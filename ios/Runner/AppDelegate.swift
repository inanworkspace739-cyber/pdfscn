import UIKit
import Flutter
import VisionKit
import PDFKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, VNDocumentCameraViewControllerDelegate {
    private var scannerResult: FlutterResult?
    private var scannedImages: [UIImage] = []
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        let scannerChannel = FlutterMethodChannel(
            name: "document_scanner",
            binaryMessenger: controller.binaryMessenger
        )
        
        scannerChannel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { return }
            
            switch call.method {
            case "scanDocument":
                self.scanDocument(result: result)
            case "extractText":
                if let args = call.arguments as? [String: Any],
                   let pdfPath = args["pdfPath"] as? String {
                    self.extractText(from: pdfPath, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing pdfPath", details: nil))
                }
            case "shareDocument":
                if let args = call.arguments as? [String: Any],
                   let pdfPath = args["pdfPath"] as? String {
                    self.shareDocument(pdfPath: pdfPath, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing pdfPath", details: nil))
                }
            case "openPDFViewer":
                if let args = call.arguments as? [String: Any],
                   let pdfPath = args["pdfPath"] as? String {
                    self.openPDFViewer(pdfPath: pdfPath, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing pdfPath", details: nil))
                }
            case "renameDocument":
                if let args = call.arguments as? [String: Any],
                   let oldPath = args["oldPath"] as? String,
                   let newName = args["newName"] as? String {
                    self.renameDocument(oldPath: oldPath, newName: newName, result: result)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Orientation Support
    // iPhone and iPad: Portrait only (matches Info.plist)
    override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
    
    // MARK: - Scan Document
    
    private func scanDocument(result: @escaping FlutterResult) {
        guard VNDocumentCameraViewController.isSupported else {
            result(FlutterError(code: "UNSUPPORTED", message: "Document scanning is not supported on this device", details: nil))
            return
        }
        
        self.scannerResult = result
        self.scannedImages = []
        
        DispatchQueue.main.async {
            let scannerVC = VNDocumentCameraViewController()
            scannerVC.delegate = self
            self.window?.rootViewController?.present(scannerVC, animated: true)
        }
    }
    
    // MARK: - VNDocumentCameraViewControllerDelegate
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                self.scannedImages.append(self.enhanceImage(image))
            }
            self.generatePDF()
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        scannerResult?(FlutterError(code: "CANCELLED", message: "User cancelled", details: nil))
        scannerResult = nil
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        scannerResult?(FlutterError(code: "SCAN_ERROR", message: error.localizedDescription, details: nil))
        scannerResult = nil
    }
    
    // MARK: - PDF Generation
    
    private func generatePDF() {
        let pdfDocument = PDFDocument()
        
        for (index, image) in scannedImages.enumerated() {
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: index)
            }
        }
        
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let filename = "Scan_\(timestamp).pdf"
        
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            scannerResult?(FlutterError(code: "ERROR", message: "Could not access documents directory", details: nil))
            scannerResult = nil
            return
        }
        
        let pdfURL = documentsURL.appendingPathComponent(filename)
        
        if pdfDocument.write(to: pdfURL) {
            scannerResult?(pdfURL.path)
        } else {
            scannerResult?(FlutterError(code: "PDF_ERROR", message: "Failed to save PDF", details: nil))
        }
        
        scannerResult = nil
        scannedImages = []
    }
    
    // MARK: - Image Enhancement
    
    private func enhanceImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)
        contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey)
        
        guard let contrastOutput = contrastFilter.outputImage else { return image }
        
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")!
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
        
        guard let output = sharpenFilter.outputImage else { return image }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else { return image }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - OCR
    
    private func extractText(from pdfPath: String, result: @escaping FlutterResult) {
        guard let url = URL(string: "file://\(pdfPath)"),
              let pdfDocument = CGPDFDocument(url as CFURL) else {
            result(FlutterError(code: "INVALID_PDF", message: "Could not load PDF", details: nil))
            return
        }
        
        var images: [UIImage] = []
        for pageNumber in 1...pdfDocument.numberOfPages {
            guard let page = pdfDocument.page(at: pageNumber) else { continue }
            let pageRect = page.getBoxRect(.mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.drawPDFPage(page)
            }
            images.append(image)
        }
        
        performOCR(on: images, result: result)
    }
    
    private func performOCR(on images: [UIImage], result: @escaping FlutterResult) {
        var allText: [String] = []
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            guard let cgImage = image.cgImage else {
                group.leave()
                continue
            }
            
            let request = VNRecognizeTextRequest { vnRequest, error in
                guard error == nil,
                      let observations = vnRequest.results as? [VNRecognizedTextObservation] else {
                    group.leave()
                    return
                }
                
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if !text.isEmpty {
                    allText.append(text)
                }
                group.leave()
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "fr-FR", "ar"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
        
        group.notify(queue: .main) {
            result(allText.isEmpty ? nil : allText.joined(separator: "\n\n--- Page Break ---\n\n"))
        }
    }
    
    // MARK: - Share
    
    private func shareDocument(pdfPath: String, result: @escaping FlutterResult) {
        guard let url = URL(string: "file://\(pdfPath)"),
              FileManager.default.fileExists(atPath: url.path) else {
            result(FlutterError(code: "FILE_NOT_FOUND", message: "PDF not found", details: nil))
            return
        }
        
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            if let controller = self.window?.rootViewController {
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = controller.view
                    popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                controller.present(activityVC, animated: true) {
                    result(true)
                }
            } else {
                result(FlutterError(code: "NO_CONTROLLER", message: "Could not present share sheet", details: nil))
            }
        }
    }
    
    // MARK: - PDF Viewer
    
    private func openPDFViewer(pdfPath: String, result: @escaping FlutterResult) {
        print("📄 openPDFViewer called with path: \(pdfPath)")
        
        // Use fileURLWithPath instead of URL(string:) for file paths
        let url = URL(fileURLWithPath: pdfPath)
        
        print("📄 Checking file exists at: \(url.path)")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File not found at: \(url.path)")
            result(FlutterError(code: "FILE_NOT_FOUND", message: "PDF not found at: \(pdfPath)", details: nil))
            return
        }
        
        print("✅ File exists, presenting viewer")
        DispatchQueue.main.async {
            let viewerVC = PDFViewerViewController(pdfURL: url)
            let navController = UINavigationController(rootViewController: viewerVC)
            navController.modalPresentationStyle = .fullScreen
            
            print("📱 About to present viewer")
            self.window?.rootViewController?.present(navController, animated: true) {
                print("✅ Viewer presented successfully")
                result(true)
            }
        }
    }
    
    // MARK: - Rename Document
    
    private func renameDocument(oldPath: String, newName: String, result: @escaping FlutterResult) {
        let oldURL = URL(fileURLWithPath: oldPath)
        let directory = oldURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent("\(newName).pdf")
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            result(newURL.path)
        } catch {
            result(FlutterError(code: "RENAME_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}

// MARK: - PDF Viewer with Markup

import PencilKit

class PDFViewerViewController: UIViewController, PKToolPickerObserver {
    private let pdfURL: URL
    private var pdfView: PDFView!
    private var canvasView: PKCanvasView!
    private var toolPicker: PKToolPicker!
    private var isMarkupMode = false
    private var bottomToolbar: UIToolbar!
    private var activeSignatureView: UIImageView?
    private var resizeButtons: [UIBarButtonItem] = []
    
    init(pdfURL: URL) {
        self.pdfURL = pdfURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPDF()
        setupTools()
        // Hide toolbar by default
        toolPicker?.setVisible(false, forFirstResponder: canvasView)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Don't auto-show toolbar
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = pdfURL.deletingPathExtension().lastPathComponent
        
        // PDF View
        pdfView = PDFView(frame: view.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        view.addSubview(pdfView)
        
        // Canvas View (for annotations)
        canvasView = PKCanvasView(frame: view.bounds)
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.isUserInteractionEnabled = false // Disabled by default - only active in markup mode
        if #available(iOS 14.0, *) {
            canvasView.drawingPolicy = .anyInput
        }
        view.addSubview(canvasView)
        
        // Top Navigation
        
        // Left: Close Button (X)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem?.tintColor = .black
        
        // Right: Save Button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
        
        // Bottom Toolbar
        setupBottomToolbar()
    }
    
    private func setupBottomToolbar() {
        bottomToolbar = UIToolbar()
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
        
        NSLayoutConstraint.activate([
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        let markupButton = UIBarButtonItem(
            image: UIImage(systemName: "pencil.tip.crop.circle"),
            style: .plain,
            target: self,
            action: #selector(markupTapped)
        )
        
        let signatureButton = UIBarButtonItem(
            image: UIImage(systemName: "signature"),
            style: .plain,
            target: self,
            action: #selector(signatureTapped)
        )
        
        let cropButton = UIBarButtonItem(
            image: UIImage(systemName: "crop"),
            style: .plain,
            target: self,
            action: #selector(cropTapped)
        )
        
        let rotateButton = UIBarButtonItem(
            image: UIImage(systemName: "rotate.right"),
            style: .plain,
            target: self,
            action: #selector(rotateTapped)
        )
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        bottomToolbar.items = [
            flexSpace,
            markupButton,
            flexSpace,
            signatureButton,
            flexSpace,
            cropButton,
            flexSpace,
            rotateButton,
            flexSpace
        ]
    }
    
    private func loadPDF() {
        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
        }
    }
    
    private func setupTools() {
        if #available(iOS 14.0, *) {
            toolPicker = PKToolPicker()
        } else {
            // For iOS 13, we need a window. If setupTools is called before viewDidAppear, window might be nil.
            if let window = view.window, let tp = PKToolPicker.shared(for: window) {
                toolPicker = tp
            }
        }
        
        // Only set up if we successfully got a picker
        if let picker = toolPicker {
            picker.addObserver(canvasView)
            picker.addObserver(self)
            picker.setVisible(false, forFirstResponder: canvasView)
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func markupTapped() {
        isMarkupMode.toggle()
        toolPicker?.setVisible(isMarkupMode, forFirstResponder: canvasView)
        
        if isMarkupMode {
            // Enable drawing
            canvasView.isUserInteractionEnabled = true
            canvasView.becomeFirstResponder()
        } else {
            // Disable drawing - allow free scrolling/zooming
            canvasView.isUserInteractionEnabled = false
            canvasView.resignFirstResponder()
        }
    }
    
    @objc private func closeMarkupTapped() {
        // Same as toggling markup off
        if isMarkupMode {
            markupTapped()
        }
    }
    
    @objc private func signatureTapped() {
        let signatureVC = SignatureViewController()
        signatureVC.completion = { [weak self] signature in
            guard let self = self else { return }
            
            // Convert signature to image
            let signatureImage = signature.image(from: signature.bounds, scale: 2.0)
            
            // Create draggable image view
            let imageView = UIImageView(image: signatureImage)
            imageView.contentMode = .scaleAspectFit
            
            // Size the signature (adjust as needed)
            let signatureSize = CGSize(width: 200, height: 100)
            imageView.frame = CGRect(
                x: self.view.center.x - signatureSize.width / 2,
                y: self.view.center.y - signatureSize.height / 2,
                width: signatureSize.width,
                height: signatureSize.height
            )
            
            // Make it draggable
            imageView.isUserInteractionEnabled = true
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(self.handleSignaturePan(_:)))
            imageView.addGestureRecognizer(panGesture)
            
            // Add pinch to resize
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.handleSignaturePinch(_:)))
            imageView.addGestureRecognizer(pinchGesture)
            
            // Add tap to select
            let tapSelectGesture = UITapGestureRecognizer(target: self, action: #selector(self.signatureViewTapped(_:)))
            imageView.addGestureRecognizer(tapSelectGesture)
            
            // Add border so user can see it's moveable
            imageView.layer.borderColor = UIColor.systemBlue.cgColor
            imageView.layer.borderWidth = 2
            imageView.layer.cornerRadius = 4
            
            // Store reference
            self.activeSignatureView = imageView
            
            // Add to view
            self.view.addSubview(imageView)
            
            // Show resize buttons
            self.showResizeButtons()
            
            // Show instruction alert
            let alert = UIAlertController(
                title: "Position Signature",
                message: "Drag to move, use +/- buttons to resize. Tap anywhere outside to place it",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                // Add tap gesture to finalize position
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.finalizeSignature))
                self.view.addGestureRecognizer(tapGesture)
            })
            self.present(alert, animated: true)
        }
        
        let navController = UINavigationController(rootViewController: signatureVC)
        present(navController, animated: true)
    }
    
    private func showResizeButtons() {
        // Delete button
        let deleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(removeSignature)
        )
        deleteButton.tintColor = .systemRed
        
        // Decrease size button
        let decreaseButton = UIBarButtonItem(
            image: UIImage(systemName: "minus.circle"),
            style: .plain,
            target: self,
            action: #selector(decreaseSignatureSize)
        )
        
        // Increase size button
        let increaseButton = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle"),
            style: .plain,
            target: self,
            action: #selector(increaseSignatureSize)
        )
        
        // OK/Deselect button
        let okButton = UIBarButtonItem(
            image: UIImage(systemName: "checkmark.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(deselectSignature)
        )
        okButton.tintColor = .systemGreen
        
        resizeButtons = [deleteButton, decreaseButton, increaseButton, okButton]
        
        // Add to navigation bar
        var rightItems = navigationItem.rightBarButtonItems ?? []
        // Remove existing resize buttons if any
        rightItems.removeAll { item in 
            resizeButtons.contains(where: { $0 === item })
        }
        rightItems.insert(contentsOf: resizeButtons, at: 0)
        navigationItem.rightBarButtonItems = rightItems
    }
    
    @objc private func deselectSignature() {
        // Remove border
        activeSignatureView?.layer.borderWidth = 0
        activeSignatureView = nil
        
        // Hide buttons
        hideResizeButtons()
        
        // Remove tap gesture
        view.gestureRecognizers?.removeAll { $0 is UITapGestureRecognizer }
    }
    
    private func hideResizeButtons() {
        navigationItem.rightBarButtonItems?.removeAll { item in
            resizeButtons.contains(item)
        }
        resizeButtons.removeAll()
    }
    
    @objc private func increaseSignatureSize() {
        guard let imageView = activeSignatureView else { return }
        UIView.animate(withDuration: 0.2) {
            imageView.transform = imageView.transform.scaledBy(x: 1.2, y: 1.2)
        }
    }
    
    @objc private func decreaseSignatureSize() {
        guard let imageView = activeSignatureView else { return }
        UIView.animate(withDuration: 0.2) {
            imageView.transform = imageView.transform.scaledBy(x: 0.8, y: 0.8)
        }
    }
    
    @objc private func removeSignature() {
        // Remove the signature view
        activeSignatureView?.removeFromSuperview()
        activeSignatureView = nil
        
        // Hide resize buttons
        hideResizeButtons()
        
        // Remove tap gesture
        view.gestureRecognizers?.removeAll { $0 is UITapGestureRecognizer }
    }
    
    @objc private func handleSignaturePan(_ gesture: UIPanGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        
        // Auto-select if panning
        if activeSignatureView != imageView {
            activateSignature(imageView)
        }
        
        let translation = gesture.translation(in: view)
        imageView.center = CGPoint(
            x: imageView.center.x + translation.x,
            y: imageView.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: view)
    }
    
    @objc private func handleSignaturePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        
        // Auto-select if pinching
        if activeSignatureView != imageView {
            activateSignature(imageView)
        }
        
        if gesture.state == .began || gesture.state == .changed {
            imageView.transform = imageView.transform.scaledBy(x: gesture.scale, y: gesture.scale)
            gesture.scale = 1.0
        }
    }
    
    @objc private func finalizeSignature(_ gesture: UITapGestureRecognizer) {
        deselectSignature()
    }
    
    @objc private func signatureViewTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        activateSignature(imageView)
    }
    
    private func activateSignature(_ imageView: UIImageView) {
        // Deselect previous
        if let current = activeSignatureView, current != imageView {
            current.layer.borderWidth = 0
        }
        
        activeSignatureView = imageView
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 2
        
        showResizeButtons()
        
        // Ensure background tap exists
        if view.gestureRecognizers?.contains(where: { $0 is UITapGestureRecognizer }) == false {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(finalizeSignature))
            view.addGestureRecognizer(tapGesture)
        }
    }
        
    
    @objc private func cropTapped() {
        let alert = UIAlertController(
            title: "Crop",
            message: "Crop feature coming soon",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func rotateTapped() {
        guard let pdfDocument = pdfView.document else { return }
        
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i) {
                page.rotation += 90
            }
        }
        pdfView.layoutDocumentView()
    }
    
    // Removed old saveTapped (now implemented below)
    
    @objc private func renameTapped() {
        let alert = UIAlertController(
            title: "Rename Document",
            message: nil,
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.text = self.pdfURL.deletingPathExtension().lastPathComponent
            textField.placeholder = "Document name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text,
                  !newName.isEmpty else { return }
            
            self.renameCurrentDocument(newName: newName)
        })
        
        present(alert, animated: true)
    }
    
    @objc private func saveTapped() {
        // Show loading indicator
        let alert = UIAlertController(title: nil, message: "Saving...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        
        DispatchQueue.main.async {
            self.saveAnnotationsAndSignatures()
            
            alert.dismiss(animated: true) {
                let successAlert = UIAlertController(
                    title: "Saved",
                    message: "File saved successfully",
                    preferredStyle: .alert
                )
                successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(successAlert, animated: true)
            }
        }
    }
    
    // Rasterize pages to burn in signatures and drawings
    private func saveAnnotationsAndSignatures() {
        guard let document = pdfView.document else { return }
        
        // Create new document to build into
        let newDocument = PDFDocument()
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            
            let pageBounds = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            
            let image = renderer.image { ctx in
                // 1. Draw original page
                UIColor.white.set()
                ctx.fill(pageBounds)
                
                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: 0, y: pageBounds.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
                ctx.cgContext.restoreGState()
                
                // 2. Draw Signatures
                for subview in self.view.subviews {
                     if let imageView = subview as? UIImageView, imageView.image != nil {
                         // Check if on this page using center point
                         let center = imageView.center
                         if self.pdfView.page(for: center, nearest: false) == page {
                             // Convert frame to page rect
                             let rectOnPage = self.pdfView.convert(imageView.frame, to: page)
                             
                             // Draw image
                             // We need to convert rectOnPage (PDF Coords, Origin Bottom-Left) to UI Coords (Top-Left)
                             let x = rectOnPage.origin.x
                             let y = pageBounds.height - rectOnPage.origin.y - rectOnPage.height
                             let uiRect = CGRect(x: x, y: y, width: rectOnPage.width, height: rectOnPage.height)
                             
                             imageView.image?.draw(in: uiRect)
                         }
                     }
                }
                
                // 3. Draw Ink
                // Convert page bounds to canvas bounds to get the relevant slice of drawing
                let pageRectInCanvas = self.pdfView.convert(page.bounds(for: .mediaBox), from: page)
                let drawingImage = self.canvasView.drawing.image(from: pageRectInCanvas, scale: 1.0)
                drawingImage.draw(in: pageBounds)
            }
            
            if let newPage = PDFPage(image: image) {
                newDocument.insert(newPage, at: newDocument.pageCount)
            }
        }
        
        // Write to file
        newDocument.write(to: pdfURL)
    }
    
    private func renameCurrentDocument(newName: String) {
        let oldURL = pdfURL
        let directory = oldURL.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent("\(newName).pdf")
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            title = newName
            
            let alert = UIAlertController(
                title: "Renamed",
                message: "Document renamed to \(newName)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "Error",
                message: "Could not rename document: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

// MARK: - Signature View Controller

class SignatureViewController: UIViewController {
    private var canvasView: PKCanvasView!
    private var thicknessSlider: UISlider!
    private var currentPenWidth: CGFloat = 3.0
    var completion: ((PKDrawing) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        title = "Add Signature"
        
        // Canvas for signature
        canvasView = PKCanvasView(frame: view.bounds)
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .white
        canvasView.tool = PKInkingTool(.pen, color: .black, width: currentPenWidth)
        if #available(iOS 14.0, *) {
            canvasView.drawingPolicy = .anyInput
        }
        view.addSubview(canvasView)
        
        // Add border/guide
        let borderView = UIView()
        borderView.translatesAutoresizingMaskIntoConstraints = false
        borderView.layer.borderColor = UIColor.systemGray4.cgColor
        borderView.layer.borderWidth = 2
        borderView.layer.cornerRadius = 8
        borderView.isUserInteractionEnabled = false
        view.addSubview(borderView)
        
        NSLayoutConstraint.activate([
            borderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            borderView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            borderView.widthAnchor.constraint(equalToConstant: 300),
            borderView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        // Thickness control toolbar at bottom
        setupThicknessControls()
        
        // Navigation buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Clear",
            style: .plain,
            target: self,
            action: #selector(clearTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
    }
    
    private func setupThicknessControls() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
        
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Create slider
        thicknessSlider = UISlider()
        thicknessSlider.minimumValue = 1.0
        thicknessSlider.maximumValue = 10.0
        thicknessSlider.value = Float(currentPenWidth)
        thicknessSlider.addTarget(self, action: #selector(thicknessChanged), for: .valueChanged)
        
        let sliderContainer = UIView()
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(thicknessSlider)
        thicknessSlider.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            thicknessSlider.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor),
            thicknessSlider.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor),
            thicknessSlider.centerYAnchor.constraint(equalTo: sliderContainer.centerYAnchor),
            sliderContainer.widthAnchor.constraint(equalToConstant: 250)
        ])
        
        let sliderItem = UIBarButtonItem(customView: sliderContainer)
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [
            flexSpace,
            sliderItem,
            flexSpace
        ]
    }
    
    @objc private func thicknessChanged() {
        currentPenWidth = CGFloat(thicknessSlider.value)
        updatePenTool()
        
        // Live update of existing strokes!
        if #available(iOS 14.0, *) {
            if !canvasView.drawing.strokes.isEmpty {
                let newStrokes = canvasView.drawing.strokes.map { stroke -> PKStroke in
                    // Create new ink with the current width
                    // Note: We use PKInkingTool to generate the configured ink
                    let newTool = PKInkingTool(.pen, color: .black, width: currentPenWidth)
                    return PKStroke(ink: newTool.ink, path: stroke.path)
                }
                canvasView.drawing = PKDrawing(strokes: newStrokes)
            }
        }
    }
    
    private func updatePenTool() {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: currentPenWidth)
    }
    
    @objc private func clearTapped() {
        canvasView.drawing = PKDrawing()
    }
    
    @objc private func doneTapped() {
        completion?(canvasView.drawing)
        dismiss(animated: true)
    }
}

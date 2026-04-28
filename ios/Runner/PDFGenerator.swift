import UIKit
import PDFKit

class PDFGenerator {
    static func createPDF(from images: [UIImage], filename: String) -> URL? {
        let pdfDocument = PDFDocument()
        
        for (index, image) in images.enumerated() {
            guard let pdfPage = createPDFPage(from: image) else { continue }
            pdfDocument.insert(pdfPage, at: index)
        }
        
        // Save to Documents directory
        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else { return nil }
        
        let pdfURL = documentsURL.appendingPathComponent("\(filename).pdf")
        
        if pdfDocument.write(to: pdfURL) {
            return pdfURL
        }
        
        return nil
    }
    
    private static func createPDFPage(from image: UIImage) -> PDFPage? {
        // Create PDF page from image
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let data = renderer.pdfData { context in
            image.draw(at: .zero)
        }
        
        guard let provider = CGDataProvider(data: data as CFData),
              let cgPDF = CGPDFDocument(provider),
              let page = cgPDF.page(at: 1) else {
            return nil
        }
        
        return PDFPage(page: page)
    }
}

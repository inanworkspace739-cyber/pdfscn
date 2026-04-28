import UIKit
import Vision

class OCRProcessor {
    static func extractText(from images: [UIImage], completion: @escaping (String?) -> Void) {
        var allText: [String] = []
        let group = DispatchGroup()
        
        for image in images {
            group.enter()
            extractText(from: image) { text in
                if let text = text {
                    allText.append(text)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(allText.isEmpty ? nil : allText.joined(separator: "\n\n--- Page Break ---\n\n"))
        }
    }
    
    static func extractText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(recognizedText.isEmpty ? nil : recognizedText)
        }
        
        // Configure for best accuracy and multiple languages
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US", "fr-FR", "ar"]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(nil)
            }
        }
    }
}

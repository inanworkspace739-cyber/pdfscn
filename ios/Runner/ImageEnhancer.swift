import UIKit
import CoreImage

class ImageEnhancer {
    static func enhance(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Apply filters for document enhancement
        let enhanced = applyDocumentFilter(to: ciImage)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(enhanced, from: enhanced.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    private static func applyDocumentFilter(to image: CIImage) -> CIImage {
        // Increase contrast and brightness for better readability
        let contrastFilter = CIFilter(name: "CIColorControls")!
        contrastFilter.setValue(image, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.2, forKey: kCIInputContrastKey) // Increase contrast
        contrastFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Slight brightness boost
        
        guard let contrastOutput = contrastFilter.outputImage else { return image }
        
        // Sharpen the image
        let sharpenFilter = CIFilter(name: "CISharpenLuminance")!
        sharpenFilter.setValue(contrastOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
        
        return sharpenFilter.outputImage ?? contrastOutput
    }
}

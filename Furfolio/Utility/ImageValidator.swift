//
//  ImageValidator.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Validates image data for size, type, and resolution.
//

import UIKit
import ImageIO

enum ValidationResult {
  case success(UIImage)
  case failure(String)
}

struct ImageValidator {
    
    // MARK: – Configuration
    
    /// Maximum allowed image data size: 5 MB
    private static let maxDataSize: Int = 5_000_000
    
    /// Minimum acceptable dimensions: 100×100 px
    private static let minWidth: CGFloat  = 100
    private static let minHeight: CGFloat = 100
    
    
    // MARK: – Type Checks
    
    /// Returns true if the data is a JPEG or PNG.
    public static func isValidType(_ data: Data?) -> Bool {
        guard let bytes = data else { return false }
        // JPEG magic numbers: 0xFF 0xD8…0xFF 0xD9
        if bytes.starts(with: [0xFF, 0xD8]) { return true }
        // PNG magic number: 0x89 0x50 0x4E 0x47
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        return false
    }
    
    
    // MARK: – Size & Resolution
    
    /// Returns true if data size ≤ `maxDataSize`.
    public static func isValidSize(_ data: Data?) -> Bool {
        guard let data = data else { return false }
        return data.count <= maxDataSize
    }
    
    /// Returns true if image dimensions ≥ `minWidth`×`minHeight`.
    public static func isSufficientResolution(_ image: UIImage) -> Bool {
        image.size.width  >= minWidth &&
        image.size.height >= minHeight
    }
    
    
    // MARK: – Full Validation
    
    /// Returns success with UIImage if valid, or failure with error message.
    static func validateImage(_ data: Data?) -> ValidationResult {
      guard let data = data else {
        return .failure("No data provided")
      }
      guard isValidType(data) else {
        return .failure("Unsupported image format")
      }
      guard isValidSize(data) else {
        return .failure("Image exceeds maximum size of \(maxDataSize/1_000_000) MB")
      }
      // Use CGImageSource to inspect dimensions without full decoding
      guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
            let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
        return .failure("Unable to read image properties")
      }
      guard width >= minWidth, height >= minHeight else {
        return .failure("Image resolution too low (\(Int(width))×\(Int(height)) px)")
      }
      guard let image = UIImage(data: data) else {
        return .failure("Failed to decode image")
      }
      return .success(image)
    }
    
    /// Convenience check: returns true if `validateImage` yields `.success`
    public static func isAcceptableImage(_ data: Data?) -> Bool {
        if case .success = validateImage(data) {
            return true
        } else {
            return false
        }
    }
}

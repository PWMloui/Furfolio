//
//  ImageValidator.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Validates image data for size, type, and resolution.
//

import UIKit
import ImageIO
import os

enum ValidationResult {
  case success(UIImage)
  case failure(String)
}

struct ImageValidator {
    
    // MARK: – Configuration
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ImageValidator")
    
    /// Maximum allowed image data size: 5 MB
    private static let maxDataSize: Int = 5_000_000
    
    /// Minimum acceptable dimensions: 100×100 px
    private static let minWidth: CGFloat  = 100
    private static let minHeight: CGFloat = 100
    
    
    // MARK: – Type Checks
    
    /// Returns true if the data is a JPEG or PNG.
    public static func isValidType(_ data: Data?) -> Bool {
        logger.log("isValidType called, data size: \(data?.count ?? 0) bytes")
        guard let bytes = data else { 
            logger.log("Invalid image type")
            return false 
        }
        // JPEG magic numbers: 0xFF 0xD8…0xFF 0xD9
        if bytes.starts(with: [0xFF, 0xD8]) { 
            logger.log("Valid image type: JPEG")
            return true 
        }
        // PNG magic number: 0x89 0x50 0x4E 0x47
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { 
            logger.log("Valid image type: PNG")
            return true 
        }
        logger.log("Invalid image type")
        return false
    }
    
    
    // MARK: – Size & Resolution
    
    /// Returns true if data size ≤ `maxDataSize`.
    public static func isValidSize(_ data: Data?) -> Bool {
        logger.log("isValidSize called, data size: \(data?.count ?? 0) bytes, max allowed: \(maxDataSize)")
        guard let data = data else { 
            logger.log("false")
            return false 
        }
        let result = data.count <= maxDataSize
        logger.log("\(result)")
        return result
    }
    
    /// Returns true if image dimensions ≥ `minWidth`×`minHeight`.
    public static func isSufficientResolution(_ image: UIImage) -> Bool {
        logger.log("isSufficientResolution called, image size: \(image.size)")
        let result = image.size.width  >= minWidth &&
        image.size.height >= minHeight
        logger.log("\(result)")
        return result
    }
    
    
    // MARK: – Full Validation
    
    /// Returns success with UIImage if valid, or failure with error message.
    static func validateImage(_ data: Data?) async -> ValidationResult {
        return await Task.detached(priority: .userInitiated) {
            logger.log("validateImage started")
            guard let data = data else {
                logger.error("No data provided")
                return .failure("No data provided")
            }
            guard isValidType(data) else {
                logger.error("Unsupported image format")
                return .failure("Unsupported image format")
            }
            guard isValidSize(data) else {
                logger.error("Image exceeds maximum size of \(maxDataSize/1_000_000) MB")
                return .failure("Image exceeds maximum size of \(maxDataSize/1_000_000) MB")
            }
            // Use CGImageSource to inspect dimensions without full decoding
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
                  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
                logger.error("Unable to read image properties")
                return .failure("Unable to read image properties")
            }
            guard width >= minWidth, height >= minHeight else {
                logger.error("Image resolution too low (\(Int(width))×\(Int(height)) px)")
                return .failure("Image resolution too low (\(Int(width))×\(Int(height)) px)")
            }
            guard let image = UIImage(data: data) else {
                logger.error("Failed to decode image")
                return .failure("Failed to decode image")
            }
            logger.log("validateImage succeeded")
            return .success(image)
        }.value
    }
    
    /// Synchronous wrapper for validateImage
    static func validateImageSync(_ data: Data?) async -> ValidationResult {
        return Task { await validateImage(data) }.value
    }
    
    /// Convenience check: returns true if `validateImage` yields `.success`
    public static func isAcceptableImage(_ data: Data?) -> Bool {
        if case .success = Task { await validateImage(data) }.value {
            return true
        } else {
            return false
        }
    }
}
public protocol EquatableBytes: Equatable {
    init(bytes: [UInt8])
    var bytes: [UInt8] { get }      
}

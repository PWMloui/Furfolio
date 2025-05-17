
//
//  ImageValidator.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Validates image data for size, type, and resolution.
//

import UIKit

struct ImageValidator {
    
    // MARK: – Configuration
    
    /// Maximum allowed image data size: 5 MB
    private static let maxDataSize: Int = 5_000_000
    
    /// Minimum acceptable dimensions: 100×100 px
    private static let minWidth: CGFloat  = 100
    private static let minHeight: CGFloat = 100
    
    
    // MARK: – Type Checks
    
    /// Returns true if the data is a JPEG or PNG.
    static func isValidType(_ data: Data?) -> Bool {
        guard let bytes = data else { return false }
        // JPEG magic numbers: 0xFF 0xD8…0xFF 0xD9
        if bytes.starts(with: [0xFF, 0xD8]) { return true }
        // PNG magic number: 0x89 0x50 0x4E 0x47
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        return false
    }
    
    
    // MARK: – Size & Resolution
    
    /// Returns true if data size ≤ `maxDataSize`.
    static func isValidSize(_ data: Data?) -> Bool {
        guard let data = data else { return false }
        return data.count <= maxDataSize
    }
    
    /// Returns true if image dimensions ≥ `minWidth`×`minHeight`.
    static func isSufficientResolution(_ image: UIImage) -> Bool {
        image.size.width  >= minWidth &&
        image.size.height >= minHeight
    }
    
    
    // MARK: – Full Validation
    
    /// Returns true if data exists, is correct type, within size limits, and has sufficient resolution.
    static func isAcceptableImage(_ data: Data?) -> Bool {
        guard let data = data else { return false }
        guard isValidType(data) else { return false }
        guard isValidSize(data) else { return false }
        guard let image = UIImage(data: data) else { return false }
        return isSufficientResolution(image)
    }
}

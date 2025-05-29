//
//  ImageProcessor.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Updated on 07/03/2025 — disambiguated Task.detached and priority qualifiers.
//

import UIKit
import os

struct ImageProcessor {
    
    /// In-memory cache for processed UIImages
    private static let imageCache = NSCache<NSString, UIImage>()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ImageProcessor")
    
    /// Supported output formats.
    enum OutputFormat {
        case jpeg(quality: CGFloat)    // quality 0.0…1.0
        case png
    }
    
    // MARK: — Synchronous Methods
    
    static func resizedImage(
        from data: Data?,
        targetWidth: CGFloat,
        interpolationQuality: CGInterpolationQuality = .high
    ) -> UIImage? {
        logger.log("resizedImage called with targetWidth: \(targetWidth), dataHash: \(data.hashValue)")
        guard let data = data else { return nil }
        let cacheKey = NSString(string: "resize_\(targetWidth)_\(data.hashValue)")
        if let cached = imageCache.object(forKey: cacheKey) {
            logger.log("Cache hit for resizedImage with key: \(cacheKey)")
            return cached
        }
        guard let image = UIImage(data: data) else { return nil }
        
        let originalSize = image.size
        let scale = targetWidth / originalSize.width
        let targetSize = CGSize(
            width: targetWidth,
            height: originalSize.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { context in
            context.cgContext.interpolationQuality = interpolationQuality
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        logger.log("Cache miss—resizing image to \(targetSize)")
        imageCache.setObject(resized, forKey: cacheKey)
        return resized
    }
    
    static func resize(
        data: Data?,
        targetWidth: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) -> Data? {
        logger.log("resize(data:) called with targetWidth: \(targetWidth), format: \(format)")
        guard let resized = resizedImage(from: data, targetWidth: targetWidth) else {
            return nil
        }
        let result: Data?
        switch format {
        case .jpeg(let quality):
            result = resized.jpegData(compressionQuality: quality)
        case .png:
            result = resized.pngData()
        }
        logger.log("resize(data:) returning data of size: \(result?.count ?? 0)")
        return result
    }
    
    static func downsampledImage(
        from data: Data?,
        maxDimension: CGFloat,
        interpolationQuality: CGInterpolationQuality = .high
    ) -> UIImage? {
        logger.log("downsampledImage called with maxDimension: \(maxDimension), dataHash: \(data.hashValue)")
        guard let data = data else { return nil }
        let cacheKey = NSString(string: "downsample_\(maxDimension)_\(data.hashValue)")
        if let cached = imageCache.object(forKey: cacheKey) {
            logger.log("Cache hit for downsampledImage with key: \(cacheKey)")
            return cached
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        let img = UIImage(cgImage: cgImage)
        logger.log("Cache miss—downsampling image to maxDimension: \(maxDimension)")
        imageCache.setObject(img, forKey: cacheKey)
        return img
    }
    
    static func downsample(
        data: Data?,
        maxDimension: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) -> Data? {
        logger.log("downsample(data:) called with maxDimension: \(maxDimension), format: \(format)")
        guard let ds = downsampledImage(from: data, maxDimension: maxDimension) else {
            return nil
        }
        let result: Data?
        switch format {
        case .jpeg(let quality):
            result = ds.jpegData(compressionQuality: quality)
        case .png:
            result = ds.pngData()
        }
        logger.log("downsample(data:) returning data of size: \(result?.count ?? 0)")
        return result
    }
    
    /// Asynchronously resizes image data on a background thread.
    static func resizeAsync(
        data: Data?,
        targetWidth: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) async -> Data? {
        logger.log("resizeAsync scheduled with targetWidth: \(targetWidth), format: \(format)")
        await Task.detached(priority: .userInitiated) {
            return resize(data: data, targetWidth: targetWidth, as: format)
        }.value
    }
    
    /// Asynchronously downsamples image data on a background thread.
    static func downsampleAsync(
        data: Data?,
        maxDimension: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) async -> Data? {
        logger.log("downsampleAsync scheduled with maxDimension: \(maxDimension), format: \(format)")
        await Task.detached(priority: .userInitiated) {
            return downsample(data: data, maxDimension: maxDimension, as: format)
        }.value
    }
}

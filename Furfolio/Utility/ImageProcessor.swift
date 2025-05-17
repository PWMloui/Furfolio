//
//  ImageProcessor.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Updated on 07/03/2025 — disambiguated Task.detached and priority qualifiers.
//

import UIKit

struct ImageProcessor {
    
    /// Supported output formats.
    enum OutputFormat {
        case jpeg(quality: CGFloat)    // quality 0.0…1.0
        case png
    }
    
    // MARK: — Synchronous Methods
    
    static func resizedImage(
        from data: Data?,
        targetWidth: CGFloat
    ) -> UIImage? {
        guard
            let data = data,
            let image = UIImage(data: data)
        else { return nil }
        
        let originalSize = image.size
        let scale = targetWidth / originalSize.width
        let targetSize = CGSize(
            width: targetWidth,
            height: originalSize.height * scale
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    static func resize(
        data: Data?,
        targetWidth: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) -> Data? {
        guard let resized = resizedImage(from: data, targetWidth: targetWidth) else {
            return nil
        }
        switch format {
        case .jpeg(let quality):
            return resized.jpegData(compressionQuality: quality)
        case .png:
            return resized.pngData()
        }
    }
    
    static func downsampledImage(
        from data: Data?,
        maxDimension: CGFloat
    ) -> UIImage? {
        guard
            let data = data,
            let image = UIImage(data: data)
        else { return nil }
        
        let aspect = image.size.width / image.size.height
        let newSize: CGSize = aspect > 1
            ? CGSize(width: maxDimension, height: maxDimension / aspect)
            : CGSize(width: maxDimension * aspect, height: maxDimension)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    static func downsample(
        data: Data?,
        maxDimension: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) -> Data? {
        guard let ds = downsampledImage(from: data, maxDimension: maxDimension) else {
            return nil
        }
        switch format {
        case .jpeg(let quality):
            return ds.jpegData(compressionQuality: quality)
        case .png:
            return ds.pngData()
        }
    }
    
    
    // MARK: — Asynchronous Methods
    
    static func asyncResize(
        data: Data?,
        targetWidth: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) async -> Data? {
        // Fully qualify the concurrency Task and its Priority
        return await _Concurrency.Task
            .detached(priority: _Concurrency.TaskPriority.userInitiated) {
                resize(data: data, targetWidth: targetWidth, as: format)
            }
            .value
    }
    
    static func asyncDownsample(
        data: Data?,
        maxDimension: CGFloat,
        as format: OutputFormat = .jpeg(quality: 0.8)
    ) async -> Data? {
        return await _Concurrency.Task
            .detached(priority: _Concurrency.TaskPriority.userInitiated) {
                downsample(data: data, maxDimension: maxDimension, as: format)
            }
            .value
    }
}

//
//  PhotoStorageManager .swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import UIKit

/// Manages storing and retrieving photos in the app’s Documents/Photos directory.
public final class PhotoStorageManager {
    public static let shared = PhotoStorageManager()
    private init() {
        createPhotosDirectoryIfNeeded()
    }

    private let directoryName = "Photos"
    private var photosDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Ensures the Photos directory exists.
    private func createPhotosDirectoryIfNeeded() {
        let url = photosDirectoryURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Saves a UIImage as JPEG data with the given filename.
    /// - Parameters:
    ///   - image: The UIImage to save.
    ///   - name: The base filename (without extension).
    /// - Throws: An error if the write fails.
    /// - Returns: The URL where the image was saved.
    @discardableResult
    public func save(_ image: UIImage, name: String) throws -> URL {
        createPhotosDirectoryIfNeeded()
        let filename = name.hasSuffix(".jpg") ? name : name + ".jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "PhotoStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert image to JPEG data"])
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Loads a UIImage from disk for the given filename.
    /// - Parameter name: The base filename (without or with .jpg).
    /// - Returns: A UIImage if the file exists and can be loaded, otherwise nil.
    public func load(name: String) -> UIImage? {
        let filename = name.hasSuffix(".jpg") ? name : name + ".jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data)
        else {
            return nil
        }
        return image
    }

    /// Deletes the image file with the given filename.
    /// - Parameter name: The base filename (without or with .jpg).
    /// - Throws: An error if deletion fails.
    public func delete(name: String) throws {
        let filename = name.hasSuffix(".jpg") ? name : name + ".jpg"
        let fileURL = photosDirectoryURL.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Lists all saved image filenames (with .jpg extension).
    /// - Returns: Array of filenames.
    public func listAll() -> [String] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: photosDirectoryURL.path) else {
            return []
        }
        return contents.filter { $0.lowercased().hasSuffix(".jpg") }
    }

    /// Deletes all images in the Photos directory.
    /// - Throws: An error if any deletion fails.
    public func clearAll() throws {
        let items = try FileManager.default.contentsOfDirectory(atPath: photosDirectoryURL.path)
        for item in items {
            let fileURL = photosDirectoryURL.appendingPathComponent(item)
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

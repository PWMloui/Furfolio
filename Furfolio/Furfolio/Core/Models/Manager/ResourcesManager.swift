//
//  ResourcesManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftUI

/// Centralized access to app resources such as images, colors, and bundled data files.
public final class ResourcesManager {
    /// Shared singleton instance.
    public static let shared = ResourcesManager()
    private init() {}

    private let bundle = Bundle.main

    // MARK: - Images

    /// Returns a SwiftUI Image for the given asset name.
    public func image(named name: String) -> Image {
        Image(name, bundle: bundle)
    }

    /// Returns a UIImage for the given asset name, if available.
    public func uiImage(named name: String) -> UIImage? {
        UIImage(named: name, in: bundle, compatibleWith: nil)
    }

    // MARK: - Colors

    /// Returns a SwiftUI Color for the given asset catalog color name.
    public func color(named name: String) -> Color {
        Color(name, bundle: bundle)
    }

    // MARK: - Data Loading

    /// Loads and decodes a JSON file from the app bundle into the specified Decodable type.
    /// - Parameters:
    ///   - type: The Decodable type to decode.
    ///   - filename: The name of the JSON file (without extension).
    /// - Returns: An instance of the specified type, or nil if loading/decoding fails.
    public func loadJSON<T: Decodable>(_ type: T.Type, from filename: String) -> T? {
        guard let url = bundle.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Strings

    /// Returns a localized string for the given key.
    public func localizedString(_ key: String, comment: String = "") -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, comment: comment)
    }

    // MARK: - Fonts

    /// Loads a custom font from the bundle.
    /// - Parameters:
    ///   - name: The font filename (without extension).
    ///   - size: The font size.
    /// - Returns: A UIFont if the font is registered, else the system font.
    public func customFont(named name: String, size: CGFloat) -> Font {
        if let uiFont = UIFont(name: name, size: size) {
            return Font(uiFont)
        }
        return Font.system(size: size)
    }
}


//
//  LocalizationService.swift
//  Furfolio
//
//  Created by senpai on 6/23/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages app localization/language switching and string lookup.
@MainActor
final class LocalizationService: ObservableObject {
    // Singleton instance for global access
    static let shared = LocalizationService()

    /// The current language (e.g., "en", "es").
    @Published private(set) var currentLanguage: String

    /// Notifies listeners when the language changes.
    let languageChanged = PassthroughSubject<String, Never>()

    private let userDefaultsKey = "selectedLanguage"

    private init() {
        // Use UserDefaults or fallback to system language
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
            self.currentLanguage = saved
        } else {
            self.currentLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
        }
        setLanguage(currentLanguage)
    }

    /// Changes the current language, saves preference, and reloads bundles.
    func setLanguage(_ language: String) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: userDefaultsKey)
        Bundle.setLanguage(language)
        languageChanged.send(language)
        objectWillChange.send()
    }

    /// Returns a localized string for a given key (from Localizable.strings).
    func localizedString(forKey key: String, comment: String = "") -> String {
        NSLocalizedString(key, bundle: Bundle.main, comment: comment)
    }
}

// MARK: - Bundle Language Extension

private var bundleKey: UInt8 = 0

extension Bundle {
    /// Swizzle to force load strings from a specific language bundle.
    static func setLanguage(_ language: String) {
        // Swap the main bundle implementation at runtime.
        objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle(path: Bundle.main.path(forResource: language, ofType: "lproj") ?? ""), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let onceToken = UUID().uuidString // Prevent multiple swizzles in one session.
        DispatchQueue.once(token: onceToken) {
            let original = class_getInstanceMethod(Bundle.self, #selector(localizedString(forKey:value:table:)))
            let swizzled = class_getInstanceMethod(Bundle.self, #selector(swizzled_localizedString(forKey:value:table:)))
            if let original = original, let swizzled = swizzled {
                method_exchangeImplementations(original, swizzled)
            }
        }
    }

    @objc func swizzled_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle {
            return bundle.swizzled_localizedString(forKey: key, value: value, table: tableName)
        } else {
            return self.swizzled_localizedString(forKey: key, value: value, table: tableName)
        }
    }
}

// MARK: - DispatchQueue Once Helper
extension DispatchQueue {
    private static var _onceTracker = [String]()

    /// Executes a block of code, associated with a unique token, only once.
    static func once(token: String, block: () -> Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        if _onceTracker.contains(token) { return }
        _onceTracker.append(token)
        block()
    }
}

//
//  LocalizationService.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Enterprise-Grade Localization Service
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
        Bundle.setLanguage(currentLanguage)
        LocalizationServiceAudit.record(action: "Init", language: currentLanguage)
    }

    /// Changes the current language, saves preference, and reloads bundles.
    func setLanguage(_ language: String) {
        guard language != currentLanguage else { return }
        let previousLanguage = currentLanguage
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: userDefaultsKey)
        Bundle.setLanguage(language)
        languageChanged.send(language)
        objectWillChange.send()
        LocalizationServiceAudit.record(action: "SetLanguage", language: language, previous: previousLanguage)
    }

    /// Returns a localized string for a given key (from Localizable.strings).
    func localizedString(forKey key: String, comment: String = "") -> String {
        NSLocalizedString(key, bundle: Bundle.main, comment: comment)
    }
    
    /// Returns the identifier for accessibility or analytics.
    var accessibilityIdentifier: String { "LocalizationService-\(currentLanguage)" }
}

// MARK: - Audit/Event Logging

fileprivate struct LocalizationServiceAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let language: String
    let previous: String?
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        let prev = previous != nil ? " (from: \(previous!))" : ""
        return "[LocalizationService] \(action): \(language)\(prev) at \(df.string(from: timestamp))"
    }
}
fileprivate final class LocalizationServiceAudit {
    static private(set) var log: [LocalizationServiceAuditEvent] = []
    static func record(action: String, language: String, previous: String? = nil) {
        let event = LocalizationServiceAuditEvent(
            timestamp: Date(),
            action: action,
            language: language,
            previous: previous
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum LocalizationServiceAuditAdmin {
    public static func lastSummary() -> String { LocalizationServiceAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { LocalizationServiceAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 10) -> [String] { LocalizationServiceAudit.recentSummaries(limit: limit) }
}

// MARK: - Bundle Language Extension

private var bundleKey: UInt8 = 0

extension Bundle {
    /// Swizzle to force load strings from a specific language bundle.
    static func setLanguage(_ language: String) {
        // Swap the main bundle implementation at runtime.
        objc_setAssociatedObject(Bundle.main, &bundleKey, Bundle(path: Bundle.main.path(forResource: language, ofType: "lproj") ?? ""), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        let onceToken = "com.furfolio.bundle.swizzle.\(language)" // One swizzle per language per run
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

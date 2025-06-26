//
//  UserSettings.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

import Foundation
import SwiftUI

/// The central, observable user settings model for Furfolio.
/// Use as an @ObservableObject in App, views, and for user preference sync.
final class UserSettings: ObservableObject, Codable {
    // MARK: - User Preferences
    @Published var isDarkMode: Bool
    @Published var isDemoMode: Bool
    @Published var preferredLanguage: String   // e.g. "en", "es"
    @Published var notificationsEnabled: Bool
    @Published var marketingOptIn: Bool
    @Published var favoriteGroomingStyle: String
    @Published var preferredShampoo: String
    @Published var specialRequests: String
    @Published var lastSeenWhatsNew: String    // Version or identifier
    @Published var onboardingCompleted: Bool
    @Published var hasRatedApp: Bool

    // Add more settings as needed

    // MARK: - Init
    init(
        isDarkMode: Bool = false,
        isDemoMode: Bool = false,
        preferredLanguage: String = Locale.current.language.languageCode?.identifier ?? "en",
        notificationsEnabled: Bool = true,
        marketingOptIn: Bool = false,
        favoriteGroomingStyle: String = "",
        preferredShampoo: String = "",
        specialRequests: String = "",
        lastSeenWhatsNew: String = "",
        onboardingCompleted: Bool = false,
        hasRatedApp: Bool = false
    ) {
        self.isDarkMode = isDarkMode
        self.isDemoMode = isDemoMode
        self.preferredLanguage = preferredLanguage
        self.notificationsEnabled = notificationsEnabled
        self.marketingOptIn = marketingOptIn
        self.favoriteGroomingStyle = favoriteGroomingStyle
        self.preferredShampoo = preferredShampoo
        self.specialRequests = specialRequests
        self.lastSeenWhatsNew = lastSeenWhatsNew
        self.onboardingCompleted = onboardingCompleted
        self.hasRatedApp = hasRatedApp
    }

    // MARK: - Codable support
    enum CodingKeys: String, CodingKey {
        case isDarkMode, isDemoMode, preferredLanguage, notificationsEnabled, marketingOptIn, favoriteGroomingStyle, preferredShampoo, specialRequests, lastSeenWhatsNew, onboardingCompleted, hasRatedApp
    }
    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            isDarkMode: try c.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? false,
            isDemoMode: try c.decodeIfPresent(Bool.self, forKey: .isDemoMode) ?? false,
            preferredLanguage: try c.decodeIfPresent(String.self, forKey: .preferredLanguage) ?? "en",
            notificationsEnabled: try c.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true,
            marketingOptIn: try c.decodeIfPresent(Bool.self, forKey: .marketingOptIn) ?? false,
            favoriteGroomingStyle: try c.decodeIfPresent(String.self, forKey: .favoriteGroomingStyle) ?? "",
            preferredShampoo: try c.decodeIfPresent(String.self, forKey: .preferredShampoo) ?? "",
            specialRequests: try c.decodeIfPresent(String.self, forKey: .specialRequests) ?? "",
            lastSeenWhatsNew: try c.decodeIfPresent(String.self, forKey: .lastSeenWhatsNew) ?? "",
            onboardingCompleted: try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false,
            hasRatedApp: try c.decodeIfPresent(Bool.self, forKey: .hasRatedApp) ?? false
        )
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(isDarkMode, forKey: .isDarkMode)
        try c.encode(isDemoMode, forKey: .isDemoMode)
        try c.encode(preferredLanguage, forKey: .preferredLanguage)
        try c.encode(notificationsEnabled, forKey: .notificationsEnabled)
        try c.encode(marketingOptIn, forKey: .marketingOptIn)
        try c.encode(favoriteGroomingStyle, forKey: .favoriteGroomingStyle)
        try c.encode(preferredShampoo, forKey: .preferredShampoo)
        try c.encode(specialRequests, forKey: .specialRequests)
        try c.encode(lastSeenWhatsNew, forKey: .lastSeenWhatsNew)
        try c.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try c.encode(hasRatedApp, forKey: .hasRatedApp)
    }

    // MARK: - Persistence
    static let saveKey = "UserSettings"
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }
    static func load() -> UserSettings {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            return settings
        }
        return UserSettings()
    }
}

// MARK: - Audit/Event Logging

struct UserSettingsAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let key: String
    let value: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[UserSettings] \(action) \(key): \(value) at \(df.string(from: timestamp))"
    }
}
final class UserSettingsAudit {
    static private(set) var log: [UserSettingsAuditEvent] = []
    static func record(action: String, key: String, value: String) {
        let event = UserSettingsAuditEvent(timestamp: Date(), action: action, key: key, value: value)
        log.append(event)
        if log.count > 36 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum UserSettingsAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { UserSettingsAudit.recentSummaries(limit: limit) }
}

#if DEBUG
extension UserSettings {
    static let preview = UserSettings(isDarkMode: true, isDemoMode: false, preferredLanguage: "en", notificationsEnabled: true, marketingOptIn: true, favoriteGroomingStyle: "Poodle Clip", preferredShampoo: "Oatmeal", specialRequests: "SMS reminders", lastSeenWhatsNew: "2.4.1", onboardingCompleted: true, hasRatedApp: false)
}
#endif

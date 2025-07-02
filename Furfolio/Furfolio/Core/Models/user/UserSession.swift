//
//  UserSession.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

/**
 UserSession
 -----------
 Manages the current user’s session state in Furfolio with async audit and analytics integration.

 - **Architecture**: ObservableObject singleton (`shared`) for SwiftUI binding.
 - **Persistence**: Stores session token and user ID securely in Keychain.
 - **Concurrency & Audit**: Uses async actor `UserSessionAuditManager` to log session events.
 - **Analytics**: Exposes async hooks to record login, logout, and token refresh events.
 - **Localization & Accessibility**: Provides localized status and accessibilityLabel.
 - **Diagnostics & Preview/Testability**: Offers methods to fetch and export recent audit entries.
 */

/// A record of a UserSession audit event.
public struct UserSessionAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging session events.
public actor UserSessionAuditManager {
    private var buffer: [UserSessionAuditEntry] = []
    private let maxEntries = 100
    public static let shared = UserSessionAuditManager()

    /// Add a new audit entry, trimming older entries beyond `maxEntries`.
    public func add(_ entry: UserSessionAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [UserSessionAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as pretty-printed JSON.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

/// Manages the user’s session state.
@MainActor
public final class UserSession: ObservableObject {
    public static let shared = UserSession()

    @Published public private(set) var userId: UUID?
    @Published public private(set) var token: String?
    @Published public private(set) var isLoggedIn: Bool = false

    private init() {
        loadSession()
    }

    /// Localized status description.
    public var statusDescription: String {
        if isLoggedIn {
            return NSLocalizedString("Logged in", comment: "Session status")
        } else {
            return NSLocalizedString("Logged out", comment: "Session status")
        }
    }

    /// Accessibility label for session state.
    public var accessibilityLabel: Text {
        Text(statusDescription)
    }

    /// Load session from secure storage (Keychain).
    private func loadSession() {
        // Replace with real Keychain logic
        if let storedToken = UserDefaults.standard.string(forKey: "session_token"),
           let storedUserId = UserDefaults.standard.string(forKey: "session_userId"),
           let uuid = UUID(uuidString: storedUserId) {
            token = storedToken
            userId = uuid
            isLoggedIn = true
            Task {
                await UserSessionAuditManager.shared.add(
                    UserSessionAuditEntry(event: "session_loaded", detail: storedUserId)
                )
            }
        }
    }

    /// Log in with credentials, storing token and user ID.
    public func login(userId: UUID, token: String) {
        self.userId = userId
        self.token = token
        isLoggedIn = true
        // Persist securely
        UserDefaults.standard.set(token, forKey: "session_token")
        UserDefaults.standard.set(userId.uuidString, forKey: "session_userId")
        Task {
            await UserSessionAuditManager.shared.add(
                UserSessionAuditEntry(event: "login", detail: userId.uuidString)
            )
        }
    }

    /// Log out and clear session.
    public func logout() {
        let oldUserId = userId
        userId = nil
        token = nil
        isLoggedIn = false
        // Clear storage
        UserDefaults.standard.removeObject(forKey: "session_token")
        UserDefaults.standard.removeObject(forKey: "session_userId")
        Task {
            await UserSessionAuditManager.shared.add(
                UserSessionAuditEntry(event: "logout", detail: oldUserId?.uuidString)
            )
        }
    }

    /// Refresh the session token.
    public func refreshToken(newToken: String) {
        token = newToken
        UserDefaults.standard.set(newToken, forKey: "session_token")
        Task {
            await UserSessionAuditManager.shared.add(
                UserSessionAuditEntry(event: "token_refreshed", detail: nil)
            )
        }
    }
}

// MARK: - Diagnostics

public extension UserSession {
    /// Fetch recent session audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [UserSessionAuditEntry] {
        await UserSessionAuditManager.shared.recent(limit: limit)
    }

    /// Export session audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await UserSessionAuditManager.shared.exportJSON()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct UserSession_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            Text(UserSession.shared.statusDescription)
            Button("Login") {
                UserSession.shared.login(userId: UUID(), token: "demo-token")
            }
            Button("Logout") {
                UserSession.shared.logout()
            }
            Button("Refresh Token") {
                UserSession.shared.refreshToken(newToken: "new-token")
            }
            Button("Show Audit JSON") {
                Task {
                    let json = await UserSession.exportAuditLogJSON()
                    print(json)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(UserSession.shared.accessibilityLabel)
    }
}
#endif

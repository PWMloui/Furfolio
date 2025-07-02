//
//  GiftCard.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 GiftCard
 --------
 A model representing a digital gift card within the Furfolio app, including value, expiration, and audit logging.

 - **Architecture**: Conforms to Identifiable, Codable for SwiftUI and networking.
 - **Concurrency & Audit**: Provides async/await audit logging via `GiftCardAuditManager` actor.
 - **Fields**: Card code, recipient details, balance, expiration, creation and update timestamps.
 - **Localization**: All user-facing strings and audit entries use NSLocalizedString.
 - **Accessibility**: Computed properties expose formatted values for VoiceOver.
 - **Preview/Testability**: Includes a SwiftUI preview demonstrating creation, redemption, and audit entries.
 */

import SwiftUI
import Foundation
import SwiftData

@Model public struct GiftCard: Identifiable {
    /// Unique identifier for the gift card
    @Attribute(.unique) public var id: UUID
    /// Human-readable gift card code
    public var code: String
    /// Recipient name or email
    public var recipient: String?
    /// Current balance on the card
    public var balance: Double
    /// Optional expiration date
    public var expirationDate: Date?
    /// Creation timestamp
    public let createdAt: Date
    /// Last updated timestamp
    public var updatedAt: Date

    @Attribute(.transient)
    /// Formatted balance string for display
    public var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: balance)) ?? "\(balance)"
    }

    @Attribute(.transient)
    /// Formatted expiration date
    public var formattedExpiration: String? {
        guard let exp = expirationDate else { return nil }
        return DateFormatter.localizedString(from: exp, dateStyle: .medium, timeStyle: .none)
    }

    /// Initializes a new GiftCard
    public init(id: UUID = UUID(),
                code: String,
                recipient: String? = nil,
                balance: Double,
                expirationDate: Date? = nil) {
        self.id = id
        self.code = NSLocalizedString(code, comment: "Gift card code")
        self.recipient = recipient
        self.balance = balance
        self.expirationDate = expirationDate
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

/// Represents a single GiftCard audit entry.
@Model public struct GiftCardAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

/// Actor for concurrency-safe GiftCard audit logging.
public actor GiftCardAuditManager {
    private var buffer: [GiftCardAuditEntry] = []
    private let maxEntries = 100
    public static let shared = GiftCardAuditManager()

    /// Add a new audit entry, capping to `maxEntries`.
    public func add(_ entry: GiftCardAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to `limit`.
    public func recent(limit: Int = 20) -> [GiftCardAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
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

public extension GiftCard {
    /// Asynchronously logs an audit entry for this gift card.
    func addAudit(_ entry: String) async {
        let localized = NSLocalizedString(entry, comment: "GiftCard audit entry")
        let auditEntry = GiftCardAuditEntry(timestamp: Date(), entry: localized)
        await GiftCardAuditManager.shared.add(auditEntry)
        updatedAt = Date()
    }

    /// Fetches recent audit entries for this gift card.
    func recentAuditEntries(limit: Int = 20) async -> [GiftCardAuditEntry] {
        await GiftCardAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as a JSON string.
    func exportAuditLogJSON() async -> String {
        await GiftCardAuditManager.shared.exportJSON()
    }

    /// Redeem a specified amount from the gift card.
    mutating func redeem(amount: Double) async {
        balance = max(0, balance - amount)
        updatedAt = Date()
        await addAudit("Redeemed \(amount) from gift card")
    }
}

#if DEBUG
struct GiftCard_Previews: PreviewProvider {
    static var previews: some View {
        var card = GiftCard(code: "GIFT2025", recipient: "client@example.com", balance: 50.0, expirationDate: Date().addingTimeInterval(60*60*24*30))
        VStack(spacing: 16) {
            Text("Code: \(card.code)")
            Text("Balance: \(card.formattedBalance)")
            if let exp = card.formattedExpiration {
                Text("Expires: \(exp)")
            }
            Button("Redeem $10") {
                Task {
                    await card.redeem(amount: 10.0)
                    let entries = await card.recentAuditEntries(limit: 5)
                    print(entries)
                }
            }
        }
        .padding()
    }
}
#endif

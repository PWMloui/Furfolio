// MARK: - Gift Card Audit Event Logging & Analytics

import Foundation
import SwiftUI

/// Represents an audit event for a gift card operation.
/// Conforms to Codable for persistence and export.
struct GiftCardAuditEvent: Codable, Identifiable {
    /// Unique identifier for the audit event.
    let id: UUID
    /// UTC timestamp of the event.
    let timestamp: Date
    /// Operation type: "issue", "redeem", "expire", "edit", "delete", "exportCSV".
    let operation: String
    /// Gift card identifier.
    let cardID: String
    /// Recipient of the gift card.
    let recipient: String
    /// Value of the gift card.
    let value: Double
    /// Date the gift card was issued.
    let issuedDate: Date?
    /// Date the gift card was redeemed.
    let redeemedDate: Date?
    /// Expiry date of the gift card.
    let expiryDate: Date?
    /// Status of the gift card ("active", "redeemed", "expired", etc).
    let status: String
    /// Tags or labels associated with the gift card.
    let tags: [String]
    /// The actor/user performing the operation.
    let actor: String
    /// Context (e.g. "admin panel", "user app").
    let context: String
    /// Additional details about the event.
    let detail: String?
    
    init(
        operation: String,
        cardID: String,
        recipient: String,
        value: Double,
        issuedDate: Date?,
        redeemedDate: Date?,
        expiryDate: Date?,
        status: String,
        tags: [String],
        actor: String,
        context: String,
        detail: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.operation = operation
        self.cardID = cardID
        self.recipient = recipient
        self.value = value
        self.issuedDate = issuedDate
        self.redeemedDate = redeemedDate
        self.expiryDate = expiryDate
        self.status = status
        self.tags = tags
        self.actor = actor
        self.context = context
        self.detail = detail
    }
}

/// Manages the list of audit events for gift card operations.
/// Provides logging and analytics.
class GiftCardAudit: ObservableObject {
    /// All logged audit events.
    @Published private(set) var events: [GiftCardAuditEvent] = []
    
    /// Logs a new audit event for a gift card operation.
    func logEvent(
        operation: String,
        cardID: String,
        recipient: String,
        value: Double,
        issuedDate: Date?,
        redeemedDate: Date?,
        expiryDate: Date?,
        status: String,
        tags: [String],
        actor: String,
        context: String,
        detail: String? = nil
    ) {
        let event = GiftCardAuditEvent(
            operation: operation,
            cardID: cardID,
            recipient: recipient,
            value: value,
            issuedDate: issuedDate,
            redeemedDate: redeemedDate,
            expiryDate: expiryDate,
            status: status,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        events.append(event)
    }
    
    // MARK: - Analytics
    
    /// Total number of issued gift cards (count of "issue" events).
    var totalIssued: Int {
        events.filter { $0.operation == "issue" }.count
    }
    
    /// Total number of redeemed gift cards (count of "redeem" events).
    var totalRedeemed: Int {
        events.filter { $0.operation == "redeem" }.count
    }
    
    /// Total number of currently active gift cards (status "active" in latest event per card).
    var totalActive: Int {
        // Get the latest event for each cardID and count those with status "active"
        let latestByCard = Dictionary(grouping: events, by: { $0.cardID }).compactMapValues { $0.max(by: { $0.timestamp < $1.timestamp }) }
        return latestByCard.values.filter { $0.status.lowercased() == "active" }.count
    }
    
    /// The recipient who received the most issued gift cards.
    var mostFrequentRecipient: String? {
        let issued = events.filter { $0.operation == "issue" }
        let freq = Dictionary(grouping: issued, by: { $0.recipient }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
}

/// Provides admin access for audit log, analytics, and export.
public class GiftCardAuditAdmin {
    private let audit: GiftCardAudit
    
    public init(audit: GiftCardAudit) {
        self.audit = audit
    }
    
    /// Returns the last audit event as a formatted string.
    public var lastSummary: String? {
        guard let last = audit.events.last else { return nil }
        return "[\(last.operation.uppercased())] \(last.recipient) | \(last.status) | \(last.timestamp)"
    }
    
    /// Returns the last audit event as JSON.
    public var lastJSON: String? {
        guard let last = audit.events.last else { return nil }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(last) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Returns the most recent audit events, up to the specified limit.
    public func recentEvents(limit: Int) -> [GiftCardAuditEvent] {
        let count = audit.events.count
        guard count > 0 else { return [] }
        return Array(audit.events.suffix(limit))
    }
    
    /// Exports all audit events as CSV string.
    /// CSV headers: timestamp,operation,cardID,recipient,value,issuedDate,redeemedDate,expiryDate,status,tags,actor,context,detail
    public func exportCSV() -> String {
        let header = [
            "timestamp","operation","cardID","recipient","value","issuedDate","redeemedDate","expiryDate","status","tags","actor","context","detail"
        ].joined(separator: ",")
        let dateFormatter = ISO8601DateFormatter()
        let rows = audit.events.map { e in
            [
                dateFormatter.string(from: e.timestamp),
                e.operation,
                e.cardID,
                e.recipient,
                String(format: "%.2f", e.value),
                e.issuedDate.map { dateFormatter.string(from: $0) } ?? "",
                e.redeemedDate.map { dateFormatter.string(from: $0) } ?? "",
                e.expiryDate.map { dateFormatter.string(from: $0) } ?? "",
                e.status,
                e.tags.joined(separator: "|"),
                e.actor,
                e.context,
                e.detail?.replacingOccurrences(of: ",", with: ";") ?? ""
            ].map { "\"\($0)\"" }.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    // MARK: - Analytics Exposed
    public var totalIssued: Int { audit.totalIssued }
    public var totalRedeemed: Int { audit.totalRedeemed }
    public var totalActive: Int { audit.totalActive }
    public var mostFrequentRecipient: String? { audit.mostFrequentRecipient }
}

// MARK: - Accessibility VoiceOver Announcements

#if canImport(UIKit)
import UIKit
#endif

/// Posts a VoiceOver accessibility announcement for gift card actions.
func postGiftCardAccessibilityAnnouncement(_ message: String) {
#if os(iOS)
    UIAccessibility.post(notification: .announcement, argument: message)
#endif
}
//
//  GiftCardManagementView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//



// MARK: - Gift Card Management View (with Audit & DEV Overlay)

/// Example usage of audit logging, analytics, accessibility, and DEV overlay in a SwiftUI view.
struct GiftCardManagementView: View {
    // The audit manager (should be shared or injected).
    @StateObject private var audit = GiftCardAudit()
    // The admin interface for audit.
    private var auditAdmin: GiftCardAuditAdmin { GiftCardAuditAdmin(audit: audit) }
    
    // Example state for demonstration.
    @State private var giftCards: [String: (recipient: String, value: Double, issuedDate: Date, status: String)] = [:]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                // Example: Issue a gift card button
                Button("Issue Gift Card") {
                    let cardID = UUID().uuidString
                    let recipient = "Alice"
                    let value = 50.0
                    let issuedDate = Date()
                    giftCards[cardID] = (recipient, value, issuedDate, "active")
                    // Log audit event
                    audit.logEvent(
                        operation: "issue",
                        cardID: cardID,
                        recipient: recipient,
                        value: value,
                        issuedDate: issuedDate,
                        redeemedDate: nil,
                        expiryDate: Calendar.current.date(byAdding: .day, value: 365, to: issuedDate),
                        status: "active",
                        tags: ["promo"],
                        actor: "admin",
                        context: "GiftCardManagementView",
                        detail: "Issued via admin panel"
                    )
                    // Accessibility announcement
                    postGiftCardAccessibilityAnnouncement("Gift card for \(recipient) issued.")
                }
                // Example: Redeem a gift card button
                Button("Redeem First Gift Card") {
                    guard let (cardID, gc) = giftCards.first else { return }
                    giftCards[cardID] = (gc.recipient, gc.value, gc.issuedDate, "redeemed")
                    audit.logEvent(
                        operation: "redeem",
                        cardID: cardID,
                        recipient: gc.recipient,
                        value: gc.value,
                        issuedDate: gc.issuedDate,
                        redeemedDate: Date(),
                        expiryDate: nil,
                        status: "redeemed",
                        tags: ["promo"],
                        actor: "admin",
                        context: "GiftCardManagementView",
                        detail: "Redeemed via admin panel"
                    )
                    postGiftCardAccessibilityAnnouncement("Gift card for \(gc.recipient) redeemed.")
                }
                // Example: Expire a gift card button
                Button("Expire First Gift Card") {
                    guard let (cardID, gc) = giftCards.first else { return }
                    giftCards[cardID] = (gc.recipient, gc.value, gc.issuedDate, "expired")
                    audit.logEvent(
                        operation: "expire",
                        cardID: cardID,
                        recipient: gc.recipient,
                        value: gc.value,
                        issuedDate: gc.issuedDate,
                        redeemedDate: nil,
                        expiryDate: Date(),
                        status: "expired",
                        tags: ["promo"],
                        actor: "admin",
                        context: "GiftCardManagementView",
                        detail: "Expired via admin panel"
                    )
                    postGiftCardAccessibilityAnnouncement("Gift card for \(gc.recipient) expired.")
                }
                // Example: Export CSV button
                Button("Export Audit CSV") {
                    let csv = auditAdmin.exportCSV()
                    // Do something with CSV (e.g. share, save)
                    print(csv)
                }
                Spacer()
            }
#if DEBUG
            // MARK: - DEV Overlay for Audit/Analytics (only in DEBUG)
            DevAuditOverlay(auditAdmin: auditAdmin)
                .padding(.bottom, 4)
#endif
        }
    }
}

#if DEBUG
/// Developer overlay view showing recent audit events and analytics (DEBUG only).
struct DevAuditOverlay: View {
    let auditAdmin: GiftCardAuditAdmin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AUDIT DEV OVERLAY").font(.caption2).bold().foregroundColor(.gray)
            ForEach(auditAdmin.recentEvents(limit: 3)) { event in
                Text("[\(event.operation.uppercased())] \(event.recipient) | \(event.status) | \(event.timestamp.formatted(.dateTime.hour().minute().second()))")
                    .font(.caption2)
            }
            HStack(spacing: 12) {
                Text("Issued: \(auditAdmin.totalIssued)")
                Text("Redeemed: \(auditAdmin.totalRedeemed)")
                Text("Active: \(auditAdmin.totalActive)")
                if let freq = auditAdmin.mostFrequentRecipient {
                    Text("Top: \(freq)")
                }
            }
            .font(.caption2)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(radius: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

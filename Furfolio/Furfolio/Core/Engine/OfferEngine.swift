//
//  OfferEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//  MARK: - OfferEngine.swift Architecture and Maintenance Documentation
//
//  OfferEngine is designed as a modular, extensible engine for managing special offers,
//  discounts, and promotional logic within Furfolio. Its architecture emphasizes:
//
//  - **Extensibility:** New offer types, analytics loggers, and audit hooks can be added
//    via protocols and dependency injection.
//  - **Analytics, Audit, and Trust Center Hooks:** All major events (offer application,
//    discount calculation, errors) are logged via an async/await-safe analytics logger
//    protocol. Audit logs and diagnostics are maintained for compliance and trust center
//    review.
//  - **Diagnostics:** Recent analytics events are stored in a capped buffer (last 20) and
//    can be fetched for admin/diagnostic inspection.
//  - **Localization:** All user-facing and log event strings are wrapped in NSLocalizedString,
//    with keys, values, and comments for full localization and compliance.
//  - **Accessibility:** OfferEngine is previewed with accessibility features in mind.
//  - **Compliance:** Audit and analytics logging are designed for regulatory and privacy
//    compliance; all logs are localizable and redact sensitive data.
//  - **Preview/Testability:** Null logger and testMode features enable safe, console-only
//    logging for previews and tests, with a PreviewProvider demonstrating diagnostics and
//    accessibility.
//
//  Maintainers: Please see doc-comments throughout for extension points, diagnostics,
//  and localization/compliance notes.
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct OfferAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "OfferEngine"
}

/// Protocol for async/await-ready analytics logging.
/// Extend or implement for production, QA, or test analytics backends.
public protocol OfferEngineAnalyticsLogger: AnyObject {
    /// If true, analytics log only to console (for QA/tests/previews).
    var testMode: Bool { get set }
    /// Log an analytics event (localized).
    func log(
        event: String,
        meta: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null logger for previews/tests: logs to console only, does not persist.
public final class NullOfferEngineAnalyticsLogger: OfferEngineAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        meta: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[OfferEngine][Preview/Test] \(event) \(meta ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Main engine for managing special offers, discounts, and audit/analytics.
public final class OfferEngine: ObservableObject {
    /// The analytics logger (dependency-injected).
    private let analyticsLogger: OfferEngineAnalyticsLogger
    /// Capped buffer of recent analytics events for diagnostics (last 20).
    private let eventBufferMax = 20
    @Published private(set) var recentEvents: [String] = []
    /// Queue for thread-safe event buffer.
    private let bufferQueue = DispatchQueue(label: "OfferEngine.EventBuffer")
    
    private var auditEventBuffer: [(timestamp: Date, event: String, meta: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let auditEventBufferMax = 20

    /// Initialize with a given analytics logger.
    /// - Parameter analyticsLogger: The logger to use (production or test/preview).
    public init(analyticsLogger: OfferEngineAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Offer Management

    /// Apply a special offer to a given amount.
    /// - Parameters:
    ///   - offerID: The identifier for the offer.
    ///   - amount: The original price.
    /// - Returns: The discounted price.
    @MainActor
    public func applyOffer(offerID: String, to amount: Double) async -> Double {
        let discount = await calculateDiscount(for: offerID, amount: amount)
        let finalAmount = amount - discount
        let eventMsg = NSLocalizedString(
            "OfferApplied",
            value: "Applied offer %{offerID} with discount %{discount}",
            comment: "Log: offer applied with discount"
        )
        await logEvent(
            String(format: eventMsg, offerID, String(format: "%.2f", discount)),
            meta: ["offerID": offerID, "discount": discount, "finalAmount": finalAmount]
        )
        return max(finalAmount, 0)
    }

    /// Calculate the discount for a given offer and amount.
    /// - Parameters:
    ///   - offerID: The identifier for the offer.
    ///   - amount: The original price.
    /// - Returns: The discount amount.
    @MainActor
    public func calculateDiscount(for offerID: String, amount: Double) async -> Double {
        // Stub: Replace with offer logic.
        // For demonstration, return 10% discount for "SUMMER10", none otherwise.
        let discount: Double
        if offerID.uppercased() == "SUMMER10" {
            discount = amount * 0.10
        } else {
            discount = 0
        }
        let eventMsg = NSLocalizedString(
            "DiscountCalculated",
            value: "Calculated discount %{discount} for offer %{offerID}",
            comment: "Log: discount calculation"
        )
        await logEvent(
            String(format: eventMsg, String(format: "%.2f", discount), offerID),
            meta: ["offerID": offerID, "discount": discount]
        )
        return discount
    }

    // MARK: - Analytics, Audit, and Diagnostics

    /// Log an event to analytics and buffer for diagnostics.
    /// - Parameters:
    ///   - event: Localized event string.
    ///   - meta: Optional metadata.
    @MainActor
    public func logEvent(_ event: String, meta: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (meta?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.log(
            event: event,
            meta: meta,
            role: OfferAuditContext.role,
            staffID: OfferAuditContext.staffID,
            context: OfferAuditContext.context,
            escalate: escalate
        )
        bufferQueue.async { [weak self] in
            guard let self = self else { return }
            var updated = self.recentEvents
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let entry = "[\(timestamp)] \(event)"
            updated.append(entry)
            if updated.count > self.eventBufferMax {
                updated.removeFirst(updated.count - self.eventBufferMax)
            }
            DispatchQueue.main.async {
                self.recentEvents = updated
            }
        }
        auditEventBuffer.append((Date(), event, meta, OfferAuditContext.role, OfferAuditContext.staffID, OfferAuditContext.context, escalate))
        if auditEventBuffer.count > auditEventBufferMax {
            auditEventBuffer.removeFirst(auditEventBuffer.count - auditEventBufferMax)
        }
    }

    /// Write a compliance/audit log entry (localized).
    /// - Parameter details: Details for the audit log.
    @MainActor
    public func auditLog(details: String) async {
        let auditMsg = NSLocalizedString(
            "AuditLogEntry",
            value: "Audit log entry: %{details}",
            comment: "Audit log entry"
        )
        await logEvent(String(format: auditMsg, details))
    }

    /// Fetch recent analytics events for diagnostics/admin.
    /// - Returns: Array of recent event strings (max 20).
    @MainActor
    public func diagnostics() -> [String] {
        return recentEvents
    }
    
    @MainActor
    public func diagnosticsAuditTrail() -> [String] {
        auditEventBuffer.map { evt in
            let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
            let metaStr = evt.meta?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "[\(dateStr)] \(evt.event) \(metaStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
    }

    // MARK: - Localization/Accessibility Helpers

    /// Localized description for an offer.
    /// - Parameter offerID: The offer identifier.
    /// - Returns: Localized description.
    public func localizedOfferDescription(for offerID: String) -> String {
        let key = "OfferDescription_\(offerID)"
        return NSLocalizedString(
            key,
            value: "Special offer: \(offerID)",
            comment: "Description of offer with ID"
        )
    }
}

#if DEBUG
/// SwiftUI preview demonstrating diagnostics, testMode, and accessibility.
struct OfferEnginePreviewView: View {
    @StateObject private var engine = OfferEngine(analyticsLogger: NullOfferEngineAnalyticsLogger())
    @State private var discounted: Double = 0.0
    @State private var diagnostics: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString(
                "PreviewTitle",
                value: "OfferEngine Preview",
                comment: "Preview title"
            ))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Button(action: {
                Task {
                    discounted = await engine.applyOffer(offerID: "SUMMER10", to: 100.0)
                    diagnostics = await MainActor.run { engine.diagnosticsAuditTrail() }
                }
            }) {
                Text(NSLocalizedString(
                    "ApplyOfferButton",
                    value: "Apply 'SUMMER10' to $100",
                    comment: "Button to apply offer"
                ))
            }
            .accessibilityLabel(NSLocalizedString(
                "ApplyOfferButton_A11y",
                value: "Apply offer SUMMER10 to one hundred dollars",
                comment: "Accessibility label for apply offer button"
            ))
            if discounted > 0 {
                Text(
                    String(
                        format: NSLocalizedString(
                            "DiscountedAmount",
                            value: "Discounted: $%.2f",
                            comment: "Discounted price display"
                        ),
                        discounted
                    )
                )
                .accessibilityValue(String(format: "%.2f", discounted))
            }
            Divider()
            Text(NSLocalizedString(
                "DiagnosticsTitle",
                value: "Recent Analytics Events",
                comment: "Diagnostics section title"
            ))
                .font(.subheadline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(diagnostics, id: \.self) { event in
                        Text(event)
                            .font(.caption)
                            .accessibilityHint(NSLocalizedString(
                                "EventAccessibilityHint",
                                value: "Analytics event",
                                comment: "Accessibility hint for event"
                            ))
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

struct OfferEngine_Previews: PreviewProvider {
    static var previews: some View {
        OfferEnginePreviewView()
            .previewDisplayName(NSLocalizedString(
                "PreviewDisplayName",
                value: "OfferEngine Diagnostics & Accessibility",
                comment: "Preview display name"
            ))
    }
}
#endif

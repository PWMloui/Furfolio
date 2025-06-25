// CurrencyFormatter.swift

//
//  CurrencyFormatter.swift
//  Furfolio
//
//  Enhanced: Auditable, Tokenized, BI/Compliance Ready, 2025
//

import Foundation

// MARK: - Audit/Event Logging

fileprivate struct CurrencyFormatterAuditEvent: Codable {
    let timestamp: Date
    let operation: String         // "update" | "format"
    let locale: String
    let currencyCode: String
    let value: Double?
    let formatted: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let errorDescription: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let valStr = value.map { "\($0)" } ?? "--"
        let out = formatted ?? ""
        return "\(op) \(currencyCode) (\(locale)): \(valStr) → \(out) at \(dateStr)"
    }
}

fileprivate final class CurrencyFormatterAudit {
    static private(set) var log: [CurrencyFormatterAuditEvent] = []

    static func record(
        operation: String,
        locale: Locale,
        currencyCode: String,
        value: Double?,
        formatted: String?,
        tags: [String],
        actor: String? = nil,
        context: String? = nil,
        error: Error? = nil
    ) {
        let event = CurrencyFormatterAuditEvent(
            timestamp: Date(),
            operation: operation,
            locale: locale.identifier,
            currencyCode: currencyCode,
            value: value,
            formatted: formatted,
            tags: tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        log.append(event)
        if log.count > 1000 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No currency events recorded."
    }
}

// MARK: - CurrencyFormatter (Modular, Tokenized, Auditable Currency Formatting Utility)

/// CurrencyFormatter is a modular, tokenized, auditable singleton utility designed to standardize currency display throughout Furfolio.
/// It supports localization, multi-currency handling, business logic overrides, analytics tracking, compliance requirements,
/// UI tokenization, audit trails, and dashboard integration. This utility is built to enable scalable, owner-focused dashboards and reporting,
/// ensuring consistent, compliant, and traceable monetary formatting across the entire application ecosystem.
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()

    /// The NumberFormatter instance used for all currency formatting.
    /// This formatter is configured to comply with locale and currency standards, ensuring auditability and UI consistency.
    private let formatter: NumberFormatter

    /// The default locale for formatting currency values.
    /// This property supports localization and multi-language workflows, enabling business and compliance requirements across regions.
    private(set) var locale: Locale

    /// The default currency code (e.g., "USD").
    /// This supports multi-currency business logic, analytics reporting, and audit trails for financial transactions.
    private(set) var currencyCode: String

    /// Private initializer to enforce singleton pattern.
    /// Initializes the formatter with the current locale and currency code, supporting audit and compliance from app launch.
    private init(locale: Locale = .current, currencyCode: String = Locale.current.currency?.identifier ?? "USD") {
        self.formatter = NumberFormatter()
        self.locale = locale
        self.currencyCode = currencyCode
        configureFormatter()
    }

    /// Update locale and currency code dynamically for multi-business or user preferences.
    /// This method supports audit/event logging, analytics tracking, and updates UI/dashboard components with the new settings.
    /// It ensures that currency formatting remains consistent with business context and compliance requirements.
    func update(locale: Locale, currencyCode: String, actor: String? = nil, context: String? = nil) {
        self.locale = locale
        self.currencyCode = currencyCode
        configureFormatter()
        CurrencyFormatterAudit.record(
            operation: "update",
            locale: locale,
            currencyCode: currencyCode,
            value: nil,
            formatted: nil,
            tags: ["update", "locale", "currency"],
            actor: actor,
            context: context
        )
    }

    /// Configure the NumberFormatter with current settings.
    /// This setup ensures compliance with regional currency formatting rules, supports audit trails by standardizing output,
    /// and applies UI formatting logic consistent with tokenized design standards.
    private func configureFormatter() {
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.usesGroupingSeparator = true
    }

    /// Format a given number as a localized currency string.
    /// Returns a localized string representation or a fallback string.
    /// This method supports audit logging of formatted values, analytics on currency usage,
    /// business reporting, dashboard visualization, and ensures localization compliance.
    func string(from amount: Double?, actor: String? = nil, context: String? = nil) -> String {
        guard let amount = amount else {
            CurrencyFormatterAudit.record(
                operation: "format",
                locale: locale,
                currencyCode: currencyCode,
                value: nil,
                formatted: "--",
                tags: ["format", "currency", "fallback"],
                actor: actor,
                context: context
            )
            return "--"
        }
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
        CurrencyFormatterAudit.record(
            operation: "format",
            locale: locale,
            currencyCode: currencyCode,
            value: amount,
            formatted: formatted,
            tags: ["format", "currency"],
            actor: actor,
            context: context
        )
        return formatted
    }

    // MARK: - Audit/Admin Accessors

    static var lastAuditSummary: String { CurrencyFormatterAudit.accessibilitySummary }
    static var lastAuditJSON: String? { CurrencyFormatterAudit.exportLastJSON() }
    static func recentAuditEvents(limit: Int = 5) -> [String] {
        CurrencyFormatterAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - SwiftUI Preview Example

#if DEBUG
import SwiftUI

struct CurrencyFormatterPreview: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            // Demo of formatted currency display using modular font tokens.
            // This preview demonstrates business logic for tokenized UI and audit-friendly formatting.
            Text(CurrencyFormatter.shared.string(from: 129.99, actor: "preview"))
                .font(AppFonts.title)
                .bold(AppFonts.bold)
                .accessibilityLabel("Formatted price")
            // Display fallback for nil amount with secondary text color for UI clarity.
            Text(CurrencyFormatter.shared.string(from: nil, actor: "preview"))
                .foregroundColor(AppColors.secondaryText)
                .accessibilityLabel("No price available")
            // Button to simulate switching currency context for multi-business and analytics demo.
            Button("Switch to Euro") {
                CurrencyFormatter.shared.update(locale: Locale(identifier: "fr_FR"), currencyCode: "EUR", actor: "preview")
            }
            // Debug: Show last audit event
            if let summary = CurrencyFormatter.lastAuditJSON {
                Text(summary)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 16)
            }
        }
        .padding(AppSpacing.medium)
    }
}

#Preview {
    CurrencyFormatterPreview()
}
#endif

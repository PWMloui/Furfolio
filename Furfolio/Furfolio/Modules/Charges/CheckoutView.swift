//
//  CheckoutView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//


// MARK: - Checkout Audit Model and Admin Enhancements

import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Represents a single checkout audit event.
struct CheckoutAudit: Identifiable {
    let id = UUID()
    let timestamp: Date
    let operation: String      // e.g., "checkout", "refund"
    let checkoutID: String
    let owner: String
    let dog: String
    let amount: Double
    let paymentMethod: String
    let items: [String]
    let discount: Double?
    let tax: Double?
    let notes: String?
    let tags: [String]?
    let detail: String?

    /// Static: Export all audit events as CSV string.
    /// Fields: timestamp,operation,checkoutID,owner,dog,amount,paymentMethod,items,discount,tax,notes,tags,detail
    static func exportCSV(_ audits: [CheckoutAudit]) -> String {
        let header = [
            "timestamp", "operation", "checkoutID", "owner", "dog", "amount",
            "paymentMethod", "items", "discount", "tax", "notes", "tags", "detail"
        ].joined(separator: ",")

        let rows = audits.map { audit in
            [
                ISO8601DateFormatter().string(from: audit.timestamp),
                audit.operation,
                audit.checkoutID,
                audit.owner,
                audit.dog,
                String(format: "%.2f", audit.amount),
                audit.paymentMethod,
                audit.items.joined(separator: ";"),
                audit.discount.map { String(format: "%.2f", $0) } ?? "",
                audit.tax.map { String(format: "%.2f", $0) } ?? "",
                audit.notes ?? "",
                audit.tags?.joined(separator: ";") ?? "",
                audit.detail ?? ""
            ]
            .map { field in
                // Escape commas and quotes for CSV
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
                } else {
                    return field
                }
            }
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Computed: Total number of "checkout" operations in the log.
    static func totalCheckouts(_ audits: [CheckoutAudit]) -> Int {
        audits.filter { $0.operation == "checkout" }.count
    }

    /// Computed: Average amount of all checkouts.
    static func averageCheckoutAmount(_ audits: [CheckoutAudit]) -> Double {
        let amounts = audits.map { $0.amount }
        guard !amounts.isEmpty else { return 0.0 }
        return amounts.reduce(0, +) / Double(amounts.count)
    }

    /// Computed: Most frequent payment method in the log.
    static func mostFrequentPaymentMethod(_ audits: [CheckoutAudit]) -> String? {
        let methods = audits.map { $0.paymentMethod }
        let counts = Dictionary(grouping: methods, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

/// Singleton admin for audit event storage and analytics.
class CheckoutAuditAdmin: ObservableObject {
    static let shared = CheckoutAuditAdmin()
    @Published private(set) var audits: [CheckoutAudit] = []

    private init() {}

    /// Add an audit event to the log.
    func log(_ audit: CheckoutAudit) {
        audits.append(audit)
    }

    /// Export all audit events as CSV.
    func exportCSV() -> String {
        CheckoutAudit.exportCSV(audits)
    }

    /// Total number of checkouts.
    var totalCheckouts: Int {
        CheckoutAudit.totalCheckouts(audits)
    }

    /// Average checkout amount.
    var averageCheckoutAmount: Double {
        CheckoutAudit.averageCheckoutAmount(audits)
    }

    /// Most frequent payment method.
    var mostFrequentPaymentMethod: String? {
        CheckoutAudit.mostFrequentPaymentMethod(audits)
    }
}

// MARK: - Accessibility: VoiceOver Announcement on Checkout
/// Posts a VoiceOver announcement for successful checkout.
func postCheckoutVoiceOverAnnouncement(dog: String, owner: String) {
#if canImport(UIKit)
    let announcement = "Checkout for \(dog) completed for \(owner)."
    UIAccessibility.post(notification: .announcement, argument: announcement)
#endif
}

// MARK: - DEV: Checkout Audit Summary Overlay (DEBUG builds only)
#if DEBUG
/// SwiftUI View: Shows summary of recent audit events and analytics for developers.
struct CheckoutAuditSummaryView: View {
    @ObservedObject var admin: CheckoutAuditAdmin = .shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Checkout Audit Summary")
                .font(.headline)
            if admin.audits.isEmpty {
                Text("No audit events.")
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(admin.audits.suffix(3).reversed()) { audit in
                        HStack {
                            Text(audit.operation.capitalized)
                            Text(audit.dog)
                            Text("by \(audit.owner)")
                            Text(String(format: "$%.2f", audit.amount))
                        }
                        .font(.caption)
                    }
                }
            }
            Divider()
            HStack {
                Text("Total checkouts: \(admin.totalCheckouts)")
                Spacer()
                Text(String(format: "Avg: $%.2f", admin.averageCheckoutAmount))
                Spacer()
                Text("Most Used: \(admin.mostFrequentPaymentMethod ?? "-")")
            }
            .font(.caption2)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        .padding([.leading, .trailing, .bottom])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Developer Checkout Audit Summary")
    }
}
#endif

// MARK: - Example CheckoutView (partial, for enhancements integration)

struct CheckoutView: View {
    // ... existing state and properties ...

    @ObservedObject private var auditAdmin = CheckoutAuditAdmin.shared
    @State private var showSuccess = false
    // Example checkout data, replace with actual app logic
    @State private var owner = "Jane Doe"
    @State private var dog = "Rover"
    @State private var checkoutAmount = 42.50
    @State private var paymentMethod = "Credit Card"
    @State private var items = ["Grooming", "Nail Trim"]
    @State private var notes: String? = nil
    @State private var tags: [String]? = ["VIP"]
    @State private var detail: String? = nil

    var body: some View {
        VStack {
            // ... your checkout form and controls ...
            Button("Complete Checkout") {
                let audit = CheckoutAudit(
                    timestamp: Date(),
                    operation: "checkout",
                    checkoutID: UUID().uuidString,
                    owner: owner,
                    dog: dog,
                    amount: checkoutAmount,
                    paymentMethod: paymentMethod,
                    items: items,
                    discount: nil,
                    tax: nil,
                    notes: notes,
                    tags: tags,
                    detail: detail
                )
                auditAdmin.log(audit)
                showSuccess = true
                // Accessibility: Post VoiceOver announcement
                postCheckoutVoiceOverAnnouncement(dog: dog, owner: owner)
            }
            .accessibilityLabel("Complete checkout for \(dog)")
            // ... other UI ...

            if showSuccess {
                Text("Checkout completed!").foregroundColor(.green)
            }

#if DEBUG
            // DEV overlay: Show audit summary at bottom in DEBUG builds
            Spacer()
            CheckoutAuditSummaryView(admin: auditAdmin)
#endif
        }
    }
}

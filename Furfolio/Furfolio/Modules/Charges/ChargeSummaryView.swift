//
//  ChargeSummaryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge Summary UI
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ChargeSummaryAuditEvent: Codable {
    let timestamp: Date
    let operation: String        // "appear", "summaryView", "breakdownView"
    let totalAmount: Double
    let chargeCount: Int
    let breakdown: [String: Double]?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(operation.capitalized)] Total: $\(String(format: "%.2f", totalAmount))"
        base += ", Charges: \(chargeCount)"
        if let breakdown, !breakdown.isEmpty {
            let items = breakdown.map { "\($0.key): $\(String(format: "%.2f", $0.value))" }
            base += " | Breakdown: [\(items.joined(separator: ", "))]"
        }
        if !tags.isEmpty { base += " [\(tags.joined(separator: ","))]" }
        base += " at \(dateStr)"
        if let detail { base += ": \(detail!)" }
        return base
    }
}

fileprivate final class ChargeSummaryAudit {
    static private(set) var log: [ChargeSummaryAuditEvent] = []

    static func record(
        operation: String,
        totalAmount: Double,
        chargeCount: Int,
        breakdown: [String: Double]? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = ChargeSummaryAuditEvent(
            timestamp: Date(),
            operation: operation,
            totalAmount: totalAmount,
            chargeCount: chargeCount,
            breakdown: breakdown,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 60 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge summary events recorded."
    }
}

// MARK: - ChargeSummaryView

struct ChargeSummaryView: View {
    let charges: [Charge]

    // MARK: - Computed Properties

    private var totalAmount: Double {
        charges.reduce(0) { $0 + $1.amount }
    }

    private var chargeCount: Int {
        charges.count
    }

    private var chargesByType: [String: Double] {
        Dictionary(grouping: charges, by: { $0.type })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            Text("Charge Summary")
                .font(AppFonts.title2Bold)
                .accessibilityAddTraits(.isHeader)

            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Total Revenue")
                        .font(AppFonts.headline)
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(AppFonts.largeTitle)
                        .foregroundColor(AppColors.success)
                        .accessibilityLabel("Total Revenue $\(Int(totalAmount)) dollars")
                }
                Spacer()
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Total Charges")
                        .font(AppFonts.headline)
                    Text("\(chargeCount)")
                        .font(AppFonts.largeTitle)
                        .accessibilityLabel("Total Charges \(chargeCount)")
                }
            }

            Divider()

            Text("Revenue by Charge Type")
                .font(AppFonts.headline)
                .padding(.bottom, AppSpacing.small)

            ForEach(chargesByType.sorted(by: { $0.key < $1.key }), id: \.key) { type, amount in
                HStack {
                    Text(type)
                    Spacer()
                    Text("$\(amount, specifier: "%.2f")")
                        .foregroundColor(AppColors.textPrimary)
                        .accessibilityLabel("\(type) revenue $\(Int(amount)) dollars")
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.background)
                .shadow(
                    color: AppShadows.medium.color,
                    radius: AppShadows.medium.radius,
                    x: AppShadows.medium.x,
                    y: AppShadows.medium.y
                )
        )
        .padding(AppSpacing.medium)
        .onAppear {
            ChargeSummaryAudit.record(
                operation: "appear",
                totalAmount: totalAmount,
                chargeCount: chargeCount,
                breakdown: chargesByType,
                tags: ["summary", "breakdown"]
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeSummaryAuditAdmin {
    public static var lastSummary: String { ChargeSummaryAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeSummaryAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeSummaryAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Charge Model

struct Charge: Identifiable, Equatable {
    var id: UUID
    var type: String
    var amount: Double
}

// MARK: - Preview

#if DEBUG
struct ChargeSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        ChargeSummaryView(charges: [
            Charge(id: UUID(), type: "Full Package", amount: 75),
            Charge(id: UUID(), type: "Basic Package", amount: 50),
            Charge(id: UUID(), type: "Nail Trim", amount: 15),
            Charge(id: UUID(), type: "Full Package", amount: 75)
        ])
        .previewLayout(.sizeThatFits)
    }
}
#endif

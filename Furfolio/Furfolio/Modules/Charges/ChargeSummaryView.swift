//
//  ChargeSummaryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge Summary UI
//

import SwiftUI
import AVFoundation

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
    
    // MARK: - CSV Export Enhancement
    /// Exports the last audit event as a CSV string with columns:
    /// timestamp, operation, totalAmount, chargeCount, breakdown, tags, detail
    static func exportCSV() -> String? {
        guard let last = log.last else { return nil }
        let dateFormatter = ISO8601DateFormatter()
        let timestampStr = dateFormatter.string(from: last.timestamp)
        let breakdownStr: String
        if let breakdown = last.breakdown, !breakdown.isEmpty {
            // Convert breakdown dictionary to key=value pairs separated by ';'
            breakdownStr = breakdown.map { "\($0.key)=\($0.value)" }.joined(separator: ";")
        } else {
            breakdownStr = ""
        }
        let tagsStr = last.tags.joined(separator: ";")
        // Escape detail for CSV if needed
        let detailStr: String
        if let detail = last.detail {
            if detail.contains(",") || detail.contains("\"") || detail.contains("\n") {
                let escaped = detail.replacingOccurrences(of: "\"", with: "\"\"")
                detailStr = "\"\(escaped)\""
            } else {
                detailStr = detail
            }
        } else {
            detailStr = ""
        }
        // Compose CSV line
        let csvLine = "\(timestampStr),\(last.operation),\(last.totalAmount),\(last.chargeCount),\(breakdownStr),\(tagsStr),\(detailStr)"
        return csvLine
    }
    
    // MARK: - Analytics Enhancements
    
    /// Computes the average of all totalAmount values in the audit log.
    static var averageChargeAmount: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.totalAmount }
        return total / Double(log.count)
    }
    
    /// Determines the most frequent charge type across all breakdowns in audit log.
    /// Returns nil if no breakdown data is available.
    static var mostFrequentChargeType: String? {
        var frequency: [String: Int] = [:]
        for event in log {
            if let breakdown = event.breakdown {
                for (type, _) in breakdown {
                    frequency[type, default: 0] += 1
                }
            }
        }
        return frequency.max(by: { $0.value < $1.value })?.key
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
            // MARK: - Accessibility Enhancement: VoiceOver announcement if no charges
            if totalAmount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, argument: "No charges recorded this period.")
                }
            }
        }
        // MARK: - DEV Overlay Enhancement: Show last 3 audit events, averageChargeAmount, mostFrequentChargeType
        #if DEBUG
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("DEV AUDIT LOG (Last 3 Events):")
                    .font(.caption).bold()
                ForEach(Array(ChargeSummaryAudit.log.suffix(3).enumerated()), id: \.offset) { _, event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(String(format: "Average Charge Amount: $%.2f", ChargeSummaryAudit.averageChargeAmount))
                    .font(.caption2)
                Text("Most Frequent Charge Type: \(ChargeSummaryAudit.mostFrequentChargeType ?? "N/A")")
                    .font(.caption2)
            }
            .padding(8)
            .background(Color.black.opacity(0.75))
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding()
            , alignment: .bottom
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeSummaryAuditAdmin {
    public static var lastSummary: String { ChargeSummaryAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeSummaryAudit.exportLastJSON() }
    
    // MARK: - Expose CSV export to Admin
    public static var lastCSV: String? { ChargeSummaryAudit.exportCSV() }
    
    // MARK: - Expose Analytics properties to Admin
    public static var averageChargeAmount: Double { ChargeSummaryAudit.averageChargeAmount }
    public static var mostFrequentChargeType: String? { ChargeSummaryAudit.mostFrequentChargeType }
    
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

//
//  ExpenseBreakdownWidget.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Expense Breakdown Widget
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ExpenseBreakdownAuditEvent: Codable {
    let timestamp: Date
    let segmentCount: Int
    let categories: [String]
    let valueRange: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] ExpenseBreakdown: \(segmentCount) categories, \(valueRange), categories: [\(categories.joined(separator: ", "))] [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

/// Audit/event logger for ExpenseBreakdownWidget.
/// Includes analytics, CSV export, and accessibility logic.
fileprivate final class ExpenseBreakdownAudit {
    static private(set) var log: [ExpenseBreakdownAuditEvent] = []

    /// Records an audit event and maintains log size.
    /// Posts VoiceOver announcement if segmentCount > 5 for accessibility.
    static func record(
        segmentCount: Int,
        categories: [String],
        valueRange: String,
        tags: [String] = ["expenseBreakdown"]
    ) {
        let event = ExpenseBreakdownAuditEvent(
            timestamp: Date(),
            segmentCount: segmentCount,
            categories: categories,
            valueRange: valueRange,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }

        // Accessibility enhancement: Announce if > 5 segments.
        if segmentCount > 5 {
            #if os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIAccessibility.post(notification: .announcement, argument: "Pie chart has more than five expense categories.")
            }
            #endif
        }
    }

    /// Exports the last audit event as JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Exports all audit events as CSV.
    /// CSV columns: timestamp,segmentCount,categories,valueRange,tags
    static func exportCSV() -> String {
        var rows: [String] = ["timestamp,segmentCount,categories,valueRange,tags"]
        let df = ISO8601DateFormatter()
        for event in log {
            let ts = df.string(from: event.timestamp)
            let seg = "\(event.segmentCount)"
            let cats = "\"\(event.categories.joined(separator: ";"))\""
            let vr = "\"\(event.valueRange.replacingOccurrences(of: "\"", with: "'"))\""
            let tags = "\"\(event.tags.joined(separator: ";"))\""
            rows.append([ts, seg, cats, vr, tags].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    /// Accessibility summary of last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No expense breakdown events recorded."
    }
    /// Returns recent events' accessibility labels.
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }

    /// Analytics: Average segment count of all audit events.
    static var averageSegmentCount: Double {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.segmentCount }
        return Double(total) / Double(log.count)
    }

    /// Analytics: Most frequent category name across all audit events.
    static var mostFrequentCategory: String? {
        let allCats = log.flatMap { $0.categories }
        guard !allCats.isEmpty else { return nil }
        let counts = Dictionary(grouping: allCats, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Model

public struct ExpenseCategory: Identifiable {
    public let id = UUID()
    public let name: String
    public let amount: Double
    public let color: Color

    public init(name: String, amount: Double, color: Color) {
        self.name = name
        self.amount = amount
        self.color = color
    }
}

// MARK: - ExpenseBreakdownWidget

public struct ExpenseBreakdownWidget: View {
    public let categories: [ExpenseCategory]

    private var total: Double { categories.reduce(0) { $0 + $1.amount } }
    private var valueRange: String {
        guard let min = categories.map(\.amount).min(),
              let max = categories.map(\.amount).max() else { return "n/a" }
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.maximumFractionDigits = 0; nf.currencySymbol = "$"
        let minStr = nf.string(from: NSNumber(value: min)) ?? "$0"
        let maxStr = nf.string(from: NSNumber(value: max)) ?? "$0"
        return "min \(minStr), max \(maxStr)"
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("Expense Breakdown")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)
                .accessibilityIdentifier("ExpenseBreakdownWidget-Header")

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                ZStack {
                    ForEach(categories.indices, id: \.self) { idx in
                        let startAngle = angle(for: idx)
                        let endAngle = angle(for: idx + 1)
                        PieSegmentShape(startAngle: startAngle, endAngle: endAngle)
                            .fill(categories[idx].color)
                            .overlay(
                                PieSegmentShape(startAngle: startAngle, endAngle: endAngle)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .accessibilityLabel("\(categories[idx].name), \(percentage(for: categories[idx]))% (\(currencyString(categories[idx].amount)))")
                            .accessibilityIdentifier("ExpenseBreakdownWidget-Segment-\(categories[idx].name)")
                    }
                    VStack {
                        Text(currencyString(total))
                            .font(.title.bold())
                            .accessibilityIdentifier("ExpenseBreakdownWidget-CenterTotal")
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: size, height: size)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(height: 220)
            .accessibilityIdentifier("ExpenseBreakdownWidget-PieChart")

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(categories.indices, id: \.self) { idx in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categories[idx].color)
                            .frame(width: 18, height: 18)
                        Text(categories[idx].name)
                            .font(.subheadline)
                        Text(currencyString(categories[idx].amount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityIdentifier("ExpenseBreakdownWidget-Legend-\(categories[idx].name)")
                }
            }
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Expense categories: \(categories.map { $0.name }.joined(separator: ", "))")
            .accessibilityIdentifier("ExpenseBreakdownWidget-Legend")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Expense breakdown pie chart with \(categories.count) categories, \(valueRange)")
        .accessibilityIdentifier("ExpenseBreakdownWidget-Container")
        .onAppear {
            ExpenseBreakdownAudit.record(
                segmentCount: categories.count,
                categories: categories.map { $0.name },
                valueRange: valueRange
            )
        }
    }

    private func angle(for index: Int) -> Angle {
        let sum = categories.prefix(index).reduce(0) { $0 + $1.amount }
        return .degrees((sum / max(total, 1)) * 360 - 90)
    }
    private func percentage(for category: ExpenseCategory) -> String {
        total > 0 ? String(format: "%.1f", (category.amount / total) * 100) : "0"
    }
    private func currencyString(_ value: Double) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .currency; nf.maximumFractionDigits = 0; nf.currencySymbol = "$"
        return nf.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - PieSegmentShape

private struct PieSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Audit/Admin Accessors

/// Admin/audit API for ExpenseBreakdownWidget.
/// Exposes summaries, analytics, and CSV export.
public enum ExpenseBreakdownWidgetAuditAdmin {
    /// Last event's accessibility summary.
    public static var lastSummary: String { ExpenseBreakdownAudit.accessibilitySummary }
    /// Last event as JSON.
    public static var lastJSON: String? { ExpenseBreakdownAudit.exportLastJSON() }
    /// Recent event summaries.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ExpenseBreakdownAudit.recentEvents(limit: limit)
    }
    /// Exports all audit events as CSV.
    public static func exportCSV() -> String { ExpenseBreakdownAudit.exportCSV() }
    /// Analytics: Average segment count.
    public static var averageSegmentCount: Double { ExpenseBreakdownAudit.averageSegmentCount }
    /// Analytics: Most frequent category.
    public static var mostFrequentCategory: String? { ExpenseBreakdownAudit.mostFrequentCategory }
}

// MARK: - Preview

#if DEBUG
/// DEV overlay for audit analytics and recent events.
fileprivate struct ExpenseBreakdownDevOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEV: Audit Log (last 3)")
                .font(.caption.bold())
                .foregroundColor(.blue)
            ForEach(Array(ExpenseBreakdownAudit.log.suffix(3).enumerated()), id: \.offset) { idx, event in
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(idx + 1). \(event.accessibilityLabel)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Divider()
            Text(String(format: "Average segments: %.2f", ExpenseBreakdownAudit.averageSegmentCount))
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("Most frequent category: \(ExpenseBreakdownAudit.mostFrequentCategory ?? "-")")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 1)
        )
        .padding(.top, 12)
    }
}

struct ExpenseBreakdownWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = [
            ExpenseCategory(name: "Supplies", amount: 440, color: .blue),
            ExpenseCategory(name: "Wages", amount: 1650, color: .green),
            ExpenseCategory(name: "Rent", amount: 890, color: .purple),
            ExpenseCategory(name: "Utilities", amount: 210, color: .orange),
            ExpenseCategory(name: "Other", amount: 80, color: .pink),
            ExpenseCategory(name: "Travel", amount: 120, color: .red)
        ]
        ZStack(alignment: .bottom) {
            ExpenseBreakdownWidget(categories: sample)
                .frame(width: 340, height: 340)
                .previewLayout(.sizeThatFits)
            ExpenseBreakdownDevOverlay()
                .frame(maxWidth: .infinity)
        }
    }
}
#endif

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

fileprivate final class ExpenseBreakdownAudit {
    static private(set) var log: [ExpenseBreakdownAuditEvent] = []

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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No expense breakdown events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
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

public enum ExpenseBreakdownWidgetAuditAdmin {
    public static var lastSummary: String { ExpenseBreakdownAudit.accessibilitySummary }
    public static var lastJSON: String? { ExpenseBreakdownAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ExpenseBreakdownAudit.recentEvents(limit: limit)
    }
}

// MARK: - Preview

#if DEBUG
struct ExpenseBreakdownWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sample = [
            ExpenseCategory(name: "Supplies", amount: 440, color: .blue),
            ExpenseCategory(name: "Wages", amount: 1650, color: .green),
            ExpenseCategory(name: "Rent", amount: 890, color: .purple),
            ExpenseCategory(name: "Utilities", amount: 210, color: .orange),
            ExpenseCategory(name: "Other", amount: 80, color: .pink)
        ]
        ExpenseBreakdownWidget(categories: sample)
            .frame(width: 340, height: 340)
            .previewLayout(.sizeThatFits)
    }
}
#endif

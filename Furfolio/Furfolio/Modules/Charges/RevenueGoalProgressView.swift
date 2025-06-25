//
//  RevenueGoalProgressView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Revenue Goal Progress UI
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct RevenueGoalProgressAuditEvent: Codable {
    let timestamp: Date
    let currentRevenue: Double
    let goalRevenue: Double
    let progress: Double
    let color: String
    let label: String?
    let tags: [String]
    var accessibilityLabel: String {
        let percent = Int(progress * 100)
        let colorText = color.capitalized
        let base = "\(label ?? "Revenue progress"): \(percent)% (\(currentRevenue) of \(goalRevenue)), Color: \(colorText)"
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(base) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class RevenueGoalProgressAudit {
    static private(set) var log: [RevenueGoalProgressAuditEvent] = []

    static func record(
        currentRevenue: Double,
        goalRevenue: Double,
        progress: Double,
        color: Color,
        label: String?,
        tags: [String] = []
    ) {
        let colorDesc: String
        switch color {
        case .green: colorDesc = "green"
        case .orange: colorDesc = "orange"
        case .red: colorDesc = "red"
        default: colorDesc = color.description
        }
        let event = RevenueGoalProgressAuditEvent(
            timestamp: Date(),
            currentRevenue: currentRevenue,
            goalRevenue: goalRevenue,
            progress: progress,
            color: colorDesc,
            label: label,
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
        log.last?.accessibilityLabel ?? "No revenue goal events recorded."
    }
}

// MARK: - RevenueGoalProgressView

struct RevenueGoalProgressView: View {
    var currentRevenue: Double
    var goalRevenue: Double
    var label: String?

    private var progress: Double {
        guard goalRevenue > 0 else { return 0 }
        return min(currentRevenue / goalRevenue, 1.0)
    }

    private var progressColor: Color {
        switch progress {
        case 0.75...1.0:
            return .green
        case 0.5..<0.75:
            return .orange
        default:
            return .red
        }
    }

    private var formattedCurrentRevenue: String {
        CurrencyFormatter.shared.string(from: currentRevenue)
    }

    private var formattedGoalRevenue: String {
        CurrencyFormatter.shared.string(from: goalRevenue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.headline)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 22)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: 22)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 22)

            HStack {
                Text(formattedCurrentRevenue)
                    .font(.subheadline).bold()
                Spacer()
                Text("Goal: \(formattedGoalRevenue)")
                    .font(.subheadline)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            RevenueGoalProgressAudit.record(
                currentRevenue: currentRevenue,
                goalRevenue: goalRevenue,
                progress: progress,
                color: progressColor,
                label: label,
                tags: ["revenueGoal", "progress"]
            )
        }
    }

    private var accessibilityLabel: String {
        let labelText = label ?? "Revenue progress"
        return "\(labelText), \(formattedCurrentRevenue) out of \(formattedGoalRevenue)"
    }
}

// MARK: - Audit/Admin Accessors

public enum RevenueGoalProgressAuditAdmin {
    public static var lastSummary: String { RevenueGoalProgressAudit.accessibilitySummary }
    public static var lastJSON: String? { RevenueGoalProgressAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        RevenueGoalProgressAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// Shared currency formatter
final class CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private let formatter: NumberFormatter

    private init() {
        formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
    }

    func string(from value: Double) -> String {
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#if DEBUG
struct RevenueGoalProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            RevenueGoalProgressView(currentRevenue: 7500, goalRevenue: 10000, label: "Monthly Revenue")
            RevenueGoalProgressView(currentRevenue: 4000, goalRevenue: 10000, label: "Monthly Revenue")
            RevenueGoalProgressView(currentRevenue: 2000, goalRevenue: 10000, label: "Monthly Revenue")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

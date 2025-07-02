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

/// Audit/event logger for RevenueGoalProgressView, with analytics and export enhancements.
fileprivate final class RevenueGoalProgressAudit {
    static private(set) var log: [RevenueGoalProgressAuditEvent] = []

    /// Record an audit event for a revenue goal progress update.
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

    /// Export the most recent audit event as pretty JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Export all audit events as CSV.
    /// Columns: timestamp,currentRevenue,goalRevenue,progress,color,label,tags
    static func exportCSV() -> String {
        let header = "timestamp,currentRevenue,goalRevenue,progress,color,label,tags"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event in
            let dateStr = formatter.string(from: event.timestamp)
            let label = event.label?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tags = event.tags.joined(separator: "|").replacingOccurrences(of: "\"", with: "\"\"")
            return """
\(dateStr),\(event.currentRevenue),\(event.goalRevenue),\(event.progress),\(event.color),"\(label)","\(
tags)"
"""
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Accessibility summary for the most recent event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No revenue goal events recorded."
    }

    /// The mean of all progress values in the audit log.
    static var averageProgress: Double {
        guard !log.isEmpty else { return 0 }
        let sum = log.reduce(0.0) { $0 + $1.progress }
        return sum / Double(log.count)
    }

    /// The most frequent progress bar color as a string.
    static var mostFrequentColor: String {
        let colorCounts = Dictionary(grouping: log, by: { $0.color })
            .mapValues { $0.count }
        guard let (color, _) = colorCounts.max(by: { $0.value < $1.value }) else {
            return "n/a"
        }
        return color
    }
}

// MARK: - RevenueGoalProgressView

/// RevenueGoalProgressView displays a visual progress bar for revenue goals, with audit, analytics, and accessibility enhancements.
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

    /// Used to trigger accessibility announcements for progress < 50%.
    @State private var didAnnounceLowProgress: Bool = false

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
            // Audit logging
            RevenueGoalProgressAudit.record(
                currentRevenue: currentRevenue,
                goalRevenue: goalRevenue,
                progress: progress,
                color: progressColor,
                label: label,
                tags: ["revenueGoal", "progress"]
            )
            // Accessibility: Announce if progress < 50%
            if progress < 0.5 && !didAnnounceLowProgress {
                announceLowProgress()
                didAnnounceLowProgress = true
            }
        }
#if DEBUG
        .overlay(
            DevAuditOverlay()
            , alignment: .bottom
        )
#endif
    }

    private var accessibilityLabel: String {
        let labelText = label ?? "Revenue progress"
        return "\(labelText), \(formattedCurrentRevenue) out of \(formattedGoalRevenue)"
    }

    /// Posts a VoiceOver announcement for low progress (<50%).
    private func announceLowProgress() {
        #if canImport(UIKit)
        UIAccessibility.post(
            notification: .announcement,
            argument: "Warning: Revenue progress below 50 percent."
        )
        #endif
    }

#if DEBUG
    /// DEV overlay showing last 3 audit events, average progress, and most frequent color.
    @ViewBuilder
    private func DevAuditOverlay() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AUDIT (last 3):")
                .font(.caption2).bold()
            ForEach(Array(RevenueGoalProgressAudit.log.suffix(3).enumerated()), id: \.offset) { idx, event in
                Text("• \(event.accessibilityLabel)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            HStack(spacing: 16) {
                Text("Avg progress: \(String(format: "%.1f", RevenueGoalProgressAudit.averageProgress * 100))%")
                    .font(.caption2)
                Text("Top color: \(RevenueGoalProgressAudit.mostFrequentColor.capitalized)")
                    .font(.caption2)
            }
        }
        .padding(6)
        .background(Color(.systemGray6).opacity(0.9))
        .cornerRadius(8)
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }
#endif
}

// MARK: - Audit/Admin Accessors

/// Admin accessors for RevenueGoalProgressAudit, exposing analytics and exports.
public enum RevenueGoalProgressAuditAdmin {
    /// Accessibility summary for the last event.
    public static var lastSummary: String { RevenueGoalProgressAudit.accessibilitySummary }
    /// Most recent audit event as JSON.
    public static var lastJSON: String? { RevenueGoalProgressAudit.exportLastJSON() }
    /// Last N events as accessibility labels.
    public static func recentEvents(limit: Int = 5) -> [String] {
        RevenueGoalProgressAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Export all audit events as CSV.
    public static func exportCSV() -> String {
        RevenueGoalProgressAudit.exportCSV()
    }
    /// Mean of all progress values in the audit log.
    public static var averageProgress: Double {
        RevenueGoalProgressAudit.averageProgress
    }
    /// Most frequent color string in the audit log.
    public static var mostFrequentColor: String {
        RevenueGoalProgressAudit.mostFrequentColor
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

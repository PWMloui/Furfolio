//
//  MetricCard.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Metric Card
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct MetricCardAuditEvent: Codable {
    let timestamp: Date
    let metric: String
    let value: String
    let icon: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(metric): \(value), icon: \(icon) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class MetricCardAudit {
    static private(set) var log: [MetricCardAuditEvent] = []

    static func record(
        metric: String,
        value: String,
        icon: String,
        tags: [String] = ["MetricCard"]
    ) {
        let event = MetricCardAuditEvent(
            timestamp: Date(),
            metric: metric,
            value: value,
            icon: icon,
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
        log.last?.accessibilityLabel ?? "No MetricCard events recorded."
    }

    /// Export the audit log as CSV (timestamp, metric, value, icon, tags)
    static func exportCSV() -> String {
        var csv = "timestamp,metric,value,icon,tags\n"
        let dateFormatter = ISO8601DateFormatter()
        for event in log {
            let ts = dateFormatter.string(from: event.timestamp)
            let metric = event.metric.replacingOccurrences(of: ",", with: ";")
            let value = event.value.replacingOccurrences(of: ",", with: ";")
            let icon = event.icon
            let tags = event.tags.joined(separator: "|")
            csv += "\(ts),\(metric),\(value),\(icon),\(tags)\n"
        }
        return csv
    }

    /// The metric title that appeared most often.
    static var mostFrequentMetric: String? {
        let metrics = log.map { $0.metric }
        let counts = Dictionary(grouping: metrics, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// The value that appeared most often (as String).
    static var mostFrequentValue: String? {
        let values = log.map { $0.value }
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Total MetricCard appearances (for analytics).
    static var totalCardsShown: Int { log.count }
}

// MARK: - MetricCard

struct MetricCard: View {
    let metric: String
    let value: String
    let icon: String
    let iconColor: Color

    #if DEBUG
    @State private var showAuditOverlay = false
    #endif

    var body: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("MetricCard-IconBG-\(metric)")
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .medium))
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("MetricCard-Icon-\(metric)")
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("MetricCard-Title-\(metric)")
                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                        .accessibilityIdentifier("MetricCard-Value-\(metric)")
                }
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(metric), value \(value)")
            .accessibilityIdentifier("MetricCard-Container-\(metric)")
            .onAppear {
                MetricCardAudit.record(
                    metric: metric,
                    value: value,
                    icon: icon
                )
                // Announce for accessibility
                #if os(iOS)
                UIAccessibility.post(notification: .announcement, argument: "\(metric) stat card shown. Value: \(value).")
                #endif
            }

            #if DEBUG
            // DEV overlay at bottom
            if showAuditOverlay {
                MetricCardAuditOverlayView()
                    .onTapGesture { showAuditOverlay = false }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            #endif
        }
        #if DEBUG
        .onLongPressGesture {
            withAnimation { showAuditOverlay.toggle() }
        }
        #endif
    }
}

// MARK: - DEV Overlay View

#if DEBUG
struct MetricCardAuditOverlayView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MetricCard Audit")
                .font(.caption.bold())
                .foregroundColor(.accentColor)
            ForEach(MetricCardAudit.log.suffix(3), id: \.timestamp) { event in
                Text(event.accessibilityLabel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let mostMetric = MetricCardAudit.mostFrequentMetric {
                Text("Most Frequent: \(mostMetric)").font(.caption2)
            }
            if let mostValue = MetricCardAudit.mostFrequentValue {
                Text("Top Value: \(mostValue)").font(.caption2)
            }
            Text("Total: \(MetricCardAudit.totalCardsShown)").font(.caption2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).opacity(0.92))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .shadow(radius: 2)
    }
}
#endif

// MARK: - Audit/Admin Accessors

public enum MetricCardAuditAdmin {
    public static var lastSummary: String { MetricCardAudit.accessibilitySummary }
    public static var lastJSON: String? { MetricCardAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        MetricCardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Export full audit log as CSV.
    public static func exportCSV() -> String { MetricCardAudit.exportCSV() }
    /// Analytics
    public static var mostFrequentMetric: String? { MetricCardAudit.mostFrequentMetric }
    public static var mostFrequentValue: String? { MetricCardAudit.mostFrequentValue }
    public static var totalCardsShown: Int { MetricCardAudit.totalCardsShown }
}

#if DEBUG
struct MetricCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MetricCard(metric: "Total Revenue", value: "$12,345", icon: "dollarsign.circle.fill", iconColor: .green)
            MetricCard(metric: "Upcoming Appointments", value: "5", icon: "calendar", iconColor: .blue)
            MetricCard(metric: "Inactive Customers", value: "3", icon: "person.fill.xmark", iconColor: .red)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

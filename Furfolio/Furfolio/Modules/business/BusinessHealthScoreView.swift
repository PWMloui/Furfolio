//
//  BusinessHealthScoreView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Business Health Score UI
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct BusinessHealthAuditEvent: Codable {
    let timestamp: Date
    let score: Int
    let scoreColor: String
    let statusLabel: String
    let statusMessage: String
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Health Score: \(score) (\(statusLabel)), color: \(scoreColor) [\(tags.joined(separator: ","))] at \(dateStr): \(statusMessage)"
    }
}

fileprivate final class BusinessHealthAudit {
    static private(set) var log: [BusinessHealthAuditEvent] = []

    /// Records a new audit event with the given parameters.
    static func record(
        score: Int,
        color: Color,
        label: String,
        message: String,
        tags: [String] = ["businessHealthScore"]
    ) {
        let colorDesc: String
        switch color {
        case .green: colorDesc = "green"
        case .yellow: colorDesc = "yellow"
        case .red: colorDesc = "red"
        default: colorDesc = color.description
        }
        let event = BusinessHealthAuditEvent(
            timestamp: Date(),
            score: score,
            scoreColor: colorDesc,
            statusLabel: label,
            statusMessage: message,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for the most recent audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No business health score events recorded."
    }

    // MARK: - Business, Analytics, and Accessibility Enhancements

    /// Exports the entire audit log as a CSV string with headers.
    /// CSV columns: timestamp,score,scoreColor,statusLabel,statusMessage,tags
    static func exportCSV() -> String {
        let header = "timestamp,score,scoreColor,statusLabel,statusMessage,tags"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event in
            let timestamp = formatter.string(from: event.timestamp)
            let escapedStatusMessage = event.statusMessage.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedStatusLabel = event.statusLabel.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedScoreColor = event.scoreColor.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedTags = event.tags.map { $0.replacingOccurrences(of: "\"", with: "\"\"") }.joined(separator: ";")
            // Wrap fields that may contain commas or quotes in quotes
            return "\"\(timestamp)\",\(event.score),\"\(escapedScoreColor)\",\"\(escapedStatusLabel)\",\"\(escapedStatusMessage)\",\"\(escapedTags)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Computes the average score from all audit events, or nil if none.
    static var averageScore: Double? {
        guard !log.isEmpty else { return nil }
        let total = log.reduce(0) { $0 + $1.score }
        return Double(total) / Double(log.count)
    }

    /// Computes the distribution of scores by status label.
    /// Returns a dictionary mapping status label to count.
    static var scoreDistribution: [String: Int] {
        var distribution: [String: Int] = [:]
        for event in log {
            distribution[event.statusLabel, default: 0] += 1
        }
        return distribution
    }

    /// Returns the last score with "Critical" status label, or nil if none.
    static var lastCriticalScore: Int? {
        log.reversed().first(where: { $0.statusLabel == "Critical" })?.score
    }
}

// MARK: - BusinessHealthScoreView

struct BusinessHealthScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 75...100:
            return .green
        case 50..<75:
            return .yellow
        default:
            return .red
        }
    }

    private var healthStatusLabel: String {
        switch score {
        case 75...100:
            return "Excellent"
        case 50..<75:
            return "Moderate"
        default:
            return "Critical"
        }
    }

    private var statusMessage: String {
        switch score {
        case 75...100:
            return "Your business is thriving. Great customer retention and solid growth!"
        case 50..<75:
            return "Your business is stable but could benefit from better appointment frequency or revenue improvements."
        default:
            return "Your business needs attention. Consider retention strategies or re-engagement campaigns."
        }
    }

    @Environment(\.accessibilityEnabled) private var accessibilityEnabled
    @State private var accessibilityAnnouncementCancellable: AnyCancellable?

    var body: some View {
        VStack(spacing: 12) {
            Text("Business Health Score")
                .font(.headline)
                .foregroundColor(.primary)

            Text("\(score)")
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(scoreColor)

            Text(healthStatusLabel)
                .font(.subheadline.weight(.medium))
                .foregroundColor(scoreColor)

            Text(statusMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 3)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Business health score is \(score), rated as \(healthStatusLabel). \(statusMessage)")
        .onAppear {
            BusinessHealthAudit.record(
                score: score,
                color: scoreColor,
                label: healthStatusLabel,
                message: statusMessage
            )
            // Accessibility: If score is Critical, post a VoiceOver announcement.
            if accessibilityEnabled && healthStatusLabel == "Critical" {
                // Post announcement with slight delay to ensure it is heard after the view appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    UIAccessibility.post(notification: .announcement, argument: "Alert: Business health score is critical.")
                }
            }
        }
        #if DEBUG
        .overlay(
            // DEV overlay showing audit analytics and recent events
            VStack(spacing: 6) {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEV Audit Overlay")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    if let avg = BusinessHealthAudit.averageScore {
                        Text(String(format: "Average Score: %.1f", avg))
                            .font(.caption2)
                    } else {
                        Text("Average Score: N/A")
                            .font(.caption2)
                    }
                    Text("Score Distribution:")
                        .font(.caption2)
                    ForEach(BusinessHealthAudit.scoreDistribution.sorted(by: { $0.key < $1.key }), id: \.key) { key, count in
                        Text("• \(key): \(count)")
                            .font(.caption2)
                    }
                    if let lastCritical = BusinessHealthAudit.lastCriticalScore {
                        Text("Last Critical Score: \(lastCritical)")
                            .font(.caption2)
                    } else {
                        Text("Last Critical Score: None")
                            .font(.caption2)
                    }
                    Text("Recent Events:")
                        .font(.caption2)
                    ForEach(BusinessHealthAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .padding(8)
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
            , alignment: .bottom
        )
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum BusinessHealthAuditAdmin {
    public static var lastSummary: String { BusinessHealthAudit.accessibilitySummary }
    public static var lastJSON: String? { BusinessHealthAudit.exportLastJSON() }
    // Expose CSV export method
    public static func exportCSV() -> String { BusinessHealthAudit.exportCSV() }
    // Expose analytics properties
    public static var averageScore: Double? { BusinessHealthAudit.averageScore }
    public static var scoreDistribution: [String: Int] { BusinessHealthAudit.scoreDistribution }
    public static var lastCriticalScore: Int? { BusinessHealthAudit.lastCriticalScore }
    public static func recentEvents(limit: Int = 5) -> [String] {
        BusinessHealthAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct BusinessHealthScoreView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BusinessHealthScoreView(score: 85)
            BusinessHealthScoreView(score: 65)
            BusinessHealthScoreView(score: 40)
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

//
// MARK: - ChargeTagView (Tokenized, Modular, Auditable Charge Category Tag View)
//  ChargeTagView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular, Analytics-Ready Tag View
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ChargeTagAuditEvent: Codable {
    let timestamp: Date
    let text: String
    let colorDescription: String
    let tags: [String]
    let context: String
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Tag: \(text), Color: \(colorDescription) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

/// Audit log for ChargeTagView events, with analytics and export utilities.
fileprivate final class ChargeTagAudit {
    static private(set) var log: [ChargeTagAuditEvent] = []

    /// Record a new tag event.
    static func record(
        text: String,
        color: Color,
        tags: [String] = [],
        context: String = "ChargeTagView"
    ) {
        let event = ChargeTagAuditEvent(
            timestamp: Date(),
            text: text,
            colorDescription: color.description,
            tags: tags,
            context: context
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
    }

    /// Export the last audit event as pretty-printed JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Export all audit events as CSV.
    /// Columns: timestamp,text,colorDescription,tags,context
    static func exportCSV() -> String {
        let header = "timestamp,text,colorDescription,tags,context"
        let rows = log.map { event in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: "|")
            // Escape commas and quotes for CSV
            func csvEscape(_ s: String) -> String {
                if s.contains(",") || s.contains("\"") || s.contains("\n") {
                    return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
                }
                return s
            }
            return [
                dateStr,
                csvEscape(event.text),
                csvEscape(event.colorDescription),
                csvEscape(tagsStr),
                csvEscape(event.context)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Accessibility label for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tag events recorded."
    }

    /// The tag text with the highest frequency in the log.
    static var mostFrequentTagText: String? {
        let counts = log.reduce(into: [String: Int]()) { dict, event in
            dict[event.text, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of tag appearances in the audit log.
    static var totalTagEvents: Int {
        log.count
    }
}

// MARK: - ChargeTagView

/// A reusable, modular, tokenized, and auditable view for displaying charge category tags.
/// This view supports business analytics, accessibility, localization, and integration with the UI design system.
/// A reusable, modular, tokenized, and auditable view for displaying charge category tags.
/// This view supports business analytics, accessibility, localization, and integration with the UI design system.
struct ChargeTagView: View {
    let text: String
    var color: Color = AppColors.accent // Use tokenized accent color for consistency

    // Accessibility: announce tag on appear.
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    var body: some View {
        ZStack(alignment: .bottom) {
            Text(text)
                .font(AppFonts.captionSemibold) // Use tokenized font for maintainability
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(color.opacity(0.15)) // Use tokenized opacity for background fill
                )
                .foregroundColor(color) // Use tokenized foreground color
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(text) tag")
                .onAppear {
                    // Audit: record event
                    ChargeTagAudit.record(
                        text: text,
                        color: color,
                        tags: ["charge", "tag", text]
                    )
                    // Accessibility: announce tag display
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        #if os(iOS)
                        UIAccessibility.post(notification: .announcement, argument: "\(text) tag displayed")
                        #endif
                    }
                }

#if DEBUG
            // DEV overlay: show last 3 audit events and most frequent tag
            VStack(spacing: 2) {
                let events = ChargeTagAudit.log.suffix(3)
                if !events.isEmpty {
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                        Text("• \(event.text) (\(event.colorDescription))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                if let mostFrequent = ChargeTagAudit.mostFrequentTagText {
                    Text("Most frequent: \(mostFrequent)")
                        .font(.caption2.bold())
                        .foregroundColor(.accentColor)
                }
            }
            .padding(6)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(radius: 1)
            .padding(.bottom, -32)
            .transition(.opacity)
#endif
        }
    }
}

// MARK: - Audit/Admin Accessors

/// Public admin/analytics interface for ChargeTagAudit
public enum ChargeTagAuditAdmin {
    /// Last event's accessibility summary
    public static var lastSummary: String { ChargeTagAudit.accessibilitySummary }
    /// Last event as JSON
    public static var lastJSON: String? { ChargeTagAudit.exportLastJSON() }
    /// Export all audit events as CSV (timestamp,text,colorDescription,tags,context)
    public static func exportCSV() -> String { ChargeTagAudit.exportCSV() }
    /// Most frequent tag text in the audit log
    public static var mostFrequentTagText: String? { ChargeTagAudit.mostFrequentTagText }
    /// Total tag events in the audit log
    public static var totalTagEvents: Int { ChargeTagAudit.totalTagEvents }
    /// Recent event accessibility labels
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeTagAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
// Demo/business/tokenized preview for ChargeTagView
struct ChargeTagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ChargeTagView(text: "VIP", color: AppColors.accent)
            ChargeTagView(text: "Full Package", color: AppColors.blue)
            ChargeTagView(text: "Discount", color: AppColors.green)
            ChargeTagView(text: "First Visit", color: AppColors.orange)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

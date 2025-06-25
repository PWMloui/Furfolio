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

fileprivate final class ChargeTagAudit {
    static private(set) var log: [ChargeTagAuditEvent] = []

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tag events recorded."
    }
}

// MARK: - ChargeTagView

/// A reusable, modular, tokenized, and auditable view for displaying charge category tags.
/// This view supports business analytics, accessibility, localization, and integration with the UI design system.
struct ChargeTagView: View {
    let text: String
    var color: Color = AppColors.accent // Use tokenized accent color for consistency

    var body: some View {
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
                ChargeTagAudit.record(
                    text: text,
                    color: color,
                    tags: ["charge", "tag", text]
                )
            }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeTagAuditAdmin {
    public static var lastSummary: String { ChargeTagAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeTagAudit.exportLastJSON() }
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

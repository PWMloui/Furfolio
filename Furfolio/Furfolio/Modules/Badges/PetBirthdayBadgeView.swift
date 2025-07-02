//
//  PetBirthdayBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Birthday Badge View
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct PetBirthdayBadgeAuditEvent: Codable {
    let timestamp: Date
    let petName: String
    let ageNote: String?
    let tags: [String]
    let context: String
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] Birthday badge for \(petName)\(ageNote != nil ? ", \(ageNote!)" : "") [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class PetBirthdayBadgeAudit {
    static private(set) var log: [PetBirthdayBadgeAuditEvent] = []
    
    /// Records a birthday badge appearance event.
    /// - Parameters:
    ///   - petName: The name of the pet.
    ///   - ageNote: Optional age note associated with the badge.
    ///   - tags: Tags related to the badge event.
    ///   - context: Context string identifying the source.
    static func record(
        petName: String,
        ageNote: String?,
        tags: [String] = [],
        context: String = "PetBirthdayBadgeView"
    ) {
        let event = PetBirthdayBadgeAuditEvent(
            timestamp: Date(),
            petName: petName,
            ageNote: ageNote,
            tags: tags,
            context: context
        )
        log.append(event)
        if log.count > 80 { log.removeFirst() }
    }
    
    /// Exports the last logged event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Accessibility summary string for the last event or a default message.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No birthday badge events recorded."
    }
    
    /// CSV export of all logged events.
    /// Format: timestamp,petName,ageNote,tags,context
    static func exportCSV() -> String {
        let header = "timestamp,petName,ageNote,tags,context"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let petNameEscaped = event.petName.replacingOccurrences(of: "\"", with: "\"\"")
            let ageNoteEscaped = (event.ageNote ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let tagsEscaped = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let contextEscaped = event.context.replacingOccurrences(of: "\"", with: "\"\"")
            // Wrap fields with commas or special chars in quotes
            func quoteIfNeeded(_ str: String) -> String {
                if str.contains(",") || str.contains("\"") || str.contains("\n") {
                    return "\"\(str)\""
                } else {
                    return str
                }
            }
            return [
                quoteIfNeeded(timestampStr),
                quoteIfNeeded(petNameEscaped),
                quoteIfNeeded(ageNoteEscaped),
                quoteIfNeeded(tagsEscaped),
                quoteIfNeeded(contextEscaped)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// The ageNote string that appears most frequently in the log, if any.
    static var mostFrequentAgeNote: String? {
        let notes = log.compactMap { $0.ageNote }
        guard !notes.isEmpty else { return nil }
        let counts = Dictionary(grouping: notes, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total count of all badge appearance events recorded.
    static var totalBadgeShows: Int {
        log.count
    }
}

// MARK: - PetBirthdayBadgeView (Tokenized, Modular, Auditable Birthday Badge View)

/// Displays a 🎂 birthday badge for a pet.
/// This view should only be shown if the BadgeEngine has awarded a .birthday badge.
struct PetBirthdayBadgeView: View {
    let petName: String
    let badge: Badge // Expects a pre-calculated badge object
    
    var body: some View {
        if badge.type == .birthday {
            HStack(spacing: 8) {
                Text(badge.type.icon) // "🎂"
                    .font(.system(size: 22))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Happy Birthday, \(petName)!")
                        .font(AppFonts.captionBold)
                        .foregroundColor(AppColors.textPrimary)
                    if let notes = badge.notes {
                        Text(notes)
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .padding(8)
            .background(AppColors.loyalty.opacity(0.15))
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    .stroke(AppColors.loyalty, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Happy Birthday, \(petName). \(badge.notes ?? "")")
            .onAppear {
                // Record the badge appearance event for auditing.
                PetBirthdayBadgeAudit.record(
                    petName: petName,
                    ageNote: badge.notes,
                    tags: ["birthday", "badge"]
                )
                // Post VoiceOver announcement for accessibility.
                UIAccessibility.post(notification: .announcement, argument: "Birthday badge for \(petName) displayed.")
            }
            #if DEBUG
            // DEV overlay showing last 3 events and most frequent ageNote.
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("DEV Audit Summary:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    ForEach(PetBirthdayBadgeAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    if let frequent = PetBirthdayBadgeAudit.mostFrequentAgeNote {
                        Text("Most Frequent AgeNote: \(frequent)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else {
                        Text("Most Frequent AgeNote: None")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.6))
                .cornerRadius(6)
                .padding([.top], 48),
                alignment: .bottom
            )
            #endif
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum PetBirthdayBadgeAuditAdmin {
    public static var lastSummary: String { PetBirthdayBadgeAudit.accessibilitySummary }
    public static var lastJSON: String? { PetBirthdayBadgeAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        PetBirthdayBadgeAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// CSV export of all logged badge appearance events.
    public static var exportCSV: String { PetBirthdayBadgeAudit.exportCSV() }
    /// The ageNote string that appears most frequently in the log, if any.
    public static var mostFrequentAgeNote: String? { PetBirthdayBadgeAudit.mostFrequentAgeNote }
    /// Total count of all badge appearance events recorded.
    public static var totalBadgeShows: Int { PetBirthdayBadgeAudit.totalBadgeShows }
}

// MARK: - Demo/Business/Tokenized Preview

#Preview {
    VStack(spacing: 16) {
        PetBirthdayBadgeView(petName: "Buddy", badge: Badge(type: .birthday, notes: "5 years old"))
        PetBirthdayBadgeView(petName: "Luna", badge: Badge(type: .birthday, notes: "2 months old"))
        PetBirthdayBadgeView(petName: "Shadow", badge: Badge(type: .birthday, notes: nil))
    }
    .padding()
    .background(AppColors.background)
}

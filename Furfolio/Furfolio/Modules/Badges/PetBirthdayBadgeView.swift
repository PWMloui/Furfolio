//
//  PetBirthdayBadgeView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Birthday Badge View
//

import SwiftUI

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No birthday badge events recorded."
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
                PetBirthdayBadgeAudit.record(
                    petName: petName,
                    ageNote: badge.notes,
                    tags: ["birthday", "badge"]
                )
            }
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

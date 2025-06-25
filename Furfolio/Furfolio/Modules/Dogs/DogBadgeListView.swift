//
//  DogBadgeListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Badge List
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DogBadgeAuditEvent: Codable {
    let timestamp: Date
    let badgeCount: Int
    let badges: [String]
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Badges] \(badgeCount) badges: \(badges.joined(separator: ", ")) at \(dateStr)"
    }
}
fileprivate final class DogBadgeAudit {
    static private(set) var log: [DogBadgeAuditEvent] = []
    static func record(badges: [String]) {
        let event = DogBadgeAuditEvent(
            timestamp: Date(),
            badgeCount: badges.count,
            badges: badges
        )
        log.append(event)
        if log.count > 25 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - DogBadgeListView

struct DogBadgeListView: View {
    let badges: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                        )
                        .foregroundColor(Color.accentColor)
                        .accessibilityLabel("Badge: \(badge)")
                        .accessibilityIdentifier("DogBadgeListView-Badge-\(badge)")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(badges.isEmpty ? "No badges" : "Dog badges: \(badges.joined(separator: ", "))")
        .accessibilityIdentifier("DogBadgeListView-Container")
        .onAppear {
            DogBadgeAudit.record(badges: badges)
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DogBadgeListViewAuditAdmin {
    public static func lastSummary() -> String { DogBadgeAudit.log.last?.summary ?? "No badge renders yet." }
    public static func lastJSON() -> String? { DogBadgeAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] { DogBadgeAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogBadgeListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DogBadgeListView(badges: ["Calm", "Friendly", "Needs Shampoo", "Allergic"])
                .previewLayout(.sizeThatFits)
            DogBadgeListView(badges: [])
                .previewLayout(.sizeThatFits)
            DogBadgeListView(badges: ["Reactive"])
                .previewLayout(.sizeThatFits)
        }
    }
}
#endif

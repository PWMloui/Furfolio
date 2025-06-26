//
//  OwnerRetentionTagView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Animated, Enterprise-Grade Retention Tag
//

import SwiftUI

/// A view that displays a retention status tag for a DogOwner.
/// It determines the appropriate tag by using the centralized CustomerRetentionAnalyzer.
struct OwnerRetentionTagView: View {
    let owner: DogOwner

    /// The single source of truth for retention logic.
    private let analyzer = CustomerRetentionAnalyzer.shared

    // Animate badge on status change
    @State private var animate: Bool = false
    @State private var lastStatus: String?

    var body: some View {
        let tag = analyzer.retentionTag(for: owner)

        Label {
            Text(tag.label)
                .font(AppFonts.caption)
                .accessibilityIdentifier("OwnerRetentionTagView-Label-\(tag.label)")
        } icon: {
            Image(systemName: tag.icon.symbol)
                .accessibilityIdentifier("OwnerRetentionTagView-Icon-\(tag.icon.symbol)")
        }
        .foregroundColor(tag.color)
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(tag.color.opacity(0.13))
        .clipShape(Capsule())
        .scaleEffect(animate ? 1.13 : 1.0)
        .shadow(color: tag.color.opacity(0.11), radius: animate ? 6 : 2)
        .animation(.spring(response: 0.36, dampingFraction: 0.52), value: animate)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Retention Status: \(tag.label)")
        .accessibilityIdentifier("OwnerRetentionTagView-Root-\(tag.label)")
        .onAppear {
            if lastStatus != tag.label {
                animate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation { animate = false }
                }
                OwnerRetentionTagAudit.record(ownerName: owner.ownerName, status: tag.label)
                lastStatus = tag.label
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerRetentionTagAuditEvent: Codable {
    let timestamp: Date
    let ownerName: String
    let status: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[OwnerRetentionTagView] \(ownerName): \(status) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerRetentionTagAudit {
    static private(set) var log: [OwnerRetentionTagAuditEvent] = []
    static func record(ownerName: String, status: String) {
        let event = OwnerRetentionTagAuditEvent(timestamp: Date(), ownerName: ownerName, status: status)
        log.append(event)
        if log.count > 36 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum OwnerRetentionTagAuditAdmin {
    public static func lastSummary() -> String { OwnerRetentionTagAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { OwnerRetentionTagAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
@available(iOS 18.0, *)
struct OwnerRetentionTagView_Previews: PreviewProvider {
    static var previews: some View {
        // Sample owners representing each retention status for the preview.
        let newOwner = DogOwner(ownerName: "New Owner")
        
        let activeOwner = DogOwner(ownerName: "Active Owner")
        activeOwner.appointments = [Appointment(date: Date().addingTimeInterval(-20 * 86400), serviceType: .fullGroom)]
        
        let returningOwner = DogOwner(ownerName: "Returning Owner")
        returningOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom),
            Appointment(date: Date().addingTimeInterval(-45 * 86400), serviceType: .fullGroom)
        ]
        
        let riskOwner = DogOwner(ownerName: "Risk Owner")
        riskOwner.appointments = [Appointment(date: Date().addingTimeInterval(-75 * 86400), serviceType: .nailTrim)]
        
        let inactiveOwner = DogOwner(ownerName: "Inactive Owner")
        inactiveOwner.appointments = [Appointment(date: Date().addingTimeInterval(-200 * 86400), serviceType: .fullGroom)]
        
        return VStack(alignment: .leading, spacing: 18) {
            OwnerRetentionTagView(owner: newOwner)
            OwnerRetentionTagView(owner: activeOwner)
            OwnerRetentionTagView(owner: returningOwner)
            OwnerRetentionTagView(owner: riskOwner)
            OwnerRetentionTagView(owner: inactiveOwner)
        }
        .padding()
        .background(AppColors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif

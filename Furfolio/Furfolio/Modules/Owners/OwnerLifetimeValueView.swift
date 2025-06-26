//
//  OwnerLifetimeValueView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Lifetime Value
//

import SwiftUI

struct OwnerLifetimeValueView: View {
    let ownerName: String
    let totalSpent: Double
    let appointmentCount: Int
    let lastVisit: Date?
    let isTopSpender: Bool

    @State private var animateBadge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ownerName)
                        .font(.title2.bold())
                        .accessibilityIdentifier("OwnerLifetimeValueView-OwnerName")
                    if isTopSpender {
                        Label("Top Spender", systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.21), Color.orange.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .yellow.opacity(0.15), radius: animateBadge ? 8 : 3)
                            .scaleEffect(animateBadge ? 1.1 : 1.0)
                            .accessibilityIdentifier("OwnerLifetimeValueView-TopSpenderBadge")
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.6)) { animateBadge = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    withAnimation(.easeOut(duration: 0.6)) { animateBadge = false }
                                }
                            }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(totalSpent, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.title.bold())
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("OwnerLifetimeValueView-TotalSpent")
                    Text("Lifetime Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("OwnerLifetimeValueView-LifetimeValueLabel")
                }
            }
            HStack(spacing: 20) {
                VStack {
                    Text("\(appointmentCount)")
                        .font(.title2.bold())
                        .accessibilityIdentifier("OwnerLifetimeValueView-AppointmentCount")
                    Text("Visits")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("OwnerLifetimeValueView-VisitsLabel")
                }
                Divider()
                    .frame(height: 34)
                VStack {
                    if let last = lastVisit {
                        Text(last, style: .date)
                            .font(.title3.bold())
                            .accessibilityIdentifier("OwnerLifetimeValueView-LastVisitDate")
                        Text("Last Visit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("OwnerLifetimeValueView-LastVisitLabel")
                    } else {
                        Text("—")
                            .font(.title3.bold())
                            .accessibilityIdentifier("OwnerLifetimeValueView-NoLastVisit")
                        Text("Last Visit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("OwnerLifetimeValueView-LastVisitLabel")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Color(.secondarySystemGroupedBackground)
                    .opacity(isTopSpender ? 0.96 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 13))
        }
        .padding()
        .background(
            Group {
                if isTopSpender {
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.07),
                            Color(.systemGroupedBackground)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                } else {
                    Color(.systemGroupedBackground)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(ownerName), total spent \(Int(totalSpent)), \(appointmentCount) visits")
        .accessibilityIdentifier("OwnerLifetimeValueView-Root")
        .onAppear {
            OwnerLifetimeValueAudit.record(action: "Appear", ownerName: ownerName, isTopSpender: isTopSpender, totalSpent: totalSpent, appointmentCount: appointmentCount)
        }
    }
}

// --- Audit/Event Logging ---

fileprivate struct OwnerLifetimeValueAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let ownerName: String
    let isTopSpender: Bool
    let totalSpent: Double
    let appointmentCount: Int
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[OwnerLifetimeValueView] \(action): \(ownerName), \(isTopSpender ? "Top Spender" : ""), $\(Int(totalSpent)), \(appointmentCount) visits at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerLifetimeValueAudit {
    static private(set) var log: [OwnerLifetimeValueAuditEvent] = []
    static func record(action: String, ownerName: String, isTopSpender: Bool, totalSpent: Double, appointmentCount: Int) {
        let event = OwnerLifetimeValueAuditEvent(
            timestamp: Date(), action: action, ownerName: ownerName,
            isTopSpender: isTopSpender, totalSpent: totalSpent, appointmentCount: appointmentCount
        )
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum OwnerLifetimeValueAuditAdmin {
    public static func lastSummary() -> String { OwnerLifetimeValueAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { OwnerLifetimeValueAudit.recentSummaries(limit: limit) }
}

#Preview {
    OwnerLifetimeValueView(
        ownerName: "Jane Doe",
        totalSpent: 1525.50,
        appointmentCount: 16,
        lastVisit: Date().addingTimeInterval(-86400 * 14),
        isTopSpender: true
    )
}

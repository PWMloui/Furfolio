//
//  DogOwnerRowView.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise, Accessible, Auditable, Visually Polished
//

import SwiftUI

struct DogOwnerRowView: View {
    let ownerName: String
    let phoneNumber: String?
    let email: String?
    let address: String?
    let dogCount: Int
    let upcomingAppointmentDate: Date?

    @State private var animateDogBadge: Bool = false

    static func auditView(ownerName: String, dogCount: Int) {
        DogOwnerRowAudit.record(action: "Render", ownerName: ownerName, dogCount: dogCount)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("DogOwnerRowView-Icon")
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ownerName)
                        .font(.headline)
                        .lineLimit(1)
                        .accessibilityIdentifier("DogOwnerRowView-OwnerName")

                    if dogCount == 0 {
                        BadgeLabel(text: "No Dogs", color: .gray)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityIdentifier("DogOwnerRowView-NoDog")
                    } else if dogCount == 1 {
                        BadgeLabel(text: "Dog", color: .accentColor)
                            .transition(.scale.combined(with: .opacity))
                            .accessibilityIdentifier("DogOwnerRowView-OneDog")
                    } else {
                        BadgeLabel(text: "\(dogCount) Dogs", color: .accentColor)
                            .scaleEffect(animateDogBadge ? 1.12 : 1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: dogCount)
                            .onAppear {
                                withAnimation {
                                    animateDogBadge.toggle()
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                                    withAnimation {
                                        animateDogBadge = false
                                    }
                                }
                            }
                            .accessibilityIdentifier("DogOwnerRowView-DogCount")
                    }
                }

                if let nextDate = upcomingAppointmentDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(nextDate, style: .date)
                            .font(.caption)
                        Text(nextDate, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Next appointment: \(nextDate.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityIdentifier("DogOwnerRowView-Appointment")
                }
                if let phone = phoneNumber, !phone.isEmpty {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("DogOwnerRowView-Phone")
                }
                if let email = email, !email.isEmpty {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("DogOwnerRowView-Email")
                }
                if let addr = address, !addr.isEmpty {
                    Label(addr, systemImage: "map.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier("DogOwnerRowView-Address")
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
                .accessibilityIdentifier("DogOwnerRowView-Chevron")
        }
        .padding(.vertical, 8)
        .background(
            Color.clear
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(ownerName), \(dogCount) dog\(dogCount == 1 ? "" : "s")")
        .accessibilityIdentifier("DogOwnerRowView-Cell")
        .onAppear {
            Self.auditView(ownerName: ownerName, dogCount: dogCount)
        }
    }
}

// MARK: - Reusable BadgeLabel

struct BadgeLabel: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundColor(color)
            .clipShape(Capsule())
            .accessibilityLabel(text)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogOwnerRowAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let ownerName: String
    let dogCount: Int
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[DogOwnerRow] \(action): \(ownerName), \(dogCount) dog(s) at \(df.string(from: timestamp))"
    }
}
fileprivate final class DogOwnerRowAudit {
    static private(set) var log: [DogOwnerRowAuditEvent] = []
    static func record(action: String, ownerName: String, dogCount: Int) {
        let event = DogOwnerRowAuditEvent(timestamp: Date(), action: action, ownerName: ownerName, dogCount: dogCount)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum DogOwnerRowAuditAdmin {
    public static func lastSummary() -> String { DogOwnerRowAudit.log.last?.summary ?? "No events yet." }
    public static func lastJSON() -> String? { DogOwnerRowAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { DogOwnerRowAudit.recentSummaries(limit: limit) }
}

#Preview {
    DogOwnerRowView(
        ownerName: "Jane Doe",
        phoneNumber: "555-987-6543",
        email: "jane@example.com",
        address: "321 Bark Ave",
        dogCount: 2,
        upcomingAppointmentDate: Date().addingTimeInterval(86400 * 2)
    )
}

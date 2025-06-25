//
//  DogProfileView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Profile View
//

import SwiftUI

// MARK: - DogProfileView
struct DogProfileView: View {
    struct Dog {
        var name: String
        var breed: String
        var birthdate: Date
        var badges: [String]
        var behaviorNotes: String
        var totalVisits: Int
        var lastVisitDate: Date
        var vaccinationsUpToDate: Bool
        var allergies: [String]
        var photo: Image?
    }

    let dog: Dog

    // Optional handlers for edit and log actions (for future navigation, analytics, etc.)
    var onEdit: (() -> Void)? = nil
    var onAddBehaviorLog: (() -> Void)? = nil

    // MARK: - Audit/Event Logging
    private func auditProfileViewed() {
        DogProfileAudit.record(action: "ViewProfile", details: dog.name)
    }

    // MARK: - Helpers
    var ageDescription: String {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month], from: dog.birthdate, to: Date())
        let years = ageComponents.year ?? 0
        let months = ageComponents.month ?? 0
        if years > 0 {
            return "\(years) year\(years > 1 ? "s" : "")"
        } else if months > 0 {
            return "\(months) month\(months > 1 ? "s" : "")"
        } else {
            return "Less than a month"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // MARK: Photo and Basic Info
                ZStack(alignment: .bottomTrailing) {
                    HStack(alignment: .center, spacing: 16) {
                        if let photo = dog.photo {
                            photo
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(radius: 4)
                                .accessibilityLabel(Text("\(dog.name) photo"))
                                .accessibilityIdentifier("DogProfileView-Photo")
                        } else {
                            Image(systemName: "pawprint.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 120, height: 120)
                                .foregroundColor(.accentColor)
                                .accessibilityHidden(true)
                                .accessibilityIdentifier("DogProfileView-DefaultPhoto")
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(dog.name)
                                .font(.largeTitle.bold())
                                .accessibilityLabel(Text("Dog name: \(dog.name)"))
                                .accessibilityIdentifier("DogProfileView-Name")
                            Text(dog.breed)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .accessibilityLabel(Text("Breed: \(dog.breed)"))
                                .accessibilityIdentifier("DogProfileView-Breed")
                            Text("Age: \(ageDescription)")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .accessibilityLabel(Text("Age: \(ageDescription)"))
                                .accessibilityIdentifier("DogProfileView-Age")
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                // MARK: Badges/Tags
                SectionCard(title: "Badges") {
                    DogBadgeListView(badges: dog.badges)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("DogProfileView-BadgeList")
                }

                // MARK: Behavior Notes
                SectionCard(title: "Behavior Notes") {
                    Text(dog.behaviorNotes.isEmpty ? "No behavior notes." : dog.behaviorNotes)
                        .foregroundColor(dog.behaviorNotes.isEmpty ? .secondary : .primary)
                        .accessibilityLabel(dog.behaviorNotes.isEmpty ? "No behavior notes" : dog.behaviorNotes)
                        .accessibilityIdentifier("DogProfileView-BehaviorNotes")
                }

                // MARK: Grooming History Summary
                SectionCard(title: "Grooming History") {
                    HStack {
                        Text("Total Visits:")
                            .font(.headline)
                        Spacer()
                        Text("\(dog.totalVisits)")
                            .accessibilityLabel(Text("Total grooming visits: \(dog.totalVisits)"))
                            .accessibilityIdentifier("DogProfileView-TotalVisits")
                    }
                    HStack {
                        Text("Last Visit:")
                            .font(.headline)
                        Spacer()
                        Text(dog.lastVisitDate, style: .date)
                            .accessibilityLabel(Text("Last grooming visit: \(dog.lastVisitDate.formatted(date: .abbreviated, time: .omitted))"))
                            .accessibilityIdentifier("DogProfileView-LastVisit")
                    }
                }

                // MARK: Health Records Summary
                SectionCard(title: "Health Records") {
                    HStack {
                        Text("Vaccinations Up to Date:")
                            .font(.headline)
                        Spacer()
                        Image(systemName: dog.vaccinationsUpToDate ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundColor(dog.vaccinationsUpToDate ? .green : .red)
                            .accessibilityLabel(Text(dog.vaccinationsUpToDate ? "Vaccinations up to date" : "Vaccinations overdue"))
                            .accessibilityIdentifier("DogProfileView-Vaccinations")
                    }
                    if dog.allergies.isEmpty {
                        Text("No known allergies.")
                            .foregroundColor(.secondary)
                            .accessibilityLabel(Text("No known allergies"))
                            .accessibilityIdentifier("DogProfileView-NoAllergies")
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allergies:")
                                .font(.headline)
                            ForEach(dog.allergies, id: \.self) { allergy in
                                Text("• \(allergy)")
                                    .accessibilityLabel(Text("Allergy: \(allergy)"))
                                    .accessibilityIdentifier("DogProfileView-Allergy-\(allergy)")
                            }
                        }
                    }
                }

                // MARK: Action Buttons
                HStack(spacing: 24) {
                    Button {
                        onEdit?()
                        DogProfileAudit.record(action: "TapEdit", details: dog.name)
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text("Edit profile"))
                    .accessibilityIdentifier("DogProfileView-EditButton")

                    Button {
                        onAddBehaviorLog?()
                        DogProfileAudit.record(action: "TapAddBehaviorLog", details: dog.name)
                    } label: {
                        Label("Add Behavior Log", systemImage: "plus.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Add new behavior log"))
                    .accessibilityIdentifier("DogProfileView-AddBehaviorLogButton")
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { auditProfileViewed() }
    }
}

// MARK: - Section Card for Visual Polish
struct SectionCard<Content: View>: View {
    let title: String
    let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(radius: 1.5)
        )
        .padding(.horizontal)
    }
}

// MARK: - Badge List View
struct DogBadgeListView: View {
    let badges: [String]
    var body: some View {
        if badges.isEmpty {
            Text("No badges")
                .foregroundColor(.secondary)
                .accessibilityIdentifier("DogBadgeListView-Empty")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.2))
                            )
                            .foregroundColor(Color.accentColor)
                            .accessibilityLabel("Badge: \(badge)")
                            .accessibilityIdentifier("DogBadgeListView-Badge-\(badge)")
                    }
                }
            }
            .accessibilityIdentifier("DogBadgeListView-Scroll")
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogProfileAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[DogProfile] \(action): \(details) at \(dateStr)"
    }
}
fileprivate final class DogProfileAudit {
    static private(set) var log: [DogProfileAuditEvent] = []
    static func record(action: String, details: String) {
        let event = DogProfileAuditEvent(
            timestamp: Date(),
            action: action,
            details: details
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Audit/Admin Accessors

public enum DogProfileAuditAdmin {
    public static func lastSummary() -> String { DogProfileAudit.log.last?.summary ?? "No profile events yet." }
    public static func lastJSON() -> String? { DogProfileAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { DogProfileAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DogProfileView(
                dog: DogProfileView.Dog(
                    name: "Bella",
                    breed: "Golden Retriever",
                    birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
                    badges: ["Calm", "Friendly", "Needs Shampoo"],
                    behaviorNotes: "Generally calm but can get anxious around strangers.",
                    totalVisits: 8,
                    lastVisitDate: Calendar.current.date(byAdding: .day, value: -14, to: Date())!,
                    vaccinationsUpToDate: true,
                    allergies: ["Pollen"],
                    photo: Image(systemName: "pawprint.fill")
                ),
                onEdit: { print("Edit tapped") },
                onAddBehaviorLog: { print("Add behavior log tapped") }
            )
        }
        .environment(\.sizeCategory, .medium)
        .previewDisplayName("Dog Profile")
    }
}
#endif

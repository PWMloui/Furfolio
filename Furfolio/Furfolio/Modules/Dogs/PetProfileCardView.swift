//
//  PetProfileCardView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Pet Profile Card
//

import SwiftUI

struct PetProfileCardView: View {
    struct Pet {
        var name: String
        var breed: String
        var birthdate: Date
        var notes: String
        var badges: [String]
        var photo: Image?
    }

    let pet: Pet
    var onTap: (() -> Void)? = nil // Extensible: For navigation, analytics, or actions

    private var ageDescription: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: pet.birthdate, to: Date())
        if let years = components.year, years > 0 {
            return "\(years) year\(years > 1 ? "s" : "")"
        }
        if let months = components.month, months > 0 {
            return "\(months) month\(months > 1 ? "s" : "")"
        }
        return "Less than a month"
    }

    var body: some View {
        Button(action: {
            onTap?()
            PetProfileCardAudit.record(petName: pet.name)
        }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    if let photo = pet.photo {
                        photo
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 3)
                            .accessibilityLabel("\(pet.name) photo")
                            .accessibilityIdentifier("PetProfileCardView-Photo")
                    } else {
                        Image(systemName: "pawprint.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("PetProfileCardView-DefaultPhoto")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(pet.name)
                            .font(.title2.bold())
                            .accessibilityLabel("Pet name: \(pet.name)")
                            .accessibilityIdentifier("PetProfileCardView-Name")
                        Text(pet.breed)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Breed: \(pet.breed)")
                            .accessibilityIdentifier("PetProfileCardView-Breed")
                        Text("Age: \(ageDescription)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Age: \(ageDescription)")
                            .accessibilityIdentifier("PetProfileCardView-Age")
                    }
                    Spacer()
                }

                if !pet.badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(pet.badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.22))
                                            .shadow(radius: 1)
                                    )
                                    .foregroundColor(Color.accentColor)
                                    .accessibilityLabel("Badge: \(badge)")
                                    .accessibilityIdentifier("PetProfileCardView-Badge-\(badge)")
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.spring(), value: pet.badges)
                            }
                        }
                        .accessibilityIdentifier("PetProfileCardView-BadgeList")
                    }
                }

                if !pet.notes.isEmpty {
                    Text(pet.notes)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .accessibilityLabel("Notes: \(pet.notes)")
                        .accessibilityIdentifier("PetProfileCardView-Notes")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.11), radius: 7, x: 0, y: 3)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("PetProfileCardView-Container")
        }
        .buttonStyle(.plain)
        .onAppear {
            PetProfileCardAudit.record(petName: pet.name)
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct PetProfileCardAuditEvent: Codable {
    let timestamp: Date
    let petName: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[PetProfileCard] \(petName) card shown at \(dateStr)"
    }
}
fileprivate final class PetProfileCardAudit {
    static private(set) var log: [PetProfileCardAuditEvent] = []
    static func record(petName: String) {
        let event = PetProfileCardAuditEvent(timestamp: Date(), petName: petName)
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

// MARK: - Admin/Audit Accessors

public enum PetProfileCardAuditAdmin {
    public static func lastSummary() -> String { PetProfileCardAudit.log.last?.summary ?? "No card events yet." }
    public static func lastJSON() -> String? { PetProfileCardAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { PetProfileCardAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct PetProfileCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PetProfileCardView(pet: PetProfileCardView.Pet(
                name: "Bella",
                breed: "Golden Retriever",
                birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
                notes: "Calm and friendly. Prefers short grooming sessions.",
                badges: ["Calm", "Friendly", "Needs Shampoo"],
                photo: Image(systemName: "pawprint.fill")
            ))
            .previewLayout(.sizeThatFits)
            .padding()

            PetProfileCardView(pet: PetProfileCardView.Pet(
                name: "Coco",
                breed: "Poodle",
                birthdate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!,
                notes: "",
                badges: [],
                photo: nil
            ))
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }
}
#endif

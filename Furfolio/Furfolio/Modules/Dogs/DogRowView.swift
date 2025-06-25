//
//  DogRowView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Dog Row View
//

import SwiftUI

struct DogRowView: View {
    struct Dog {
        var name: String
        var breed: String
        var birthdate: Date
        var photo: Image?
    }

    let dog: Dog
    var onSelect: (() -> Void)? = nil

    // MARK: - Age Description
    var ageDescription: String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: dog.birthdate, to: Date())
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
            onSelect?()
            DogRowAudit.record(action: "Select", dogName: dog.name)
        }) {
            HStack(spacing: 16) {
                if let photo = dog.photo {
                    photo
                        .resizable()
                        .scaledToFill()
                        .frame(width: 66, height: 66)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(radius: 1)
                        .accessibilityLabel("\(dog.name) photo")
                        .accessibilityIdentifier("DogRowView-Photo")
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 66, height: 66)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                        .accessibilityIdentifier("DogRowView-DefaultPhoto")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dog.name)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.primary)
                        .accessibilityLabel("Dog name: \(dog.name)")
                        .accessibilityIdentifier("DogRowView-Name")
                    Text(dog.breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Breed: \(dog.breed)")
                        .accessibilityIdentifier("DogRowView-Breed")
                    Text("Age: \(ageDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Age: \(ageDescription)")
                        .accessibilityIdentifier("DogRowView-Age")
                }

                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .opacity(0.82)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dog.name), \(dog.breed), \(ageDescription)")
        .accessibilityIdentifier("DogRowView-Container")
        .onAppear {
            DogRowAudit.record(action: "Appear", dogName: dog.name)
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogRowAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let dogName: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[DogRow] \(action): \(dogName) at \(dateStr)"
    }
}
fileprivate final class DogRowAudit {
    static private(set) var log: [DogRowAuditEvent] = []
    static func record(action: String, dogName: String) {
        let event = DogRowAuditEvent(timestamp: Date(), action: action, dogName: dogName)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
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

public enum DogRowAuditAdmin {
    public static func lastSummary() -> String { DogRowAudit.log.last?.summary ?? "No row events yet." }
    public static func lastJSON() -> String? { DogRowAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { DogRowAudit.recentSummaries(limit: limit) }
}

// MARK: - Preview

#if DEBUG
struct DogRowView_Previews: PreviewProvider {
    static var previews: some View {
        DogRowView(
            dog: DogRowView.Dog(
                name: "Bella",
                breed: "Golden Retriever",
                birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
                photo: Image(systemName: "pawprint.fill")
            ),
            onSelect: { print("Row selected!") }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

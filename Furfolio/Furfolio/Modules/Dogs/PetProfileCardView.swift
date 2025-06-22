//
//  PetProfileCardView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  PetProfileCardView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                if let photo = pet.photo {
                    photo
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("\(pet.name) photo")
                } else {
                    Image(systemName: "pawprint.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(pet.name)
                        .font(.title2.bold())
                        .accessibilityLabel("Pet name: \(pet.name)")
                    Text(pet.breed)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Breed: \(pet.breed)")
                    Text("Age: \(ageDescription)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Age: \(ageDescription)")
                }
            }

            if !pet.badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pet.badges, id: \.self) { badge in
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
                        }
                    }
                }
            }

            if !pet.notes.isEmpty {
                Text(pet.notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .accessibilityLabel("Notes: \(pet.notes)")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }
}

#if DEBUG
struct PetProfileCardView_Previews: PreviewProvider {
    static var previews: some View {
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
    }
}
#endif

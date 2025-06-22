//
//  DogProfileView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  DogProfileView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - DogProfileView
struct DogProfileView: View {
    // MARK: - Sample Dog model for demonstration
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
            VStack(alignment: .leading, spacing: 24) {
                // MARK: Photo and Basic Info
                HStack(alignment: .center, spacing: 16) {
                    if let photo = dog.photo {
                        photo
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .accessibilityLabel(Text("\(dog.name) photo"))
                    } else {
                        Image(systemName: "pawprint.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.accentColor)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dog.name)
                            .font(.largeTitle.bold())
                            .accessibilityLabel(Text("Dog name: \(dog.name)"))
                        Text(dog.breed)
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .accessibilityLabel(Text("Breed: \(dog.breed)"))
                        Text("Age: \(ageDescription)")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .accessibilityLabel(Text("Age: \(ageDescription)"))
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // MARK: Badges/Tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Badges")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    DogBadgeListView(badges: dog.badges)
                        .padding(.horizontal)
                        .accessibilityElement(children: .contain)
                }

                // MARK: Behavior Summary and Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("Behavior Notes")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    Text(dog.behaviorNotes.isEmpty ? "No behavior notes." : dog.behaviorNotes)
                        .padding(.horizontal)
                        .foregroundColor(dog.behaviorNotes.isEmpty ? .secondary : .primary)
                        .accessibilityLabel(dog.behaviorNotes.isEmpty ? "No behavior notes" : dog.behaviorNotes)
                }

                // MARK: Grooming History Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grooming History")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    HStack {
                        Text("Total Visits:")
                            .font(.headline)
                        Spacer()
                        Text("\(dog.totalVisits)")
                            .accessibilityLabel(Text("Total grooming visits: \(dog.totalVisits)"))
                    }
                    .padding(.horizontal)
                    HStack {
                        Text("Last Visit:")
                            .font(.headline)
                        Spacer()
                        Text(dog.lastVisitDate, style: .date)
                            .accessibilityLabel(Text("Last grooming visit: \(dog.lastVisitDate.formatted(date: .abbreviated, time: .omitted))"))
                    }
                    .padding(.horizontal)
                }

                // MARK: Health Records Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health Records")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    HStack {
                        Text("Vaccinations Up to Date:")
                            .font(.headline)
                        Spacer()
                        Image(systemName: dog.vaccinationsUpToDate ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundColor(dog.vaccinationsUpToDate ? .green : .red)
                            .accessibilityLabel(Text(dog.vaccinationsUpToDate ? "Vaccinations up to date" : "Vaccinations overdue"))
                    }
                    .padding(.horizontal)
                    if dog.allergies.isEmpty {
                        Text("No known allergies.")
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .accessibilityLabel(Text("No known allergies"))
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allergies:")
                                .font(.headline)
                            ForEach(dog.allergies, id: \.self) { allergy in
                                Text("• \(allergy)")
                                    .accessibilityLabel(Text("Allergy: \(allergy)"))
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // MARK: Action Buttons
                HStack(spacing: 24) {
                    Button {
                        // Edit dog profile action
                    } label: {
                        Label("Edit Profile", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(Text("Edit profile"))

                    Button {
                        // Add behavior log action
                    } label: {
                        Label("Add Behavior Log", systemImage: "plus.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Add new behavior log"))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(dog.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Placeholder for DogBadgeListView
struct DogBadgeListView: View {
    let badges: [String]
    var body: some View {
        if badges.isEmpty {
            Text("No badges")
                .foregroundColor(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(badges, id: \.self) { badge in
                        Text(badge)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                            .accessibilityLabel(Text("Badge: \(badge)"))
                    }
                }
            }
        }
    }
}

#if DEBUG
struct DogProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DogProfileView(dog: DogProfileView.Dog(
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
            ))
        }
        .environment(\.sizeCategory, .medium)
        .previewDisplayName("Dog Profile")
    }
}
#endif

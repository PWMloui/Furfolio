//
//  DogRowView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
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
        HStack(spacing: 16) {
            if let photo = dog.photo {
                photo
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("\(dog.name) photo")
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(dog.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityLabel("Dog name: \(dog.name)")
                Text(dog.breed)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Breed: \(dog.breed)")
                Text("Age: \(ageDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Age: \(ageDescription)")
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct DogRowView_Previews: PreviewProvider {
    static var previews: some View {
        DogRowView(dog: DogRowView.Dog(
            name: "Bella",
            breed: "Golden Retriever",
            birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
            photo: Image(systemName: "pawprint.fill")
        ))
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

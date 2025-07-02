//
//  Pupdate.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//  Pupdate.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
//  This file defines the Pupdate model representing updates related to a dog.
//  It includes properties for identification, content, timestamps, and related images,
//  along with convenient computed properties and initializers for ease of use.
//

import Foundation
import SwiftUI
import SwiftData

/// A model representing a single pupdate related to a dog.
@Model
public struct Pupdate: Identifiable {
    /// Unique identifier for the pupdate.
    @Attribute(.unique) var id: UUID
    
    /// Identifier linking this pupdate to a specific dog.
    let dogID: UUID
    
    /// The date when the pupdate occurred.
    let date: Date
    
    /// A short title summarizing the pupdate.
    let title: String
    
    /// Detailed content describing the pupdate.
    let content: String
    
    /// Optional array of image URLs or strings representing images related to the pupdate.
    let imageURLs: [String]?
    
    /// The date when this pupdate was created.
    let createdAt: Date
    
    /// The date when this pupdate was last updated.
    let updatedAt: Date
    
    @Attribute(.transient)
    /// A formatted string representation of the pupdate's date.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    @Attribute(.transient)
    /// A summary snippet of the content, limited to 100 characters.
    var summarySnippet: String {
        let maxLength = 100
        if content.count > maxLength {
            let index = content.index(content.startIndex, offsetBy: maxLength)
            return String(content[..<index]) + "…"
        } else {
            return content
        }
    }
    
    /// Initializes a new Pupdate instance.
    /// - Parameters:
    ///   - id: Unique identifier for the pupdate. Defaults to a new UUID.
    ///   - dogID: Identifier linking this pupdate to a specific dog.
    ///   - date: The date when the pupdate occurred.
    ///   - title: A short title summarizing the pupdate.
    ///   - content: Detailed content describing the pupdate.
    ///   - imageURLs: Optional array of image URLs or strings representing images related to the pupdate.
    ///   - createdAt: The date when this pupdate was created. Defaults to current date.
    ///   - updatedAt: The date when this pupdate was last updated. Defaults to current date.
    init(
        id: UUID = UUID(),
        dogID: UUID,
        date: Date,
        title: String,
        content: String,
        imageURLs: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dogID = dogID
        self.date = date
        self.title = title
        self.content = content
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

#if DEBUG
import SwiftUI

struct Pupdate_Previews: PreviewProvider {
    static var previews: some View {
        let samplePupdate = Pupdate(
            dogID: UUID(),
            date: Date(),
            title: NSLocalizedString("First Day at the Park", comment: "Pupdate title"),
            content: NSLocalizedString("Today, my dog enjoyed running around the park and playing with other dogs. It was a joyful experience and we took some great photos!", comment: "Pupdate content"),
            imageURLs: [
                "https://example.com/image1.jpg",
                "https://example.com/image2.jpg"
            ]
        )
        
        VStack(alignment: .leading, spacing: 8) {
            Text(samplePupdate.title)
                .font(.headline)
            Text(samplePupdate.formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(samplePupdate.summarySnippet)
                .font(.body)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

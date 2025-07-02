//
//  GroomingAnnotation.swift
//  Furfolio

//
//  This file defines the GroomingAnnotation struct used to represent annotations related to dog grooming.
//  The struct conforms to Codable and Identifiable for ease of use in SwiftUI and data persistence.
//  It includes an embedded enum AnnotationType to categorize the annotation types with localized descriptions.
//

import Foundation
import SwiftUI
import SwiftData

/// Represents an annotation related to a dog's grooming session.
@Model
public struct GroomingAnnotation: Identifiable {
    /// Unique identifier for the annotation.
    @Attribute(.unique) var id: UUID
    /// Identifier for the dog associated with this annotation.
    let dogID: UUID
    /// The date when the annotation was made.
    let date: Date
    /// The textual content of the annotation.
    let content: String
    /// The author of the annotation, e.g., the groomer's name.
    let author: String
    /// The type/category of the annotation.
    let type: AnnotationType
    
    /// Represents the type of grooming annotation.
    enum AnnotationType: String, Codable, CaseIterable {
        /// A general note.
        case note
        /// A warning related to grooming.
        case warning
        /// A health issue observed during grooming.
        case healthIssue
        
        /// Localized description for the annotation type.
        var localizedDescription: String {
            switch self {
            case .note:
                return NSLocalizedString("Note", comment: "Annotation type note")
            case .warning:
                return NSLocalizedString("Warning", comment: "Annotation type warning")
            case .healthIssue:
                return NSLocalizedString("Health Issue", comment: "Annotation type health issue")
            }
        }
    }
    
    /// Returns the annotation's date formatted as a user-friendly string.
    @Attribute(.transient)
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Returns the localized description of the annotation's type.
    @Attribute(.transient)
    var localizedTypeDescription: String {
        return type.localizedDescription
    }
}

#if DEBUG
import SwiftUI

struct GroomingAnnotation_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Text("Note")
                    .font(.headline)
                Text("Date: \(sampleNote.formattedDate)")
                Text("Author: \(sampleNote.author)")
                Text("Type: \(sampleNote.localizedTypeDescription)")
                Text("Content: \(sampleNote.content)")
            }
            .padding()
            .previewDisplayName("Note Annotation")
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Warning")
                    .font(.headline)
                Text("Date: \(sampleWarning.formattedDate)")
                Text("Author: \(sampleWarning.author)")
                Text("Type: \(sampleWarning.localizedTypeDescription)")
                Text("Content: \(sampleWarning.content)")
            }
            .padding()
            .previewDisplayName("Warning Annotation")
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Health Issue")
                    .font(.headline)
                Text("Date: \(sampleHealthIssue.formattedDate)")
                Text("Author: \(sampleHealthIssue.author)")
                Text("Type: \(sampleHealthIssue.localizedTypeDescription)")
                Text("Content: \(sampleHealthIssue.content)")
            }
            .padding()
            .previewDisplayName("Health Issue Annotation")
        }
        .previewLayout(.sizeThatFits)
    }
    
    static let sampleNote = GroomingAnnotation(
        id: UUID(),
        dogID: UUID(),
        date: Date(),
        content: "Dog was calm and cooperative throughout the grooming session.",
        author: "Jane Doe",
        type: .note
    )
    
    static let sampleWarning = GroomingAnnotation(
        id: UUID(),
        dogID: UUID(),
        date: Date().addingTimeInterval(-86400),
        content: "Dog showed signs of anxiety when using clippers near ears.",
        author: "John Smith",
        type: .warning
    )
    
    static let sampleHealthIssue = GroomingAnnotation(
        id: UUID(),
        dogID: UUID(),
        date: Date().addingTimeInterval(-172800),
        content: "Noticed redness and swelling near the left paw pads.",
        author: "Emily Clark",
        type: .healthIssue
    )
}
#endif

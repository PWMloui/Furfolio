//
//  DogTagManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Manages tags assigned to dogs within the Furfolio app.
final class DogTagManager {
    /// Dictionary mapping dog IDs to sets of tags
    private var dogTags: [UUID: Set<String>] = [:]

    /// Adds a tag to a specific dog.
    /// - Parameters:
    ///   - tag: The tag string to add.
    ///   - dogID: The unique identifier of the dog.
    func addTag(_ tag: String, to dogID: UUID) {
        var tags = dogTags[dogID] ?? Set<String>()
        tags.insert(tag)
        dogTags[dogID] = tags
    }

    /// Removes a tag from a specific dog.
    /// - Parameters:
    ///   - tag: The tag string to remove.
    ///   - dogID: The unique identifier of the dog.
    func removeTag(_ tag: String, from dogID: UUID) {
        guard var tags = dogTags[dogID] else { return }
        tags.remove(tag)
        dogTags[dogID] = tags.isEmpty ? nil : tags
    }

    /// Fetches all tags assigned to a specific dog.
    /// - Parameter dogID: The unique identifier of the dog.
    /// - Returns: A set of tags assigned to the dog.
    func tags(for dogID: UUID) -> Set<String> {
        return dogTags[dogID] ?? Set<String>()
    }

    /// Lists all unique tags across all dogs.
    /// - Returns: A set of all unique tags.
    func allTags() -> Set<String> {
        return dogTags.values.reduce(into: Set<String>()) { result, tags in
            result.formUnion(tags)
        }
    }
}

/*
 Usage Example:

 let manager = DogTagManager()
 let dogID = UUID()

 manager.addTag("Calm", to: dogID)
 manager.addTag("Needs Shampoo", to: dogID)

 print(manager.tags(for: dogID)) // ["Calm", "Needs Shampoo"]

 manager.removeTag("Calm", from: dogID)

 print(manager.allTags()) // ["Needs Shampoo"]
*/

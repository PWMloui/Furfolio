//
//  ExpenseCategory.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Represents a business expense category.
struct ExpenseCategory: Identifiable, Codable, Equatable {
    /// Unique identifier for the category.
    let id: UUID
    /// Name of the expense category.
    var name: String
    /// Optional description or notes for the category.
    var description: String?

    init(id: UUID = UUID(), name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }

    /// Some predefined common expense categories.
    static let supplies = ExpenseCategory(name: "Supplies")
    static let rent = ExpenseCategory(name: "Rent")
    static let utilities = ExpenseCategory(name: "Utilities")
    static let other = ExpenseCategory(name: "Other")

    /// Example list of common categories.
    static let all: [ExpenseCategory] = [
        .supplies,
        .rent,
        .utilities,
        .other
    ]
}

/*
 Usage Example:

 let category = ExpenseCategory(name: "Supplies")
 print(category.name) // "Supplies"
*/

//
//  ExpenseCategory.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Extensible Expense Category Model
//

import Foundation
import SwiftUI

/// Represents a business expense category.
struct ExpenseCategory: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for the category.
    let id: UUID
    /// Name of the expense category.
    var name: String
    /// Optional description or notes for the category.
    var description: String?
    /// Optional system icon name for use in UI.
    var icon: String?
    /// Optional color for use in UI (encoded as hex string, e.g. "#F9C12A").
    var colorHex: String?
    /// Is this a user-defined category?
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        icon: String? = nil,
        colorHex: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.colorHex = colorHex
        self.isCustom = isCustom
    }

    /// Predefined common expense categories.
    static let supplies = ExpenseCategory(name: "Supplies", icon: "cart.fill", colorHex: "#FFC14C")
    static let rent = ExpenseCategory(name: "Rent", icon: "house.fill", colorHex: "#94A3B8")
    static let utilities = ExpenseCategory(name: "Utilities", icon: "bolt.fill", colorHex: "#60A5FA")
    static let other = ExpenseCategory(name: "Other", icon: "questionmark.circle.fill", colorHex: "#A1A1AA")

    /// Example list of common categories.
    static let all: [ExpenseCategory] = [
        .supplies,
        .rent,
        .utilities,
        .other
    ]

    /// SwiftUI Color for UI
    var uiColor: Color {
        if let hex = colorHex, let color = Color(hex: hex) {
            return color
        }
        return .accentColor
    }
    
    /// Accessibility label for UI/test
    var accessibilityLabel: String { name }

    // MARK: - Audit/Event Logging (Admin/QA)
    static func auditUsage(_ category: ExpenseCategory, context: String = "") {
        ExpenseCategoryAudit.record(name: category.name, id: category.id, context: context)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct ExpenseCategoryAuditEvent: Codable {
    let timestamp: Date
    let name: String
    let id: UUID
    let context: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[ExpenseCategory] Used '\(name)' (\(id)) in \(context) at \(dateStr)"
    }
}
fileprivate final class ExpenseCategoryAudit {
    static private(set) var log: [ExpenseCategoryAuditEvent] = []
    static func record(name: String, id: UUID, context: String) {
        let event = ExpenseCategoryAuditEvent(timestamp: Date(), name: name, id: id, context: context)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - Admin/Audit Accessors

public enum ExpenseCategoryAuditAdmin {
    public static func lastSummary() -> String { ExpenseCategoryAudit.log.last?.summary ?? "No category events yet." }
    public static func lastJSON() -> String? { ExpenseCategoryAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 6) -> [String] { ExpenseCategoryAudit.recentSummaries(limit: limit) }
}

// MARK: - Color Helper

extension Color {
    /// Initialize Color from hex string, e.g. "#FFAA00"
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

/*
 Usage Example:

 let category = ExpenseCategory.supplies
 ExpenseCategory.auditUsage(category, context: "Expense Entry")
 print(category.name) // "Supplies"
 print(category.uiColor) // Color for UI
 */

//
//  DashboardMetric.swift
//  Furfolio
//


import Foundation
import SwiftUI

// MARK: - DashboardMetric (Enhanced Version)

struct DashboardMetric: Identifiable, Hashable, Equatable {
    // MARK: - Enums

    enum ValueType {
        case string, currency, number, percent, duration
    }

    enum Category: String, CaseIterable, Codable {
        case financial, appointment, retention, operations, inventory, staff, custom
    }

    // Use enums/tokens for icons and colors for better DS integration
    enum IconToken: String {
        case revenue = "dollarsign.circle.fill"
        case appointment = "calendar.badge.clock"
        case retention = "arrow.triangle.2.circlepath"
        // Add more tokens as needed
    }

    enum ColorToken {
        case accent, success, info, warning, error, custom(Color)
        var color: Color {
            switch self {
            case .accent: return AppColors.accent
            case .success: return AppColors.success
            case .info: return AppColors.info
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            case .custom(let color): return color
            }
        }
    }

    // MARK: - Core

    let id: UUID
    let title: LocalizedStringKey
    let value: String
    let valueType: ValueType
    let icon: IconToken
    let color: ColorToken
    let subtitle: LocalizedStringKey?
    let category: Category
    let lastUpdated: Date?
    var onTap: (() -> Void)?
    
    // MARK: - Permissions
    enum PermissionRole {
        case admin, staff, owner, any
    }
    var requiredRole: PermissionRole = .any
    var isSensitive: Bool = false

    // MARK: - Accessibility

    var accessibilityLabel: String?
    var accessibilityHint: String?
    var accessibilityValue: String?
    var accessibilityTraits: AccessibilityTraits = .isStaticText

    var isHighlighted: Bool = false

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        title: LocalizedStringKey,
        value: String,
        valueType: ValueType = .string,
        icon: IconToken,
        color: ColorToken = .accent,
        subtitle: LocalizedStringKey? = nil,
        category: Category = .custom,
        lastUpdated: Date? = nil,
        onTap: (() -> Void)? = nil,
        requiredRole: PermissionRole = .any,
        isSensitive: Bool = false,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityValue: String? = nil,
        accessibilityTraits: AccessibilityTraits = .isStaticText,
        isHighlighted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.valueType = valueType
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.category = category
        self.lastUpdated = lastUpdated
        self.onTap = onTap
        self.requiredRole = requiredRole
        self.isSensitive = isSensitive
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityValue = accessibilityValue
        self.accessibilityTraits = accessibilityTraits
        self.isHighlighted = isHighlighted
    }

    // MARK: - Equatable & Hashable

    static func == (lhs: DashboardMetric, rhs: DashboardMetric) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Static Examples

    static var sampleRevenue: DashboardMetric {
        DashboardMetric(
            title: "Total Revenue",
            value: "$2,750",
            valueType: .currency,
            icon: .revenue,
            color: .success,
            subtitle: "Month to date",
            category: .financial,
            lastUpdated: Date(),
            isHighlighted: true,
            accessibilityLabel: "Total revenue for the month"
        )
    }

    static var sampleAppointments: DashboardMetric {
        DashboardMetric(
            title: "Appointments",
            value: "14",
            valueType: .number,
            icon: .appointment,
            color: .accent,
            subtitle: "This week",
            category: .appointment,
            lastUpdated: Date(),
            accessibilityLabel: "Number of appointments this week"
        )
    }

    static var sampleRetention: DashboardMetric {
        DashboardMetric(
            title: "Retention Rate",
            value: "85%",
            valueType: .percent,
            icon: .retention,
            color: .info,
            subtitle: "Returning clients",
            category: .retention,
            lastUpdated: Date(),
            accessibilityLabel: "Client retention rate"
        )
    }

    static func customMetric(
        id: UUID = UUID(),
        title: LocalizedStringKey,
        value: String,
        valueType: ValueType,
        icon: IconToken,
        color: ColorToken,
        subtitle: LocalizedStringKey? = nil,
        category: Category = .custom,
        lastUpdated: Date? = nil
    ) -> DashboardMetric {
        DashboardMetric(
            id: id, title: title, value: value, valueType: valueType,
            icon: icon, color: color, subtitle: subtitle,
            category: category, lastUpdated: lastUpdated
        )
    }
}

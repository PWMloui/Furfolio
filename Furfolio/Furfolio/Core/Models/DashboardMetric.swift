//
//  DashboardMetric.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated, enhanced, and refactored for unified, scalable dashboard metrics.
//  Author: senpai + ChatGPT
//

import Foundation
import SwiftUI

// MARK: - DashboardMetric (Modular, Tokenized, Auditable Business Dashboard Metric)

/// Represents a single business metric displayed on the dashboard.
/// This struct is modular, tokenized, and auditable, designed for seamless integration with design system tokens (e.g., AppColors, AppFonts),
/// analytics tracking, business logic workflows, accessibility features, and event/audit tracking systems.
/// It is built to support scalable, owner-focused dashboards and compliance reporting across diverse business domains.
struct DashboardMetric: Identifiable, Hashable, Equatable {
    // MARK: - Identity & Core
    
    /// Unique identifier for audit tracking, analytics correlation, and UI identity.
    let id: UUID
    
    /// Localized title of the metric for display and accessibility.
    /// Supports dynamic localization and design system font tokens.
    let title: LocalizedStringKey
    
    /// String representation of the metric's value for display and analytics reporting.
    let value: String
    
    /// System or custom icon name representing the metric visually.
    /// Should map to design system iconography tokens where possible.
    let icon: String
    
    /// Color used for the metric's icon and emphasis in the UI.
    /// Intended to be sourced from design system color tokens for consistency.
    let color: Color
    
    /// Optional localized subtitle providing additional context or timeframe.
    /// Supports accessibility and enhanced user comprehension.
    let subtitle: LocalizedStringKey?
    
    // MARK: - User Interaction
    
    /// Optional action executed when the metric is tapped.
    /// Enables navigation, modal presentation, quick actions, or analytics event triggering.
    var onTap: (() -> Void)?
    
    // MARK: - Meta / Accessibility
    
    /// Accessibility label for VoiceOver and other assistive technologies.
    /// Enhances usability and compliance with accessibility standards.
    var accessibilityLabel: String?
    
    /// Flag indicating whether this metric should be visually highlighted.
    /// Useful for emphasizing key performance indicators (KPIs) in the UI and analytics.
    var isHighlighted: Bool = false
    
    /// Flag indicating if the metric contains sensitive data requiring permission checks.
    /// Supports compliance and secure display logic.
    var isSensitive: Bool = false

    // MARK: - Initializer
    
    /// Initializes a new DashboardMetric instance.
    ///
    /// Supports all audit, analytics, and design token integrations by allowing full customization of identity, display, interaction, and metadata.
    /// - Parameters:
    ///   - id: Unique identifier for audit and event correlation (default: new UUID).
    ///   - title: Localized title key for display and accessibility.
    ///   - value: String representation of the metric value.
    ///   - icon: Icon name representing the metric visually.
    ///   - color: Color for UI emphasis, ideally from design system tokens.
    ///   - subtitle: Optional localized subtitle for additional context.
    ///   - onTap: Optional tap action for user interaction and analytics event triggering.
    ///   - accessibilityLabel: Optional label for assistive technologies.
    ///   - isHighlighted: Flag for visual emphasis and KPI tracking.
    ///   - isSensitive: Flag indicating sensitive data requiring permission.
    init(
        id: UUID = UUID(),
        title: LocalizedStringKey,
        value: String,
        icon: String,
        color: Color = .accentColor,
        subtitle: LocalizedStringKey? = nil,
        onTap: (() -> Void)? = nil,
        accessibilityLabel: String? = nil,
        isHighlighted: Bool = false,
        isSensitive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.subtitle = subtitle
        self.onTap = onTap
        self.accessibilityLabel = accessibilityLabel
        self.isHighlighted = isHighlighted
        self.isSensitive = isSensitive
    }
    
    // MARK: - Equatable & Hashable
    
    /// Equatable conformance for analytics event correlation and UI deduplication.
    /// Ensures metrics are uniquely identified by their UUID for consistent tracking and rendering.
    static func == (lhs: DashboardMetric, rhs: DashboardMetric) -> Bool {
        lhs.id == rhs.id
    }
    
    /// Hashable conformance supporting use in sets, dictionaries, and UI diffing.
    /// Hashes based on unique identifier to maintain consistency across analytics and UI layers.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Demo / Preview / Factory
    
    /// Sample metric representing total revenue.
    /// Used for demo, analytics testing, and tokenized UI preview.
    /// Colors/icons use AppColors and modular tokens for consistency.
    /// Note: Use icon tokens/constants in production.
    static var sampleRevenue: DashboardMetric {
        DashboardMetric(
            title: "Total Revenue",
            value: "$2,750",
            icon: "dollarsign.circle.fill", // Replace with icon token in production
            color: AppColors.success,
            subtitle: "Month to date",
            isHighlighted: true,
            accessibilityLabel: "Total revenue for the month"
        )
    }
    
    /// Sample metric representing appointment count.
    /// Used for demo, analytics event simulation, and tokenized UI preview.
    /// Colors/icons use AppColors and modular tokens for consistency.
    /// Note: Use icon tokens/constants in production.
    static var sampleAppointments: DashboardMetric {
        DashboardMetric(
            title: "Appointments",
            value: "14",
            icon: "calendar.badge.clock", // Replace with icon token in production
            color: AppColors.accent,
            subtitle: "This week",
            accessibilityLabel: "Number of appointments this week"
        )
    }
    
    /// Sample metric representing client retention rate.
    /// Utilized for demo purposes, analytics validation, and design token previews.
    /// Colors/icons use AppColors and modular tokens for consistency.
    /// Note: Use icon tokens/constants in production.
    static var sampleRetention: DashboardMetric {
        DashboardMetric(
            title: "Retention Rate",
            value: "85%",
            icon: "arrow.triangle.2.circlepath", // Replace with icon token in production
            color: AppColors.info,
            subtitle: "Returning clients",
            accessibilityLabel: "Client retention rate"
        )
    }
    
    // Add more static examples as needed
}

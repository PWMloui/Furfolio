//
//  RetentionTag.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftUI

// MARK: - RetentionTag (Modular, Tokenized, Auditable Retention Status)

/// Represents a modular, auditable, and tokenized entity defining client retention state within Furfolio.
/// This enum supports analytics tracking, compliance auditing, dashboard and report UI rendering,
/// badge display logic, and localization for internationalization.
/// It encapsulates unified business logic and cross-feature utilities related to client retention status,
/// ensuring consistent use of design tokens for colors, fonts, spacing, and accessibility across the app.
enum RetentionTag: String, Codable, CaseIterable, Identifiable {
    case newClient
    case active
    case returning
    case retentionRisk
    case inactive

    var id: String { rawValue }

    /// Human-friendly display name, localized for future support.
    var label: String {
        switch self {
        case .newClient: return NSLocalizedString("New Client", comment: "RetentionTag label")
        case .active: return NSLocalizedString("Active", comment: "RetentionTag label")
        case .returning: return NSLocalizedString("Returning", comment: "RetentionTag label")
        case .retentionRisk: return NSLocalizedString("Retention Risk", comment: "RetentionTag label")
        case .inactive: return NSLocalizedString("Inactive", comment: "RetentionTag label")
        }
    }

    /// SF Symbol and emoji for the tag, allowing future custom branding.
    var icon: (symbol: String, emoji: String) {
        switch self {
        case .newClient: return (symbol: "sparkles", emoji: "✨")
        case .active: return (symbol: "bolt.fill", emoji: "⚡️")
        case .returning: return (symbol: "arrow.uturn.left", emoji: "↩️")
        case .retentionRisk: return (symbol: "exclamationmark.triangle.fill", emoji: "⚠️")
        case .inactive: return (symbol: "zzz", emoji: "💤")
        }
    }

    /// Color for UI badge, strictly using modular design tokens.
    /// This ensures consistent branding and theming across the app.
    /// TODO: Add fallback or error handling if token missing, never fallback to system color in production.
    var color: Color {
        switch self {
        case .newClient: return try! AppColors.blue
        case .active: return try! AppColors.green
        case .returning: return try! AppColors.purple
        case .retentionRisk: return try! AppColors.orange
        case .inactive: return try! AppColors.gray
        }
    }

    /// Sort order for dashboards and reports.
    var sortOrder: Int {
        switch self {
        case .newClient: return 0
        case .active: return 1
        case .returning: return 2
        case .retentionRisk: return 3
        case .inactive: return 4
        }
    }

    /// Indicates if the tag represents a risk state.
    var isRisk: Bool {
        return self == .retentionRisk || self == .inactive
    }

    /// Global default retention tag.
    static var `default`: RetentionTag { .active }
}

/// SwiftUI badge view displaying retention status with modular tokens for fonts, colors, spacing, border radius, and shadows.
/// This view supports accessibility and consistent theming using app-wide design tokens.
/// It is used across dashboards, client profiles, and reports to visually communicate retention state.
struct RetentionTagView: View {
    let tag: RetentionTag

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Image(systemName: tag.icon.symbol)
                .foregroundColor(tag.color)
            Text(tag.label)
                .font(AppFonts.caption)
                .foregroundColor(tag.color)
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.vertical, AppSpacing.small)
        .background(tag.color.opacity(0.13))
        .cornerRadius(BorderRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: BorderRadius.medium)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .shadow(color: AppShadows.light.color, radius: AppShadows.light.radius, x: AppShadows.light.x, y: AppShadows.light.y)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(tag.label))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppSpacing.medium) {
        ForEach(RetentionTag.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { tag in
            RetentionTagView(tag: tag)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Retention status: \(tag.label)"))
        }
    }
    .padding()
    .background(AppColors.background)
}

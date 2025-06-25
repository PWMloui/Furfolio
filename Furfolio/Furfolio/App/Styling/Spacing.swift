//
//  Spacing.swift
//  Furfolio
//
//  ENHANCED: token-compliant, analytics/audit–ready, brandable, preview/testable, robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol AppSpacingAnalyticsLogger {
    func log(event: String, value: CGFloat, token: String)
}
public struct NullAppSpacingAnalyticsLogger: AppSpacingAnalyticsLogger {
    public init() {}
    public func log(event: String, value: CGFloat, token: String) {}
}

// MARK: - AppSpacing (Centralized Spacing Tokens)

/// Central place for all standard spacing values in Furfolio.
/// Tokenized, analytics/audit–ready, brand/theme–extensible, and preview/test–injectable.
enum AppSpacing {
    // For BI/QA/Trust Center/preview
    static var analyticsLogger: AppSpacingAnalyticsLogger = NullAppSpacingAnalyticsLogger()

    // MARK: - Spacing Tokens (with robust fallback)
    static let none: CGFloat         = fetch("none", 0)
    static let xxs: CGFloat          = fetch("xxs", 2)
    static let xs: CGFloat           = fetch("xs", 4)
    static let small: CGFloat        = fetch("small", 8)
    static let medium: CGFloat       = fetch("medium", 16)
    static let large: CGFloat        = fetch("large", 24)
    static let xl: CGFloat           = fetch("xl", 32)
    static let xxl: CGFloat          = fetch("xxl", 40)
    static let section: CGFloat      = fetch("section", 48)
    static let listItem: CGFloat     = fetch("listItem", 12)  // e.g., vertical spacing in lists
    static let card: CGFloat         = fetch("card", 20)      // card padding

    // MARK: - Extendable tokens (future-proofed for components)
    static let avatar: CGFloat           = fetch("avatar", 42)
    static let pulseButtonScale: CGFloat = fetch("pulseButtonScale", 1.09)
    static let progressRingSize: CGFloat = fetch("progressRingSize", 86)
    static let progressRingStroke: CGFloat = fetch("progressRingStroke", 14)
    static let skeletonPrimary: CGFloat  = fetch("skeletonPrimary", 140)
    static let skeletonSecondaryMin: CGFloat = fetch("skeletonSecondaryMin", 90)
    static let skeletonSecondaryVar: CGFloat = fetch("skeletonSecondaryVar", 30)
    static let skeletonPrimaryHeight: CGFloat = fetch("skeletonPrimaryHeight", 15)
    static let skeletonSecondaryHeight: CGFloat = fetch("skeletonSecondaryHeight", 11)
    static let iconOffset: CGFloat       = fetch("iconOffset", 22)
    static let xsmall: CGFloat           = fetch("xsmall", 2) // Alias for very small spacing

    // MARK: - All values (for design system preview)
    static let all: [String: CGFloat] = [
        "none": none,
        "xxs": xxs,
        "xs": xs,
        "xsmall": xsmall,
        "small": small,
        "medium": medium,
        "large": large,
        "xl": xl,
        "xxl": xxl,
        "section": section,
        "listItem": listItem,
        "card": card,
        "avatar": avatar,
        "pulseButtonScale": pulseButtonScale,
        "progressRingSize": progressRingSize,
        "progressRingStroke": progressRingStroke,
        "skeletonPrimary": skeletonPrimary,
        "skeletonSecondaryMin": skeletonSecondaryMin,
        "skeletonSecondaryVar": skeletonSecondaryVar,
        "skeletonPrimaryHeight": skeletonPrimaryHeight,
        "skeletonSecondaryHeight": skeletonSecondaryHeight,
        "iconOffset": iconOffset
    ]

    /// Unified API for custom spacing (still logs and future–brand–ready).
    static func custom(_ value: CGFloat, label: String = "custom") -> CGFloat {
        analyticsLogger.log(event: "custom_spacing", value: value, token: label)
        return value
    }

    /// Robust, brand/theme–aware, logs usage.
    private static func fetch(_ token: String, _ fallback: CGFloat) -> CGFloat {
        analyticsLogger.log(event: "spacing_access", value: fallback, token: token)
        // Future: Lookup from brand/theme (e.g., AppTheme.Spacing[token])
        return fallback
    }
}

// MARK: - View Extension (Tokenized Padding)

extension View {
    /// Applies uniform padding using a named AppSpacing token (never a magic number).
    /// - Parameter spacing: Token from AppSpacing (default: .medium).
    /// - Returns: View with the specified padding.
    func appPadding(_ spacing: CGFloat = AppSpacing.medium) -> some View {
        self.padding(spacing)
    }
}

// MARK: - Preview (Design System/QA Review)

#if DEBUG
struct AppSpacingPreview: View {
    struct SpyLogger: AppSpacingAnalyticsLogger {
        func log(event: String, value: CGFloat, token: String) {
            print("[SpacingAnalytics] \(event) \(token): \(value)")
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(AppSpacing.all.keys.sorted()), id: \.self) { key in
                let value = AppSpacing.all[key] ?? 0
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.22))
                        .frame(width: value, height: 18)
                    Text("\(key): \(value, specifier: "%.1f")pt")
                        .font(.callout)
                        .foregroundColor(.primary)
                }
                .frame(height: 24)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .onAppear {
            AppSpacing.analyticsLogger = SpyLogger()
        }
    }
}
#Preview {
    AppSpacingPreview()
}
#endif

/// Usage example:
/// .padding(AppSpacing.medium)
/// .appPadding(AppSpacing.large)

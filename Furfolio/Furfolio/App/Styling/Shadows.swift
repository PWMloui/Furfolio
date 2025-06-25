//
//  Shadows.swift
//  Furfolio
//
//  ENHANCED: token-compliant, analytics/audit–ready, brandable, preview/testable, robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol ShadowAnalyticsLogger {
    func log(event: String, token: String, shadow: Shadow)
}
public struct NullShadowAnalyticsLogger: ShadowAnalyticsLogger {
    public init() {}
    public func log(event: String, token: String, shadow: Shadow) {}
}

// MARK: - AppShadows (Centralized, Theme/Brand-Aware Shadow Tokens)

/// Central place for all standard drop shadow styles in Furfolio.
/// All access is token-based, theme/brand-ready, analytics/audit–capable, and robust.
enum AppShadows {
    // Analytics logger for BI/QA/Trust Center/design system review.
    static var analyticsLogger: ShadowAnalyticsLogger = NullShadowAnalyticsLogger()

    // MARK: - Shadow Tokens (use only these in UI, never custom)
    static var card: Shadow     { fetch("card", Shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)) }
    static var modal: Shadow    { fetch("modal", Shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)) }
    static var thin: Shadow     { fetch("thin", Shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)) }
    static var inner: Shadow    { fetch("inner", Shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)) }
    static var avatar: Shadow   { fetch("avatar", Shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)) }
    static var button: Shadow   { fetch("button", Shadow(color: .black.opacity(0.09), radius: 5, x: 0, y: 2)) }

    /// All tokens for preview/design review
    static var all: [(String, Shadow)] {
        [
            ("Card", card),
            ("Modal", modal),
            ("Thin", thin),
            ("Inner", inner),
            ("Avatar", avatar),
            ("Button", button)
        ]
    }

    /// Brand/theme lookup, analytics logging, robust fallback.
    private static func fetch(_ token: String, _ fallback: Shadow) -> Shadow {
        // Future: theme/brand switch logic here (e.g. AppTheme/Shadows palette).
        analyticsLogger.log(event: "shadow_access", token: token, shadow: fallback)
        return fallback
    }
}

/// Helper struct for shadow configuration, fully codable for design system.
struct Shadow: Hashable, Codable {
    /// The color of the shadow
    let color: Color
    /// The blur radius of the shadow
    let radius: CGFloat
    /// The horizontal offset of the shadow
    let x: CGFloat
    /// The vertical offset of the shadow
    let y: CGFloat
}

// MARK: - View Modifier

extension View {
    /// Applies a standardized AppShadows style to any View.
    /// - Parameter shadow: The `Shadow` token from `AppShadows` to apply.
    /// - Returns: A view with the specified shadow applied.
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Preview/QA

#if DEBUG
struct AppShadowsPreview: View {
    struct SpyLogger: ShadowAnalyticsLogger {
        func log(event: String, token: String, shadow: Shadow) {
            print("[ShadowAnalytics] \(event) \(token): r\(shadow.radius) x\(shadow.x) y\(shadow.y)")
        }
    }

    init() {
        AppShadows.analyticsLogger = SpyLogger()
    }

    var body: some View {
        VStack(spacing: 30) {
            ForEach(AppShadows.all, id: \.0) { label, shadow in
                HStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .frame(width: 96, height: 44)
                        .appShadow(shadow)
                    VStack(alignment: .leading) {
                        Text(label).bold()
                        Text("r\(Int(shadow.radius)), x\(Int(shadow.x)), y\(Int(shadow.y))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#Preview {
    AppShadowsPreview()
}
#endif

// Usage example:
// Text("Hello, Furfolio!")
//     .padding()
//     .background(Color.white)
//     .appShadow(AppShadows.card)

//
//  AppFonts.swift
//  Furfolio
//
//  Enhanced: brand-ready, analytics/audit–ready, token-compliant, accessible, preview/testable, business/white-label robust.
//

import SwiftUI

// MARK: - Brand & Font Analytics

public enum FurfolioFontBrand: String, CaseIterable {
    case classic, modern, highContrast, business
}

public protocol AppFontAnalyticsLogger {
    func log(event: String, fontName: String, size: CGFloat, weight: Font.Weight, style: String)
}
public struct NullAppFontAnalyticsLogger: AppFontAnalyticsLogger {
    public init() {}
    public func log(event: String, fontName: String, size: CGFloat, weight: Font.Weight, style: String) {}
}

// MARK: - AppFonts (Centralized Font Management)

enum AppFonts {
    // MARK: - Settings
    static var currentBrand: FurfolioFontBrand = .classic
    static var analyticsLogger: AppFontAnalyticsLogger = NullAppFontAnalyticsLogger()

    // MARK: - Brand/Font Map
    private static let brandFonts: [FurfolioFontBrand: String] = [
        .classic: "System",
        .modern: "Avenir Next",
        .highContrast: "Menlo",
        .business: "SF Pro Rounded"
    ]
    /// Use this font name for your brand; fallback to system.
    private static var fontName: String {
        brandFonts[currentBrand] ?? "System"
    }

    // MARK: - Token Store (no magic numbers)
    private enum Tokens {
        static let largeTitle: CGFloat = 34
        static let title: CGFloat = 28
        static let headline: CGFloat = 20
        static let subheadline: CGFloat = 17
        static let body: CGFloat = 17
        static let callout: CGFloat = 16
        static let caption: CGFloat = 13
        static let caption2: CGFloat = 11
        static let footnote: CGFloat = 12
        static let button: CGFloat = 18
        static let tabBar: CGFloat = 14
        static let badge: CGFloat = 12
    }

    // MARK: - Font Factory

    /// Returns the current brand/system font.
    static func primary(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        analyticsLogger.log(event: "font_primary", fontName: fontName, size: size, weight: weight, style: "primary")
        if fontName == "System" {
            return .system(size: size, weight: weight, design: .rounded)
        } else {
            return .custom(fontName, size: size).weight(weight)
        }
    }

    // MARK: - Styles

    static var largeTitle: Font { primary(size: Tokens.largeTitle, weight: .bold) }
    static var title: Font { primary(size: Tokens.title, weight: .semibold) }
    static var headline: Font { primary(size: Tokens.headline, weight: .semibold) }
    static var subheadline: Font { primary(size: Tokens.subheadline, weight: .medium) }
    static var body: Font { primary(size: Tokens.body, weight: .regular) }
    static var callout: Font { primary(size: Tokens.callout, weight: .regular) }
    static var caption: Font { primary(size: Tokens.caption, weight: .regular) }
    static var caption2: Font { primary(size: Tokens.caption2, weight: .regular) }
    static var footnote: Font { primary(size: Tokens.footnote, weight: .medium) }
    static var button: Font { primary(size: Tokens.button, weight: .semibold) }
    static var tabBar: Font { primary(size: Tokens.tabBar, weight: .medium) }
    static var badge: Font { primary(size: Tokens.badge, weight: .bold) }

    // MARK: - Dynamic Type (supports accessibility/dynamic text sizes)
    static var dynamicBody: Font { Font.body.dynamicTypeSize(.large) }
    static var dynamicTitle: Font { Font.title.dynamicTypeSize(.large) }
    static var dynamicCaption: Font { Font.caption.dynamicTypeSize(.large) }

    static func scaled(size: CGFloat, weight: Font.Weight = .regular, textStyle: Font.TextStyle = .body) -> Font {
        analyticsLogger.log(event: "font_scaled", fontName: fontName, size: size, weight: weight, style: textStyle.rawValue)
        if fontName == "System" {
            return .system(size: size, weight: weight, design: .rounded).relative(to: textStyle)
        } else {
            return .custom(fontName, size: size).weight(weight).relative(to: textStyle)
        }
    }

    // MARK: - Custom Font Example (for adding more custom fonts)
    static func customFont(name: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        analyticsLogger.log(event: "font_custom", fontName: name, size: size, weight: weight, style: "custom")
        return .custom(name, size: size).weight(weight)
    }
}

// MARK: - Preview

#if DEBUG
struct AppFontsPreview: View {
    @State private var brand: FurfolioFontBrand = AppFonts.currentBrand

    struct SpyLogger: AppFontAnalyticsLogger {
        func log(event: String, fontName: String, size: CGFloat, weight: Font.Weight, style: String) {
            print("[FontAnalytics] \(event): \(fontName) \(size) \(weight) [\(style)]")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Brand", selection: $brand) {
                ForEach(FurfolioFontBrand.allCases, id: \.self) { brand in
                    Text(brand.rawValue.capitalized).tag(brand)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: brand) { newValue in
                AppFonts.currentBrand = newValue
            }
            Group {
                Text("Large Title").font(AppFonts.largeTitle)
                Text("Title").font(AppFonts.title)
                Text("Headline").font(AppFonts.headline)
                Text("Subheadline").font(AppFonts.subheadline)
                Text("Body").font(AppFonts.body)
                Text("Callout").font(AppFonts.callout)
                Text("Caption").font(AppFonts.caption)
                Text("Caption2").font(AppFonts.caption2)
                Text("Footnote").font(AppFonts.footnote)
                Text("Button Style").font(AppFonts.button)
                Text("Tab Bar Style").font(AppFonts.tabBar)
                Text("Badge Style").font(AppFonts.badge)
                Divider()
                Text("Dynamic Body").font(AppFonts.dynamicBody)
                Text("Dynamic Title").font(AppFonts.dynamicTitle)
                Text("Dynamic Caption").font(AppFonts.dynamicCaption)
            }
        }
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraLarge)
        .onAppear {
            AppFonts.analyticsLogger = SpyLogger()
        }
    }
}

#Preview {
    AppFontsPreview()
}
#endif

/*
Usage Example:

Text("Scalable Text")
    .font(AppFonts.scaled(size: 18, weight: .semibold, textStyle: .body))
    .dynamicTypeSize(...)

This ensures your text scales with the user's Dynamic Type settings for better accessibility and design consistency.
*/

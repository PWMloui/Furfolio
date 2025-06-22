//
//  AppFonts.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - AppFonts (Centralized Font Management)

/// Central place for all app font choices and styles.
/// Use only these throughout the app for consistency and easy design tweaks.
enum AppFonts {
    // MARK: - Brand & System Fonts

    /// The main brand font (replace with your custom font if needed)
    static func primary(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
        // Example for custom font:
        // Font.custom("YourCustomFontName", size: size).weight(weight)
    }

    // MARK: - Text Styles

    static var largeTitle: Font { primary(size: 34, weight: .bold) }
    static var title: Font { primary(size: 28, weight: .semibold) }
    static var headline: Font { primary(size: 20, weight: .semibold) }
    static var subheadline: Font { primary(size: 17, weight: .medium) }
    static var body: Font { primary(size: 17, weight: .regular) }
    static var callout: Font { primary(size: 16, weight: .regular) }
    static var caption: Font { primary(size: 13, weight: .regular) }
    static var caption2: Font { primary(size: 11, weight: .regular) }
    static var footnote: Font { primary(size: 12, weight: .medium) }

    // MARK: - Special Styles

    static var button: Font { primary(size: 18, weight: .semibold) }
    static var tabBar: Font { primary(size: 14, weight: .medium) }
    static var badge: Font { primary(size: 12, weight: .bold) }

    // MARK: - Dynamic Type (supports accessibility/dynamic text sizes)
    /// These fonts are configured to support Dynamic Type with accessibility scaling.
    /// Use `.dynamicTypeSize` modifier on views to adjust font size based on user settings.
    static var dynamicBody: Font { Font.body.dynamicTypeSize(.large) }
    static var dynamicTitle: Font { Font.title.dynamicTypeSize(.large) }
    static var dynamicCaption: Font { Font.caption.dynamicTypeSize(.large) }

    /// Returns a font scaled with dynamic type support.
    /// - Parameters:
    ///   - size: The base font size.
    ///   - weight: The font weight.
    ///   - textStyle: The text style to scale relative to.
    /// - Returns: A `Font` that scales dynamically according to the user's accessibility settings.
    static func scaled(size: CGFloat, weight: Font.Weight = .regular, textStyle: Font.TextStyle = .body) -> Font {
        .system(size: size, weight: weight, design: .rounded).relative(to: textStyle)
    }

    // MARK: - Custom Font Example (Uncomment if you add a custom font to your bundle)
    /*
    static func customFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("CustomFontName", size: size).weight(weight)
    }
    */
}

#if DEBUG
// MARK: - Preview

struct AppFontsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraLarge)
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

This will ensure your text scales correctly with the user's Dynamic Type settings for better accessibility.
*/

//
//  AppColors.swift
//  Furfolio
//
//  Enhanced: enterprise-ready, dynamic, accessible, white-label, analytics/audit–ready.
//

import SwiftUI

/// Enum for supported brands/themes. Expand as needed.
enum FurfolioBrand: String, CaseIterable {
    case classic, night, business, highContrast
}

/// Central palette for all Furfolio UI colors. Use these for consistency and easy re-theming.
/// Use `AppColors.current` for all app UI color references.
enum AppColors {
    // MARK: - Brand Logic (White-label/Business/QA Ready)

    /// Current brand/theme in use (future: set via user or config).
    static var currentBrand: FurfolioBrand = .classic

    /// Easy dynamic access to color tokens for the current brand.
    static var current: AppColors.Type { Self.self }

    // MARK: - Brand Token Store

    /// Central dictionary of all palette tokens per brand (expand as needed).
    private static let palette: [FurfolioBrand: [String: Color]] = [
        .classic: [
            "primary": Color("PrimaryColor"),
            "secondary": Color("SecondaryColor"),
            "background": Color("BackgroundColor"),
            "card": Color(.secondarySystemGroupedBackground),
            "success": .green,
            "warning": .orange,
            "danger": .red,
            "info": .blue,
            "overlay": Color.black.opacity(0.36),
            "shimmerBase": Color.gray.opacity(0.23),
            "shimmerHighlight": Color.gray.opacity(0.42),
            "textPrimary": .primary,
            "textSecondary": .secondary,
            "textPlaceholder": Color.gray.opacity(0.54),
            "separator": Color(.separator),
            "tagNew": .blue,
            "tagActive": .green,
            "tagReturning": .purple,
            "tagRisk": .orange,
            "tagInactive": .gray,
            "button": Color("PrimaryColor"),
            "buttonDisabled": Color.gray.opacity(0.33),
            "buttonText": .white
        ],
        .night: [
            "primary": Color("NightPrimaryColor"),
            "secondary": Color("NightSecondaryColor"),
            "background": Color("NightBackgroundColor"),
            "card": Color(.systemGray6),
            "success": .green.opacity(0.80),
            "warning": .yellow,
            "danger": .red.opacity(0.84),
            "info": .teal,
            "overlay": Color.black.opacity(0.61),
            "shimmerBase": Color.white.opacity(0.13),
            "shimmerHighlight": Color.white.opacity(0.35),
            "textPrimary": .white,
            "textSecondary": Color(.systemGray3),
            "textPlaceholder": Color.white.opacity(0.42),
            "separator": Color(.darkGray),
            "tagNew": .cyan,
            "tagActive": .mint,
            "tagReturning": .indigo,
            "tagRisk": .yellow,
            "tagInactive": .gray.opacity(0.44),
            "button": Color("NightPrimaryColor"),
            "buttonDisabled": Color.gray.opacity(0.41),
            "buttonText": .black
        ],
        .highContrast: [
            "primary": .black,
            "secondary": .yellow,
            "background": .white,
            "card": .yellow.opacity(0.18),
            "success": .green,
            "warning": .yellow,
            "danger": .red,
            "info": .blue,
            "overlay": .black,
            "shimmerBase": .black.opacity(0.13),
            "shimmerHighlight": .yellow.opacity(0.28),
            "textPrimary": .black,
            "textSecondary": .yellow,
            "textPlaceholder": .gray,
            "separator": .black,
            "tagNew": .yellow,
            "tagActive": .green,
            "tagReturning": .orange,
            "tagRisk": .red,
            "tagInactive": .gray,
            "button": .yellow,
            "buttonDisabled": .gray,
            "buttonText": .black
        ],
        .business: [
            // Example: add corporate palette here for business clients/white label.
            "primary": .purple,
            "secondary": .mint,
            "background": Color(.systemGray6),
            "card": .white,
            "success": .green,
            "warning": .orange,
            "danger": .red,
            "info": .blue,
            "overlay": Color.black.opacity(0.23),
            "shimmerBase": Color.purple.opacity(0.18),
            "shimmerHighlight": Color.purple.opacity(0.38),
            "textPrimary": .purple,
            "textSecondary": .mint,
            "textPlaceholder": .gray,
            "separator": .purple.opacity(0.44),
            "tagNew": .blue,
            "tagActive": .green,
            "tagReturning": .purple,
            "tagRisk": .red,
            "tagInactive": .gray,
            "button": .purple,
            "buttonDisabled": .gray.opacity(0.33),
            "buttonText": .white
        ]
    ]

    // MARK: - Color Accessors (Tokens, never use raw Color in app UI)
    static var primary: Color         { token("primary") }
    static var secondary: Color       { token("secondary") }
    static var background: Color      { token("background") }
    static var card: Color            { token("card") }
    static var success: Color         { token("success") }
    static var warning: Color         { token("warning") }
    static var danger: Color          { token("danger") }
    static var info: Color            { token("info") }
    static var overlay: Color         { token("overlay") }
    static var shimmerBase: Color     { token("shimmerBase") }
    static var shimmerHighlight: Color{ token("shimmerHighlight") }
    static var textPrimary: Color     { token("textPrimary") }
    static var textSecondary: Color   { token("textSecondary") }
    static var textPlaceholder: Color { token("textPlaceholder") }
    static var separator: Color       { token("separator") }
    static var tagNew: Color          { token("tagNew") }
    static var tagActive: Color       { token("tagActive") }
    static var tagReturning: Color    { token("tagReturning") }
    static var tagRisk: Color         { token("tagRisk") }
    static var tagInactive: Color     { token("tagInactive") }
    static var button: Color          { token("button") }
    static var buttonDisabled: Color  { token("buttonDisabled") }
    static var buttonText: Color      { token("buttonText") }

    // MARK: - Animation Placeholder
    static let fadeInOut = Color.clear

    // MARK: - Token Utility

    /// Looks up a token for the current brand, falling back to classic if missing.
    private static func token(_ key: String) -> Color {
        palette[currentBrand]?[key] ?? palette[.classic]?[key] ?? .pink // fallback for missing
    }

    // MARK: - Color Utilities

    /// Returns a contrasting color for text (black/white) for the given background color.
    static func contrasting(for background: Color) -> Color {
        // Crude luminance: future: use more precise algorithm.
        UIColor(background).cgColor.components?.first ?? 1.0 > 0.5 ? .black : .white
    }

    /// Utility: returns hex string for any color (for debug/analytics)
    static func hex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        guard let comps = uiColor.cgColor.components, comps.count >= 3 else { return "#???" }
        return String(format:"#%02X%02X%02X", Int(comps[0]*255), Int(comps[1]*255), Int(comps[2]*255))
    }
}

// MARK: - Audit/Analytics (Example)

public protocol PalettePreviewAnalyticsLogger {
    func log(event: String, brand: FurfolioBrand)
}
public struct NullPalettePreviewAnalyticsLogger: PalettePreviewAnalyticsLogger {
    public init() {}
    public func log(event: String, brand: FurfolioBrand) {}
}

// MARK: - SwiftUI Preview

#if DEBUG
struct AppColorsPreview: View {
    @State private var brand: FurfolioBrand = AppColors.currentBrand
    var analyticsLogger: PalettePreviewAnalyticsLogger = NullPalettePreviewAnalyticsLogger()

    var body: some View {
        VStack(spacing: 24) {
            Picker("Brand", selection: $brand) {
                ForEach(FurfolioBrand.allCases, id: \.self) { brand in
                    Text(brand.rawValue.capitalized).tag(brand)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: brand) { newValue in
                AppColors.currentBrand = newValue
                analyticsLogger.log(event: "brand_switch", brand: newValue)
            }

            ScrollView {
                ForEach([
                    ("Primary", AppColors.primary),
                    ("Secondary", AppColors.secondary),
                    ("Success", AppColors.success),
                    ("Warning", AppColors.warning),
                    ("Danger", AppColors.danger),
                    ("Info", AppColors.info),
                    ("Background", AppColors.background),
                    ("Card", AppColors.card),
                    ("Overlay", AppColors.overlay),
                    ("Shimmer Base", AppColors.shimmerBase),
                    ("Shimmer Highlight", AppColors.shimmerHighlight),
                    ("Text Primary", AppColors.textPrimary),
                    ("Text Secondary", AppColors.textSecondary),
                    ("Text Placeholder", AppColors.textPlaceholder),
                    ("Separator", AppColors.separator),
                    ("Tag New", AppColors.tagNew),
                    ("Tag Active", AppColors.tagActive),
                    ("Tag Returning", AppColors.tagReturning),
                    ("Tag Risk", AppColors.tagRisk),
                    ("Tag Inactive", AppColors.tagInactive),
                    ("Button", AppColors.button),
                    ("Button Disabled", AppColors.buttonDisabled),
                    ("Button Text", AppColors.buttonText)
                ], id: \.0) { label, color in
                    ColorSwatch(label: label, color: color)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(AppColors.background)
    }

    struct ColorSwatch: View {
        let label: String
        let color: Color

        var body: some View {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(color)
                    .frame(width: 54, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(AppColors.separator.opacity(0.28), lineWidth: 1)
                    )
                    .accessibilityLabel(Text("\(label) color swatch"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.callout)
                        .foregroundColor(AppColors.textPrimary)
                    Text(AppColors.hex(color))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.leading, 8)
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }
}

#Preview {
    AppColorsPreview()
}
#endif

//
//  AppFonts.swift
//  Furfolio
//
//  AppFonts.swift is the centralized font management system designed for Furfolio, providing a robust, extensible, and brand-aware typography solution.
//  
//  Architecture & Extensibility:
//  - Defines FurfolioFontBrand enum representing supported font brands with localized display names.
//  - AppFonts enum manages font selection, sizing tokens, and dynamic scaling with accessibility support.
//  - Supports adding custom fonts via a factory method.
//  
//  Analytics, Audit & Trust Center Integration:
//  - AppFontAnalyticsLogger protocol defines async logging interface with a testMode property to distinguish production from test/preview environments.
//  - NullAppFontAnalyticsLogger provides a no-op implementation for previews and tests.
//  - Logs font usage events with font name, size, weight, and style asynchronously.
//  - Maintains a capped buffer of the last 20 analytics events for diagnostics and audit purposes.
//  - Public API to retrieve recent analytics events for admin or diagnostic UIs.
//  
//  Diagnostics & Compliance:
//  - Analytics buffer supports audit trails and diagnostics for font usage patterns.
//  - Designed for accessibility compliance with dynamic type scaling and semantic font styles.
//  - Localization-ready with all user-facing strings using NSLocalizedString for internationalization.
//  
//  Preview & Testability:
//  - Includes a comprehensive preview provider demonstrating font styles, brand switching, analytics logging, and diagnostics buffer.
//  - Preview UI allows toggling testMode to simulate QA/test scenarios with console logging.
//  - Accessibility settings are showcased in previews for testing dynamic type support.
//  
//  Localization:
//  - All user-facing strings (brand names, font style labels, picker titles) are localized using NSLocalizedString with descriptive comments.
//  
//  Future Maintainers:
//  - Use the centralized AppFonts enum to add or modify font styles and brands.
//  - Extend AppFontAnalyticsLogger for integrating with real analytics backends asynchronously.
//  - Use recentAnalyticsEvents API for diagnostics or admin UI integration.
//  - Maintain localization keys and comments to ensure proper translations.
//
//  This file is the single source of truth for typography in Furfolio, ensuring consistency, auditability, and accessibility.
//
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AppFontsAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AppFonts"
}

// MARK: - Brand & Font Analytics

/// Represents the supported font brands in Furfolio.
public enum FurfolioFontBrand: String, CaseIterable {
    case classic, modern, highContrast, business
    
    /// Localized display name for the font brand.
    public var displayName: String {
        switch self {
        case .classic:
            return NSLocalizedString("brand_classic", value: "Classic", comment: "Classic font brand name")
        case .modern:
            return NSLocalizedString("brand_modern", value: "Modern", comment: "Modern font brand name")
        case .highContrast:
            return NSLocalizedString("brand_highContrast", value: "High Contrast", comment: "High Contrast font brand name")
        case .business:
            return NSLocalizedString("brand_business", value: "Business", comment: "Business font brand name")
        }
    }
}

/// Protocol defining asynchronous font analytics logging interface with audit/trust center context.
public protocol AppFontAnalyticsLogger {
    /// Indicates if the logger is in test mode (e.g., for previews, QA, or tests).
    var testMode: Bool { get }
    func log(
        event: String,
        fontName: String,
        size: CGFloat,
        weight: Font.Weight,
        style: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    func recentEvents() -> [AppFontAnalyticsEvent]
}

/// Analytics event struct for audit/trust center.
public struct AppFontAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let fontName: String
    public let size: CGFloat
    public let weight: Font.Weight
    public let style: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// No-op analytics logger for previews and tests (trust center/audit compliant).
public struct NullAppFontAnalyticsLogger: AppFontAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func log(
        event: String,
        fontName: String,
        size: CGFloat,
        weight: Font.Weight,
        style: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[FontAnalytics/NullLogger] event:\(event) fontName:\(fontName) size:\(size) weight:\(weight) style:\(style) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
        // No storage for null logger.
    }
    public func recentEvents() -> [AppFontAnalyticsEvent] {
        return []
    }
}

// MARK: - AppFonts (Centralized Font Management)

enum AppFonts {
    // MARK: - Settings
    /// Current selected font brand.
    static var currentBrand: FurfolioFontBrand = .classic
    /// Analytics logger instance, defaults to null logger.
    static var analyticsLogger: AppFontAnalyticsLogger = NullAppFontAnalyticsLogger()

    // MARK: - Brand/Font Map
    private static let brandFonts: [FurfolioFontBrand: String] = [
        .classic: "System",
        .modern: "Avenir Next",
        .highContrast: "Menlo",
        .business: "SF Pro Rounded"
    ]
    /// Returns the font name for the current brand, falling back to system font.
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

    // MARK: - Analytics Event Buffer (trust center/compliance/audit)
    /// Maximum number of analytics events to keep in buffer.
    private static let maxEventBufferSize = 20
    /// Thread-safe buffer of recent analytics events for diagnostics/trust center.
    private static var analyticsEventBuffer = [AppFontAnalyticsEvent]()
    private static let analyticsBufferQueue = DispatchQueue(label: "AppFonts.analyticsBufferQueue", attributes: .concurrent)
    /// Adds a new analytics event to the buffer, maintaining size limit.
    private static func addEventToBuffer(_ event: AppFontAnalyticsEvent) {
        analyticsBufferQueue.async(flags: .barrier) {
            if analyticsEventBuffer.count >= maxEventBufferSize {
                analyticsEventBuffer.removeFirst()
            }
            analyticsEventBuffer.append(event)
        }
    }
    /// Public API to fetch recent analytics events for diagnostics or admin UI.
    /// - Returns: Array of recent AppFontAnalyticsEvent, most recent last.
    public static func recentAnalyticsEvents() -> [AppFontAnalyticsEvent] {
        var eventsCopy = [AppFontAnalyticsEvent]()
        analyticsBufferQueue.sync {
            eventsCopy = analyticsEventBuffer
        }
        return eventsCopy
    }

    // MARK: - Font Factory
    /// Returns the current brand/system font.
    /// - Parameters:
    ///   - size: Font size.
    ///   - weight: Font weight, default is regular.
    /// - Returns: Configured Font instance.
    static func primary(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let eventName = "font_primary"
        let style = "primary"
        let escalate = eventName == "font_custom"
            || style.lowercased().contains("danger")
            || style.lowercased().contains("delete")
            || style.lowercased().contains("critical")
        let event = AppFontAnalyticsEvent(
            timestamp: Date(),
            event: eventName,
            fontName: fontName,
            size: size,
            weight: weight,
            style: style,
            role: AppFontsAuditContext.role,
            staffID: AppFontsAuditContext.staffID,
            context: AppFontsAuditContext.context,
            escalate: escalate
        )
        Task {
            await analyticsLogger.log(
                event: event.event,
                fontName: event.fontName,
                size: event.size,
                weight: event.weight,
                style: event.style,
                role: event.role,
                staffID: event.staffID,
                context: event.context,
                escalate: event.escalate
            )
        }
        addEventToBuffer(event)
        if fontName == "System" {
            return .system(size: size, weight: weight, design: .rounded)
        } else {
            return .custom(fontName, size: size).weight(weight)
        }
    }

    // MARK: - Styles
    /// Large Title font style.
    static var largeTitle: Font { primary(size: Tokens.largeTitle, weight: .bold) }
    /// Title font style.
    static var title: Font { primary(size: Tokens.title, weight: .semibold) }
    /// Headline font style.
    static var headline: Font { primary(size: Tokens.headline, weight: .semibold) }
    /// Subheadline font style.
    static var subheadline: Font { primary(size: Tokens.subheadline, weight: .medium) }
    /// Body font style.
    static var body: Font { primary(size: Tokens.body, weight: .regular) }
    /// Callout font style.
    static var callout: Font { primary(size: Tokens.callout, weight: .regular) }
    /// Caption font style.
    static var caption: Font { primary(size: Tokens.caption, weight: .regular) }
    /// Caption2 font style.
    static var caption2: Font { primary(size: Tokens.caption2, weight: .regular) }
    /// Footnote font style.
    static var footnote: Font { primary(size: Tokens.footnote, weight: .medium) }
    /// Button font style.
    static var button: Font { primary(size: Tokens.button, weight: .semibold) }
    /// Tab Bar font style.
    static var tabBar: Font { primary(size: Tokens.tabBar, weight: .medium) }
    /// Badge font style.
    static var badge: Font { primary(size: Tokens.badge, weight: .bold) }

    // MARK: - Dynamic Type (supports accessibility/dynamic text sizes)
    /// Dynamic Body font style supporting dynamic type size.
    static var dynamicBody: Font { Font.body.dynamicTypeSize(.large) }
    /// Dynamic Title font style supporting dynamic type size.
    static var dynamicTitle: Font { Font.title.dynamicTypeSize(.large) }
    /// Dynamic Caption font style supporting dynamic type size.
    static var dynamicCaption: Font { Font.caption.dynamicTypeSize(.large) }

    /// Returns a scaled font for dynamic type with analytics logging.
    /// - Parameters:
    ///   - size: Base font size.
    ///   - weight: Font weight, default regular.
    ///   - textStyle: Font.TextStyle for relative scaling, default body.
    /// - Returns: Scaled Font instance.
    static func scaled(size: CGFloat, weight: Font.Weight = .regular, textStyle: Font.TextStyle = .body) -> Font {
        let eventName = "font_scaled"
        let style = textStyle.rawValue
        let escalate = eventName == "font_custom"
            || style.lowercased().contains("danger")
            || style.lowercased().contains("delete")
            || style.lowercased().contains("critical")
        let event = AppFontAnalyticsEvent(
            timestamp: Date(),
            event: eventName,
            fontName: fontName,
            size: size,
            weight: weight,
            style: style,
            role: AppFontsAuditContext.role,
            staffID: AppFontsAuditContext.staffID,
            context: AppFontsAuditContext.context,
            escalate: escalate
        )
        Task {
            await analyticsLogger.log(
                event: event.event,
                fontName: event.fontName,
                size: event.size,
                weight: event.weight,
                style: event.style,
                role: event.role,
                staffID: event.staffID,
                context: event.context,
                escalate: event.escalate
            )
        }
        addEventToBuffer(event)
        if fontName == "System" {
            return .system(size: size, weight: weight, design: .rounded).relative(to: textStyle)
        } else {
            return .custom(fontName, size: size).weight(weight).relative(to: textStyle)
        }
    }

    // MARK: - Custom Font Example (for adding more custom fonts)
    /// Creates a custom font with analytics logging.
    /// - Parameters:
    ///   - name: Custom font name.
    ///   - size: Font size.
    ///   - weight: Font weight, default regular.
    /// - Returns: Custom Font instance.
    static func customFont(name: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let eventName = "font_custom"
        let style = "custom"
        let escalate = eventName == "font_custom"
            || style.lowercased().contains("danger")
            || style.lowercased().contains("delete")
            || style.lowercased().contains("critical")
        let event = AppFontAnalyticsEvent(
            timestamp: Date(),
            event: eventName,
            fontName: name,
            size: size,
            weight: weight,
            style: style,
            role: AppFontsAuditContext.role,
            staffID: AppFontsAuditContext.staffID,
            context: AppFontsAuditContext.context,
            escalate: escalate
        )
        Task {
            await analyticsLogger.log(
                event: event.event,
                fontName: event.fontName,
                size: event.size,
                weight: event.weight,
                style: event.style,
                role: event.role,
                staffID: event.staffID,
                context: event.context,
                escalate: event.escalate
            )
        }
        addEventToBuffer(event)
        return .custom(name, size: size).weight(weight)
    }
}

// MARK: - Preview

// MARK: - Preview (trust center/compliance/audit context)
#if DEBUG
/// Preview provider demonstrating AppFonts usage, analytics logging, diagnostics buffer, and accessibility support.
struct AppFontsPreview: View {
    @State private var brand: FurfolioFontBrand = AppFonts.currentBrand
    @State private var isTestMode: Bool = true
    @State private var recentEvents: [AppFontAnalyticsEvent] = []

    /// Spy logger that prints logs to console and supports testMode, with audit fields.
    struct SpyLogger: AppFontAnalyticsLogger {
        let testMode: Bool
        private var events: [AppFontAnalyticsEvent] = []
        func log(
            event: String,
            fontName: String,
            size: CGFloat,
            weight: Font.Weight,
            style: String,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            if testMode {
                print("[FontAnalytics/SpyLogger] event:\(event) fontName:\(fontName) size:\(size) weight:\(weight) style:\(style) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
            }
            // Simulate async delay for demonstration.
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        func recentEvents() -> [AppFontAnalyticsEvent] { [] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker(NSLocalizedString("picker_brand", value: "Brand", comment: "Brand picker title"), selection: $brand) {
                ForEach(FurfolioFontBrand.allCases, id: \.self) { brand in
                    Text(brand.displayName).tag(brand)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: brand) { newValue in
                AppFonts.currentBrand = newValue
            }

            Toggle(NSLocalizedString("toggle_testMode", value: "Test Mode Logging", comment: "Toggle for test mode logging"), isOn: $isTestMode)
                .onChange(of: isTestMode) { newValue in
                    AppFonts.analyticsLogger = SpyLogger(testMode: newValue)
                }

            Group {
                Text(NSLocalizedString("label_largeTitle", value: "Large Title", comment: "Font style label: Large Title")).font(AppFonts.largeTitle)
                Text(NSLocalizedString("label_title", value: "Title", comment: "Font style label: Title")).font(AppFonts.title)
                Text(NSLocalizedString("label_headline", value: "Headline", comment: "Font style label: Headline")).font(AppFonts.headline)
                Text(NSLocalizedString("label_subheadline", value: "Subheadline", comment: "Font style label: Subheadline")).font(AppFonts.subheadline)
                Text(NSLocalizedString("label_body", value: "Body", comment: "Font style label: Body")).font(AppFonts.body)
                Text(NSLocalizedString("label_callout", value: "Callout", comment: "Font style label: Callout")).font(AppFonts.callout)
                Text(NSLocalizedString("label_caption", value: "Caption", comment: "Font style label: Caption")).font(AppFonts.caption)
                Text(NSLocalizedString("label_caption2", value: "Caption2", comment: "Font style label: Caption2")).font(AppFonts.caption2)
                Text(NSLocalizedString("label_footnote", value: "Footnote", comment: "Font style label: Footnote")).font(AppFonts.footnote)
                Text(NSLocalizedString("label_button", value: "Button Style", comment: "Font style label: Button")).font(AppFonts.button)
                Text(NSLocalizedString("label_tabBar", value: "Tab Bar Style", comment: "Font style label: Tab Bar")).font(AppFonts.tabBar)
                Text(NSLocalizedString("label_badge", value: "Badge Style", comment: "Font style label: Badge")).font(AppFonts.badge)
                Divider()
                Text(NSLocalizedString("label_dynamicBody", value: "Dynamic Body", comment: "Font style label: Dynamic Body")).font(AppFonts.dynamicBody)
                Text(NSLocalizedString("label_dynamicTitle", value: "Dynamic Title", comment: "Font style label: Dynamic Title")).font(AppFonts.dynamicTitle)
                Text(NSLocalizedString("label_dynamicCaption", value: "Dynamic Caption", comment: "Font style label: Dynamic Caption")).font(AppFonts.dynamicCaption)
            }

            Divider()

            Text(NSLocalizedString("label_recentEvents", value: "Recent Analytics Events", comment: "Label for recent analytics events list"))
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentEvents) { event in
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Event: \(event.event)  Font: \(event.fontName)  Size: \(String(format: "%.1f", event.size))  Weight: \(String(describing: event.weight))")
                                .font(.caption)
                            Text("Style: \(event.style)  Role: \(event.role ?? "-")  StaffID: \(event.staffID ?? "-")  Context: \(event.context ?? "-")  Escalate: \(event.escalate ? "YES" : "NO")")
                                .font(.caption2)
                            Text("Timestamp: \(event.timestamp.formatted(.dateTime.hour().minute().second()))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding(.bottom, 2)
                    }
                }
            }
            .frame(maxHeight: 220)

            Spacer()
        }
        .padding()
        .environment(\.sizeCategory, .accessibilityExtraLarge)
        .onAppear {
            AppFonts.analyticsLogger = SpyLogger(testMode: isTestMode)
            refreshEvents()
        }
        .onChange(of: isTestMode) { _ in
            refreshEvents()
        }
        .onChange(of: brand) { _ in
            refreshEvents()
        }
    }

    /// Refreshes the recent analytics events from the buffer.
    private func refreshEvents() {
        recentEvents = AppFonts.recentAnalyticsEvents()
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

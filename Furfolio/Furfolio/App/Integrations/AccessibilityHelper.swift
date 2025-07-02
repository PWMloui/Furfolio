//
//  AccessibilityHelper.swift
//  Furfolio
//
//  Enhanced: audit logger injection, public color contrast check, per-action permission/AccessControl plug-in, preview-safe, future-proofed, business compliance ready.
//

import Foundation
import SwiftUI

// MARK: - Audit Logger Protocol (Injectable)

public protocol AccessibilityAuditLogger {
    func log(event: String, metadata: [String: Any]?)
}

// MARK: - AccessibilityHelper

/// AccessibilityHelper provides a centralized, extensible utility for managing accessibility features throughout Furfolio.
/// It supports audit logging for compliance, event analytics, preview safety, and is extensible with external analytics/event injection.
/// Utilities include element labeling, trait assignment, color contrast validation, live announcement, and view introspection.
enum AccessibilityHelper {
    /// Optional external analytics/event logger (injectable or global).
    static var analyticsLogger: ((String, [String: Any]?) -> Void)?
    static var auditLogger: AccessibilityAuditLogger?

    /// Runtime flag to enable accessibility debug logging.
    static var accessibilityDebug: Bool = false

    /// Optional permission checker (from AccessControl).
    static var permissionChecker: ((String) -> Bool)?

    /// PUBLIC: Check color contrast and post a warning if below threshold (for audit, preview, or engine use).
    public static func checkColorContrast(foreground: Color, background: Color, context: String) {
        // Contrast ratio calculation based on WCAG 2.1
        func luminance(_ color: Color) -> Double {
            let components = color.cgColor?.components ?? [0,0,0]
            func adjust(_ c: CGFloat) -> Double {
                let c = Double(c)
                return (c <= 0.03928) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * adjust(components[0]) + 0.7152 * adjust(components[1]) + 0.0722 * adjust(components[2])
        }
        let fgLum = luminance(foreground)
        let bgLum = luminance(background)
        let ratio = (max(fgLum, bgLum) + 0.05) / (min(fgLum, bgLum) + 0.05)
        if ratio < 4.5 {
            logEvent("ColorContrastWarning", metadata: [
                "ratio": ratio,
                "foreground": String(describing: foreground),
                "background": String(describing: background),
                "context": context
            ])
        }
    }

    // MARK: - SwiftUI Accessibility Extensions

    @ViewBuilder
    static func labeled<V: View>(_ view: V, label: String, value: String? = nil) -> some View {
        view
            .accessibilityLabel(Text(label))
            .accessibilityValue(value.map(Text.init) ?? Text(""))
    }

    @ViewBuilder
    static func withTrait<V: View>(_ view: V, trait: AccessibilityTraits) -> some View {
        view.accessibilityAddTraits(trait)
    }

    @ViewBuilder
    static func withTraits<V: View>(_ view: V, traits: [AccessibilityTraits]) -> some View {
        traits.reduce(view) { result, trait in
            result.accessibilityAddTraits(trait)
        }
    }

    @ViewBuilder
    static func withHint<V: View>(_ view: V, hint: String) -> some View {
        view.accessibilityHint(Text(hint))
    }

    @ViewBuilder
    static func hidden<V: View>(_ view: V) -> some View {
        view.accessibilityHidden(true)
    }

    /// Announces an accessibility message, supports audit, analytics, and compliance reporting.
    static func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp.mainWindow ?? NSApp, notification: .announcementRequested)
        #endif
        logEvent("announce", metadata: ["message": message])
        analyticsLogger?("announce", ["message": message])
        auditLogger?.log(event: "announce", metadata: ["message": message])
    }

    /// Announces a localized accessibility message by key.
    static func announceLocalized(key: String) {
        let message = NSLocalizedString(key, comment: "")
        announce(message)
        logEvent("announceLocalized", metadata: ["key": key, "message": message])
        analyticsLogger?("announceLocalized", ["key": key, "message": message])
        auditLogger?.log(event: "announceLocalized", metadata: ["key": key, "message": message])
    }

    @ViewBuilder
    static func row<V: View>(_ view: V, label: String, hint: String? = nil, identifier: String? = nil) -> some View {
        var modified = view
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
        if let id = identifier {
            modified = modified.accessibilityIdentifier(id)
        }
        modified
    }

    @ViewBuilder
    static func button<V: View>(_ view: V, label: String, hint: String? = nil, identifier: String? = nil) -> some View {
        var modified = view
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
            .accessibilityAddTraits(.isButton)
        if let id = identifier {
            modified = modified.accessibilityIdentifier(id)
        }
        modified
    }

    /// Enumerates all accessibility elements within a view for audit/testing purposes.
    static func enumerateAccessibilityElements<V: View>(in view: V) -> [String] {
        // Placeholder—requires runtime introspection, left for UI test/preview harness.
        return []
    }

    // MARK: - Business Audit/Event Logging

    /// Logs accessibility events with rich metadata for business, compliance, or analytics.
    static func logEvent(_ event: String, metadata: [String: Any]? = nil) {
        if accessibilityDebug {
            print("[Accessibility] \(event): \(metadata ?? [:])")
        }
        auditLogger?.log(event: event, metadata: metadata)
        analyticsLogger?(event, metadata)
        #if !DEBUG
        // Plug in global audit logger (or App-wide AuditLogger/engine) if available.
        // Example: AuditLogger.shared.log(category: .accessibility, event: event, metadata: metadata)
        #endif
    }

    /// Log explicit accessibility errors for compliance or user safety reporting.
    static func logError(_ message: String, context: String? = nil) {
        logEvent("AccessibilityError", metadata: [
            "message": message,
            "context": context ?? ""
        ])
        auditLogger?.log(event: "AccessibilityError", metadata: [
            "message": message,
            "context": context ?? ""
        ])
    }

    /// Optional per-action access check via AccessControl, for compliance/preview.
    static func checkPermission(for action: String) -> Bool {
        permissionChecker?(action) ?? true
    }
}

// MARK: - Previews (Always Safe, Always Fallback-Proof)

#if DEBUG
private let safeMedium: CGFloat = (AppSpacing.medium ?? 16)
private let safeBg = (AppColors.secondaryBackground ?? Color(.secondarySystemBackground))
private let safeRadius = (AppRadius.medium ?? 12)
private let safeMainBg = (AppColors.background ?? Color(.systemBackground))
private let safeFg = Color.primary

struct AccessibilityHelper_Preview: View {
    @State private var loggedEvents: [String] = []

    var body: some View {
        VStack(spacing: safeMedium) {
            AccessibilityHelper.labeled(
                HStack {
                    Image(systemName: "pawprint")
                    Text(LocalizedStringKey("Bella"))
                },
                label: NSLocalizedString("Dog name", comment: ""),
                value: NSLocalizedString("Bella", comment: "")
            )
            .padding()
            .background(safeBg)
            .cornerRadius(safeRadius)
            .onAppear {
                AccessibilityHelper.checkColorContrast(foreground: safeFg, background: safeBg, context: "Labeled View Background")
            }

            AccessibilityHelper.row(
                HStack {
                    Image(systemName: "phone.fill")
                    Text(LocalizedStringKey("Call Owner"))
                },
                label: NSLocalizedString("Call Owner Button", comment: ""),
                hint: NSLocalizedString("Double-tap to call", comment: ""),
                identifier: "callOwnerButton"
            )
            .padding()
            .background(safeBg)
            .cornerRadius(safeRadius)
            .onAppear {
                AccessibilityHelper.checkColorContrast(foreground: safeFg, background: safeBg, context: "Row Background")
            }

            Button("Simulate Announcement") {
                AccessibilityHelper.announce("Test announcement")
                loggedEvents.append("announce: Test announcement")
            }
            .padding()
            .background(safeBg)
            .cornerRadius(safeRadius)
            .accessibilityIdentifier("simulateAnnouncementButton")

            if !loggedEvents.isEmpty {
                VStack(alignment: .leading) {
                    Text("Logged Accessibility Events:")
                        .font(.headline)
                    ForEach(loggedEvents, id: \.self) { event in
                        Text(event)
                            .font(.caption)
                    }
                }
                .padding()
                .background(safeBg.opacity(0.6))
                .cornerRadius(safeRadius)
            }
        }
        .padding()
        .background(safeMainBg)
        .onAppear {
            AccessibilityHelper.accessibilityDebug = true
            AccessibilityHelper.analyticsLogger = { event, metadata in
                loggedEvents.append("Analytics: \(event) \(metadata ?? [:])")
            }
        }
    }
}

struct AccessibilityHelper_Preview_LargeText: View {
    var body: some View {
        AccessibilityHelper_Preview()
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

#Preview {
    Group {
        AccessibilityHelper_Preview()
            .preferredColorScheme(.light)
            .previewDisplayName("Light")
        AccessibilityHelper_Preview()
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark")
        AccessibilityHelper_Preview_LargeText()
            .preferredColorScheme(.light)
            .previewDisplayName("Accessibility Text Light")
        AccessibilityHelper_Preview_LargeText()
            .preferredColorScheme(.dark)
            .previewDisplayName("Accessibility Text Dark")
    }
}
#endif

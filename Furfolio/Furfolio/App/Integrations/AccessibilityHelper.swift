//
//  AccessibilityHelper.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced: token-fallback, auditable, preview-safe, and extensible.
//

import Foundation
import SwiftUI

/// Unified, modular helper for applying accessibility labels, traits, values, and dynamic announcements.
/// Prepares for business diagnostics, Trust Center audit logging, and localization.
enum AccessibilityHelper {
    /// Applies an accessibility label and (optional) value to a view.
    @ViewBuilder
    static func labeled<V: View>(_ view: V, label: String, value: String? = nil) -> some View {
        view
            .accessibilityLabel(Text(label))
            .accessibilityValue(value.map(Text.init) ?? Text(""))
    }

    /// Adds an accessibility trait to a view.
    @ViewBuilder
    static func withTrait<V: View>(_ view: V, trait: AccessibilityTraits) -> some View {
        view.accessibilityAddTraits(trait)
    }

    /// Adds an accessibility hint to a view.
    @ViewBuilder
    static func withHint<V: View>(_ view: V, hint: String) -> some View {
        view.accessibilityHint(Text(hint))
    }

    /// Hides a view from the accessibility tree.
    @ViewBuilder
    static func hidden<V: View>(_ view: V) -> some View {
        view.accessibilityHidden(true)
    }

    /// Announces a message for VoiceOver (iOS only; stubbed elsewhere).
    static func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
        // TODO: Hook to audit logger for Trust Center/business compliance.
    }

    /// Combines label/hint for row-like accessibility elements.
    @ViewBuilder
    static func row<V: View>(_ view: V, label: String, hint: String? = nil) -> some View {
        view
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
    }

    /// Logs an accessibility-related event (for audit/diagnostics; stub).
    static func logEvent(_ event: String, extra: String? = nil) {
        // TODO: Connect to Trust Center/audit event logger.
    }
}

// MARK: - Previews (Preview always works, even if tokens are undefined)

#if DEBUG
private let safeMedium: CGFloat = (AppSpacing.medium ?? 16)
private let safeBg = (AppColors.secondaryBackground ?? Color(.secondarySystemBackground))
private let safeRadius = (AppRadius.medium ?? 12)
private let safeMainBg = (AppColors.background ?? Color(.systemBackground))

struct AccessibilityHelper_Preview: View {
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

            AccessibilityHelper.row(
                HStack {
                    Image(systemName: "phone.fill")
                    Text(LocalizedStringKey("Call Owner"))
                },
                label: NSLocalizedString("Call Owner Button", comment: ""),
                hint: NSLocalizedString("Double-tap to call", comment: "")
            )
            .padding()
            .background(safeBg)
            .cornerRadius(safeRadius)
        }
        .padding()
        .background(safeMainBg)
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

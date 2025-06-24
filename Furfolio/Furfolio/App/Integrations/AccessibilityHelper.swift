//
//  AccessibilityHelper.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated, modular, and fully tokenized.
//

import Foundation
import SwiftUI

/// Modular helper for applying accessibility labels, values, traits, and dynamic announcements.
/// Unified for Furfolio’s business, diagnostics, and Trust Center hooks.
enum AccessibilityHelper {
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
    static func withHint<V: View>(_ view: V, hint: String) -> some View {
        view.accessibilityHint(Text(hint))
    }

    @ViewBuilder
    static func hidden<V: View>(_ view: V) -> some View {
        view.accessibilityHidden(true)
    }

    static func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
        // TODO: Hook to audit logger for Trust Center.
    }

    @ViewBuilder
    static func row<V: View>(_ view: V, label: String, hint: String? = nil) -> some View {
        view
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
    }

    static func logEvent(_ event: String, extra: String? = nil) {
        // TODO: Audit/event logger.
    }
}

#if DEBUG
struct AccessibilityHelper_Preview: View {
    var body: some View {
        VStack(spacing: AppSpacing.medium) { // TODO: Define AppSpacing.medium if not existing
            AccessibilityHelper.labeled(
                HStack {
                    Image(systemName: "pawprint")
                    Text(LocalizedStringKey("Bella"))
                }, label: NSLocalizedString("Dog name", comment: ""), value: NSLocalizedString("Bella", comment: "")
            )
            .padding()
            .background(AppColors.secondaryBackground) // TODO: Define AppColors.secondaryBackground if not existing
            .cornerRadius(AppRadius.medium) // TODO: Define AppRadius.medium if not existing

            AccessibilityHelper.row(
                HStack {
                    Image(systemName: "phone.fill")
                    Text(LocalizedStringKey("Call Owner"))
                }, label: NSLocalizedString("Call Owner Button", comment: ""), hint: NSLocalizedString("Double-tap to call", comment: "")
            )
            .padding()
            .background(AppColors.secondaryBackground) // TODO: Define AppColors.secondaryBackground if not existing
            .cornerRadius(AppRadius.medium) // TODO: Define AppRadius.medium if not existing
        }
        .padding()
        .background(AppColors.background) // TODO: Define AppColors.background if not existing
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
        AccessibilityHelper_Preview()
            .preferredColorScheme(.dark)
        AccessibilityHelper_Preview_LargeText()
            .preferredColorScheme(.light)
        AccessibilityHelper_Preview_LargeText()
            .preferredColorScheme(.dark)
    }
}
#endif

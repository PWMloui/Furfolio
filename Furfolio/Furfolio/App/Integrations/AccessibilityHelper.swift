//
//  AccessibilityHelper.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced: token-fallback, auditable, preview-safe, and extensible.
//

import Foundation
import SwiftUI

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

    static func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
        logEvent("announce", extra: message)
    }

    static func announceLocalized(key: String) {
        let message = NSLocalizedString(key, comment: "")
        announce(message)
        logEvent("announceLocalized", extra: message)
    }

    @ViewBuilder
    static func row<V: View>(_ view: V, label: String, hint: String? = nil) -> some View {
        view
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
    }

    @ViewBuilder
    static func button<V: View>(_ view: V, label: String, hint: String? = nil) -> some View {
        view
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map(Text.init) ?? Text(""))
            .accessibilityAddTraits(.isButton)
    }

    static func logEvent(_ event: String, extra: String? = nil) {
        #if DEBUG
        print("[Accessibility] \(event): \(extra ?? "-")")
        #else
        // Replace with your audit/event logger
        AuditLogger.shared.log(category: .accessibility, event: event, metadata: ["extra": extra ?? ""])
        #endif
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

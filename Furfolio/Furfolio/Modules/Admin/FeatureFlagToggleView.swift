//
//  FeatureFlagToggleView.swift
//  Furfolio
//
//  ENHANCED: Tokenized, Modular, Auditable Feature Flag Toggle UI (2025)
//

import SwiftUI

// MARK: - FeatureFlagToggle Audit/Event Logging

fileprivate struct FeatureFlagToggleAuditEvent: Codable {
    let timestamp: Date
    let flag: String
    let enabled: Bool
    let tags: [String]
    let actor: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "FeatureFlagToggle \(flag) \(enabled ? "ON" : "OFF") [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class FeatureFlagToggleAudit {
    static private(set) var log: [FeatureFlagToggleAuditEvent] = []

    static func record(
        flag: String,
        enabled: Bool,
        tags: [String],
        actor: String? = nil,
        context: String? = nil
    ) {
        let event = FeatureFlagToggleAuditEvent(
            timestamp: Date(),
            flag: flag,
            enabled: enabled,
            tags: tags,
            actor: actor,
            context: context
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No feature flag toggle events recorded."
    }
}

// MARK: - FeatureFlagToggleView (Tokenized, Modular, Auditable Feature Flag Toggle UI)

struct FeatureFlagToggleView: View {
    /// The specific flag this view controls.
    let flag: FeatureFlagManager.Flag

    /// The shared manager that holds the state for all flags.
    @ObservedObject var manager: FeatureFlagManager

    /// For enterprise auditability, optionally pass actor/context
    var actor: String? = nil
    var context: String? = "FeatureFlagToggleView"

    var body: some View {
        Toggle(isOn: Binding(
            get: { manager.isEnabled(flag) },
            set: { isEnabled in
                manager.set(flag, enabled: isEnabled)
                FeatureFlagToggleAudit.record(
                    flag: flag.rawValue,
                    enabled: isEnabled,
                    tags: ["featureFlag", flag.rawValue, isEnabled ? "enabled" : "disabled"],
                    actor: actor,
                    context: context
                )
            }
        )) {
            // Use the StringUtils helper to make the flag name more readable
            Text(StringUtils.humanize(flag.rawValue))
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
        .padding(.vertical, AppSpacing.small)
        .accessibilityIdentifier("featureFlagToggle_\(flag.rawValue)")
    }
}

// MARK: - Audit/Admin Accessors

public enum FeatureFlagToggleAuditAdmin {
    public static var lastSummary: String { FeatureFlagToggleAudit.accessibilitySummary }
    public static var lastJSON: String? { FeatureFlagToggleAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        FeatureFlagToggleAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct FeatureFlagToggleView_Previews: PreviewProvider {

    struct PreviewWrapper: View {
        @StateObject private var featureManager = FeatureFlagManager.shared

        var body: some View {
            Form {
                Section(LocalizedStringKey("Available Features")) {
                    ForEach(FeatureFlagManager.Flag.allCases) { flag in
                        FeatureFlagToggleView(flag: flag, manager: featureManager, actor: "preview")
                    }
                }
            }
            .navigationTitle("Feature Flags")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if let summary = FeatureFlagToggleAuditAdmin.lastJSON {
                        Button {
                            UIPasteboard.general.string = summary
                        } label: {
                            Label("Copy Last Audit JSON", systemImage: "doc.on.doc")
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    static var previews: some View {
        NavigationStack {
            PreviewWrapper()
        }
    }
}
#endif

//
//  FeatureFlagToggleView.swift
//  Furfolio
//
//  ENHANCED: Role/permission-aware, audit-staff-context, business-compliant toggle UI (2025)
//

import SwiftUI

// MARK: - FeatureFlagToggle Audit/Event Logging (Updated)

fileprivate struct FeatureFlagToggleAuditEvent: Codable {
    let timestamp: Date
    let flag: String
    let enabled: Bool
    let tags: [String]
    let actor: String?
    let role: String?
    let staffID: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(role ?? "User") toggled \(flag) \(enabled ? "ON" : "OFF") [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class FeatureFlagToggleAudit {
    static private(set) var log: [FeatureFlagToggleAuditEvent] = []
    private static let logQueue = DispatchQueue(label: "FeatureFlagToggleAuditQueue")

    static func record(
        flag: String,
        enabled: Bool,
        tags: [String],
        actor: String? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil
    ) async {
        await withCheckedContinuation { continuation in
            logQueue.async {
                let event = FeatureFlagToggleAuditEvent(
                    timestamp: Date(),
                    flag: flag,
                    enabled: enabled,
                    tags: tags,
                    actor: actor,
                    role: role,
                    staffID: staffID,
                    context: context
                )
                log.append(event)
                if log.count > 500 { log.removeFirst() }
                continuation.resume()
            }
        }
    }
    static func recordSync(
        flag: String,
        enabled: Bool,
        tags: [String],
        actor: String? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil
    ) {
        Task {
            await record(flag: flag, enabled: enabled, tags: tags, actor: actor, role: role, staffID: staffID, context: context)
        }
    }
    static func exportLastJSON() -> String? {
        logQueue.sync {
            guard let last = log.last else { return nil }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }
    static var accessibilitySummary: String {
        logQueue.sync {
            log.last?.accessibilityLabel ?? NSLocalizedString("No feature flag toggle events recorded.", comment: "")
        }
    }
}

// MARK: - FeatureFlagToggleView (Enterprise-Ready, Role-Aware)

struct FeatureFlagToggleView: View {
    let flag: FeatureFlagManager.Flag
    @ObservedObject var manager: FeatureFlagManager

    // New: Optional role/staff context for audit, analytics, and permission checks.
    var currentRole: FurfolioRole? = nil
    var staffID: String? = nil
    var actor: String? = nil
    var context: String? = "FeatureFlagToggleView"
    var testMode: Bool = false

    /// Optional closure for permission (default: always true). Can inject AccessControl logic here.
    var permissionChecker: ((FeatureFlagManager.Flag, FurfolioRole?) -> Bool)? = nil

    /// Optional closure for analytics events (flag, newState, role, staffID)
    var analyticsEvent: ((String, Bool, FurfolioRole?, String?) -> Void)? = nil

    // Accessibility label is now role-aware
    private var accessibilityLabel: String {
        let stateStr = manager.isEnabled(flag)
            ? NSLocalizedString("Enabled", comment: "")
            : NSLocalizedString("Disabled", comment: "")
        let roleStr = currentRole?.rawValue.capitalized ?? NSLocalizedString("User", comment: "")
        return NSLocalizedString("Feature flag %@ is %@ (%@)", comment: "accessibilityLabel")
            .replacingOccurrences(of: "%@", with: StringUtils.humanize(flag.rawValue))
            + ", \(stateStr), \(roleStr)"
    }
    private var accessibilityHint: String {
        NSLocalizedString("Double tap to toggle %@.", comment: "accessibilityHint")
            .replacingOccurrences(of: "%@", with: StringUtils.humanize(flag.rawValue))
    }

    var body: some View {
        let canToggle = permissionChecker?(flag, currentRole) ?? true

        Toggle(isOn: Binding(
            get: { manager.isEnabled(flag) },
            set: { isEnabled in
                guard canToggle else { return }
                if testMode {
                    print("TestMode: \(currentRole?.rawValue ?? "User") tried toggling '\(flag.rawValue)' to \(isEnabled ? "enabled" : "disabled")")
                } else {
                    manager.set(flag, enabled: isEnabled)
                    Task {
                        await FeatureFlagToggleAudit.record(
                            flag: flag.rawValue,
                            enabled: isEnabled,
                            tags: ["featureFlag", flag.rawValue, isEnabled ? "enabled" : "disabled", currentRole?.rawValue ?? "unknown"],
                            actor: actor,
                            role: currentRole?.rawValue,
                            staffID: staffID,
                            context: context
                        )
                    }
                }
                analyticsEvent?(flag.rawValue, isEnabled, currentRole, staffID)
            }
        )) {
            Text(StringUtils.humanize(flag.rawValue))
                .font(AppFonts.body)
                .foregroundColor(canToggle ? AppColors.textPrimary : .gray)
        }
        .toggleStyle(SwitchToggleStyle(tint: canToggle ? AppColors.primary : .gray))
        .padding(.vertical, AppSpacing.small)
        .accessibilityIdentifier("featureFlagToggle_\(flag.rawValue)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .disabled(!canToggle)
        .overlay(
            Group {
                if testMode {
                    Text(NSLocalizedString("Test Mode: No changes or logs", comment: "TestModeBanner"))
                        .font(.caption2).foregroundColor(.orange)
                        .padding(4).background(Color.yellow.opacity(0.1))
                        .cornerRadius(6).offset(y: -28)
                } else if !canToggle {
                    Text(NSLocalizedString("Insufficient permission", comment: "NoPermBanner"))
                        .font(.caption2).foregroundColor(.red)
                        .padding(4).background(Color.red.opacity(0.1))
                        .cornerRadius(6).offset(y: -28)
                }
            }
        )
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

// MARK: - Preview (Enhanced for Role/Permission Testing)

#if DEBUG
struct FeatureFlagToggleView_Previews: PreviewProvider {

    struct PreviewWrapper: View {
        @StateObject private var featureManager = FeatureFlagManager.shared
        @State private var testModeEnabled: Bool = false
        @State private var currentRole: FurfolioRole = .owner
        @State private var lastAnalyticsEvent: String = "None"
        private let allRoles: [FurfolioRole] = [.owner, .receptionist, .groomer, .admin, .guest]

        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        Toggle("Enable Test Mode", isOn: $testModeEnabled)
                        Picker("Role", selection: $currentRole) {
                            ForEach(allRoles, id: \.self) { role in
                                Text(role.rawValue.capitalized)
                            }
                        }
                    }
                    Section(LocalizedStringKey("Available Features")) {
                        ForEach(FeatureFlagManager.Flag.allCases) { flag in
                            FeatureFlagToggleView(
                                flag: flag,
                                manager: featureManager,
                                currentRole: currentRole,
                                staffID: "preview-staff",
                                actor: "preview",
                                testMode: testModeEnabled,
                                permissionChecker: { flag, role in
                                    // Example: Only owner/admin can toggle "experimental" flags
                                    if flag.rawValue.contains("experimental") {
                                        return role == .owner || role == .admin
                                    }
                                    return true
                                },
                                analyticsEvent: { flagName, enabled, role, staffID in
                                    lastAnalyticsEvent = "\(role?.rawValue ?? "User") set \(flagName) to \(enabled ? "enabled" : "disabled")"
                                }
                            )
                        }
                    }
                    Section("Audit Log Summary") {
                        Text(FeatureFlagToggleAuditAdmin.lastSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Last Analytics Event") {
                        Text(lastAnalyticsEvent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section {
                        if let json = FeatureFlagToggleAuditAdmin.lastJSON {
                            Text("Last Audit JSON:").font(.headline)
                            ScrollView(.horizontal) {
                                Text(json)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(4)
                            }
                        } else {
                            Text("No audit events recorded yet.").font(.caption)
                        }
                    }
                }
                .navigationTitle("Feature Flags")
            }
        }
    }
    static var previews: some View { PreviewWrapper() }
}
#endif

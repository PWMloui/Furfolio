//
//  ConfirmActionSheet.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–ready, token-compliant, accessible, preview/test–injectable.
//
//
//  ConfirmActionSheet.swift
//  Furfolio
//
//  ARCHITECTURE & MAINTAINER NOTES:
//
//  ConfirmActionSheet.swift provides a reusable, modular, and compliance-ready confirmation dialog for SwiftUI views,
//  supporting analytics/audit logging, Trust Center hooks, token-based styling, accessibility, localization, and diagnostics.
//
//  - Extensibility: Built as a SwiftUI ViewModifier, easily attached to any View via .confirmActionSheet. All UI tokens (fonts, colors, spacing) are injected for design system compliance.
//  - Analytics/Audit/Trust Center: Analytics logging is abstracted via ConfirmActionSheetAnalyticsLogger, supporting async/await, test/preview injection, and Trust Center audit tagging. A capped buffer of the last 20 events is available for diagnostics and admin review.
//  - Diagnostics: Recent analytics events (last 20) are retrievable via ConfirmActionSheet.recentEvents, aiding admin/QA/test/debug.
//  - Localization: All user-facing and analytics log strings are localized via NSLocalizedString with descriptive keys and comments.
//  - Accessibility: All dialogs and controls have accessibility labels and hints, with .isModal traits for assistive tech compliance.
//  - Compliance: Supports auditTag for Trust Center/compliance, and can be extended for additional compliance hooks.
//  - Preview/Testability: Supports testMode for console-only logging, Null logger for previews/tests, and exposes diagnostics buffer in previews.
//
//  For future maintainers:
//  - Update/add localization keys in Localizable.strings as needed.
//  - To inject custom analytics, assign ConfirmActionSheet.analyticsLogger.
//  - For new compliance/audit hooks, extend ConfirmActionSheetAnalyticsLogger protocol.
//  - To review/diagnose recent analytics events, call ConfirmActionSheet.recentEvents.
//
//  See ConfirmActionSheet_Previews for testMode, accessibility, and diagnostics demonstration.
//

import SwiftUI
import UIKit

// MARK: - Audit Context (set at login/session)
public struct ConfirmActionSheetAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ConfirmActionSheet"
}

// MARK: - Analytics/Audit Protocol (Async/Await, Diagnostics Buffer, TestMode)

/// Protocol for analytics/audit logging of ConfirmActionSheet events.
/// Supports async/await for future extensibility (e.g., network logging).
public protocol ConfirmActionSheetAnalyticsLogger {
    /// If true, only logs to console (no network/file output). For QA/tests/previews.
    var testMode: Bool { get }
    /// Asynchronously log an event with all audit fields.
    func logEvent(
        _ event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null logger for previews/tests. No-ops all analytics calls except prints in testMode.
public struct NullConfirmActionSheetAnalyticsLogger: ConfirmActionSheetAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func logEvent(
        _ event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[TESTMODE][NullConfirmActionSheetAnalyticsLogger] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
}

/// Default async/await analytics logger with diagnostics buffer and testMode.
public actor DefaultConfirmActionSheetAnalyticsLogger: ConfirmActionSheetAnalyticsLogger {
    public var testMode: Bool
    private(set) var eventBuffer: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
    private let bufferLimit = 20

    public init(testMode: Bool = false) {
        self.testMode = testMode
    }

    /// Asynchronously logs an event, optionally only to console if testMode is true.
    public func logEvent(
        _ event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let timestamp = Date()
        if testMode {
            print("[TESTMODE][DefaultConfirmActionSheetAnalyticsLogger] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        } else {
            // Replace with real analytics endpoint as needed.
            print("[ConfirmActionSheet] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
        // Maintain capped diagnostics buffer.
        eventBuffer.append((timestamp, event, info, role, staffID, context, escalate))
        if eventBuffer.count > bufferLimit {
            eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
        }
    }

    /// Returns a snapshot of recent analytics events for diagnostics/admin.
    public func recentEvents() -> [(Date, String, [String: Any]?, String?, String?, String?, Bool)] {
        return eventBuffer
    }
}

// MARK: - ConfirmActionSheet (Reusable Confirmation Dialog, Modular Token Styling, Audit-Ready)

struct ConfirmActionSheet: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let confirmRole: ButtonRole
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?
    let hapticFeedback: Bool
    let auditTag: String?   // For Trust Center, compliance, or advanced audit.

    /// Injected analytics logger (preview/test-injectable, async/await).
    static var analyticsLogger: ConfirmActionSheetAnalyticsLogger = NullConfirmActionSheetAnalyticsLogger()

    /// Diagnostics buffer (last 20 events) for admin/diagnostics.
    static var recentEvents: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] {
        get async {
            if let logger = analyticsLogger as? DefaultConfirmActionSheetAnalyticsLogger {
                return await logger.recentEvents()
            }
            return []
        }
    }

    private enum Defaults {
        static let defaultConfirmTitle = NSLocalizedString("confirm_action_delete", value: "Delete", comment: "Default confirm button title for destructive actions")
        static let defaultCancelTitle = NSLocalizedString("confirm_action_cancel", value: "Cancel", comment: "Default cancel button title")
    }

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .alert(
                NSLocalizedString("confirm_action_title_\(title)", value: title, comment: "Confirmation dialog title"),
                isPresented: $isPresented,
                presenting: nil,
                actions: {
                    Button(NSLocalizedString("confirm_action_confirm_button_\(confirmTitle)", value: confirmTitle, comment: "Confirm button label")) {
                        Task { await performConfirm() }
                    }
                    .font(AppFonts.button)
                    .foregroundColor(AppColors.accent)
                    .accessibilityLabel(Text(NSLocalizedString("confirm_action_confirm_button_\(confirmTitle)", value: confirmTitle, comment: "Confirm button accessibility label")))
                    .accessibilityHint(confirmRole == .destructive ?
                        Text(NSLocalizedString("confirm_action_confirm_hint_destructive", value: "Deletes the item. This action cannot be undone.", comment: "Accessibility hint for destructive confirm")) :
                        Text(NSLocalizedString("confirm_action_confirm_hint_generic", value: "Confirms the action.", comment: "Accessibility hint for confirm")))
                    Button(NSLocalizedString("confirm_action_cancel_button_\(cancelTitle)", value: cancelTitle, comment: "Cancel button label")) {
                        Task { await performCancel() }
                    }
                    .font(AppFonts.button)
                    .foregroundColor(AppColors.accent)
                    .accessibilityLabel(Text(NSLocalizedString("confirm_action_cancel_button_\(cancelTitle)", value: cancelTitle, comment: "Cancel button accessibility label")))
                    .accessibilityHint(Text(NSLocalizedString("confirm_action_cancel_hint", value: "Cancels and closes the dialog.", comment: "Accessibility hint for cancel")))
                },
                message: {
                    if let message {
                        Text(NSLocalizedString("confirm_action_message_\(message)", value: message, comment: "Confirmation dialog message"))
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                            .accessibilityLabel(Text(NSLocalizedString("confirm_action_message_\(message)", value: message, comment: "Confirmation dialog message accessibility label")))
                    }
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        #else
        content
            .confirmationDialog(
                NSLocalizedString("confirm_action_title_\(title)", value: title, comment: "Confirmation dialog title"),
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("confirm_action_confirm_button_\(confirmTitle)", value: confirmTitle, comment: "Confirm button label"), role: confirmRole) {
                    Task { await performConfirm() }
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .accessibilityLabel(Text(NSLocalizedString("confirm_action_confirm_button_\(confirmTitle)", value: confirmTitle, comment: "Confirm button accessibility label")))
                .accessibilityHint(confirmRole == .destructive ?
                    Text(NSLocalizedString("confirm_action_confirm_hint_destructive", value: "Deletes the item. This action cannot be undone.", comment: "Accessibility hint for destructive confirm")) :
                    Text(NSLocalizedString("confirm_action_confirm_hint_generic", value: "Confirms the action.", comment: "Accessibility hint for confirm")))
                Button(NSLocalizedString("confirm_action_cancel_button_\(cancelTitle)", value: cancelTitle, comment: "Cancel button label"), role: .cancel) {
                    Task { await performCancel() }
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .accessibilityLabel(Text(NSLocalizedString("confirm_action_cancel_button_\(cancelTitle)", value: cancelTitle, comment: "Cancel button accessibility label")))
                .accessibilityHint(Text(NSLocalizedString("confirm_action_cancel_hint", value: "Cancels and closes the dialog.", comment: "Accessibility hint for cancel")))
            } message: {
                if let message {
                    Text(NSLocalizedString("confirm_action_message_\(message)", value: message, comment: "Confirmation dialog message"))
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                        .accessibilityLabel(Text(NSLocalizedString("confirm_action_message_\(message)", value: message, comment: "Confirmation dialog message accessibility label")))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        #endif
    }
    
    /// Handles confirm button tap: triggers haptics, logs analytics, and calls onConfirm closure.
    private func performConfirm() async {
        if hapticFeedback {
            triggerHapticFeedback()
        }
        let event = NSLocalizedString("confirm_action_event_confirm_tapped", value: "confirm_tapped", comment: "Analytics event: confirm tapped")
        let info: [String: Any] = [
            NSLocalizedString("confirm_action_log_title", value: "title", comment: "Analytics info key: title"): title,
            NSLocalizedString("confirm_action_log_role", value: "role", comment: "Analytics info key: role"): String(describing: confirmRole),
            NSLocalizedString("confirm_action_log_audittag", value: "auditTag", comment: "Analytics info key: auditTag"): auditTag as Any
        ]
        let lowerEvent = event.lowercased()
        let auditTagString = auditTag?.lowercased() ?? ""
        let escalate = lowerEvent.contains("danger") || lowerEvent.contains("critical") || lowerEvent.contains("delete") ||
            auditTagString.contains("danger") || auditTagString.contains("critical") || auditTagString.contains("delete")
        await ConfirmActionSheet.analyticsLogger.logEvent(
            event,
            info: info,
            role: ConfirmActionSheetAuditContext.role,
            staffID: ConfirmActionSheetAuditContext.staffID,
            context: ConfirmActionSheetAuditContext.context,
            escalate: escalate
        )
        onConfirm()
    }

    /// Handles cancel button tap: logs analytics and calls onCancel closure.
    private func performCancel() async {
        let event = NSLocalizedString("confirm_action_event_cancel_tapped", value: "cancel_tapped", comment: "Analytics event: cancel tapped")
        let info: [String: Any] = [
            NSLocalizedString("confirm_action_log_title", value: "title", comment: "Analytics info key: title"): title,
            NSLocalizedString("confirm_action_log_role", value: "role", comment: "Analytics info key: role"): String(describing: confirmRole),
            NSLocalizedString("confirm_action_log_audittag", value: "auditTag", comment: "Analytics info key: auditTag"): auditTag as Any
        ]
        let lowerEvent = event.lowercased()
        let auditTagString = auditTag?.lowercased() ?? ""
        let escalate = lowerEvent.contains("danger") || lowerEvent.contains("critical") || lowerEvent.contains("delete") ||
            auditTagString.contains("danger") || auditTagString.contains("critical") || auditTagString.contains("delete")
        await ConfirmActionSheet.analyticsLogger.logEvent(
            event,
            info: info,
            role: ConfirmActionSheetAuditContext.role,
            staffID: ConfirmActionSheetAuditContext.staffID,
            context: ConfirmActionSheetAuditContext.context,
            escalate: escalate
        )
        onCancel?()
    }
    
    /// Triggers haptic feedback for confirm action.
    private func triggerHapticFeedback() {
        #if os(iOS) || os(tvOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

// MARK: - View Extension for Attaching the ConfirmActionSheet

extension View {
    /// Attaches a reusable confirmation dialog to this view.
    /// - Parameters:
    ///   - isPresented: Binding to control the presentation of the dialog.
    ///   - title: The title text of the confirmation dialog.
    ///   - message: Optional descriptive message providing more context.
    ///   - confirmTitle: Title for the confirm button. Defaults to "Delete".
    ///   - confirmRole: Role of the confirm button (e.g. destructive, cancel). Defaults to `.destructive`.
    ///   - cancelTitle: Title for the cancel button. Defaults to "Cancel".
    ///   - hapticFeedback: Whether to trigger haptic feedback on confirm action. Defaults to false.
    ///   - auditTag: Optional tag for Trust Center/compliance logging.
    ///   - onConfirm: Closure executed when the confirm button is tapped.
    ///   - onCancel: Optional closure executed when the cancel button is tapped.
    func confirmActionSheet(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = ConfirmActionSheet.Defaults.defaultConfirmTitle,
        confirmRole: ButtonRole = .destructive,
        cancelTitle: String = ConfirmActionSheet.Defaults.defaultCancelTitle,
        hapticFeedback: Bool = false,
        auditTag: String? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            ConfirmActionSheet(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                cancelTitle: cancelTitle,
                onConfirm: onConfirm,
                onCancel: onCancel,
                hapticFeedback: hapticFeedback,
                auditTag: auditTag
            )
        )
    }
}

// MARK: - Example Usage Preview with Analytics/Audit Logging, Diagnostics, Accessibility, TestMode

struct ConfirmActionSheet_Previews: PreviewProvider {
    /// Test logger for preview, showing diagnostics buffer and testMode.
    actor PreviewLogger: ConfirmActionSheetAnalyticsLogger {
        var testMode: Bool = true
        private(set) var eventBuffer: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
        let bufferLimit = 20
        func logEvent(
            _ event: String,
            info: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            print("[PREVIEW TESTMODE] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
            eventBuffer.append((Date(), event, info, role, staffID, context, escalate))
            if eventBuffer.count > bufferLimit {
                eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
            }
        }
        func recentEvents() -> [(Date, String, [String: Any]?, String?, String?, String?, Bool)] {
            return eventBuffer
        }
    }

    struct DiagnosticsView: View {
        @State private var events: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []
        let fetchEvents: () async -> [(Date, String, [String: Any]?, String?, String?, String?, Bool)]
        var body: some View {
            VStack(alignment: .leading) {
                Text(NSLocalizedString("confirm_action_diagnostics_title", value: "Recent Analytics Events", comment: "Diagnostics recent events title"))
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                Button(NSLocalizedString("confirm_action_diagnostics_refresh", value: "Refresh", comment: "Diagnostics refresh button")) {
                    Task { events = await fetchEvents() }
                }
                .font(AppFonts.caption)
                .foregroundColor(AppColors.accent)
                ScrollView {
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.0.formatted(date: .abbreviated, time: .standard)) — \(entry.1)")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Group {
                                if let info = entry.2 {
                                    Text("info: \(String(describing: info))")
                                        .font(AppFonts.caption2)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Text("role: \(entry.3 ?? "nil")")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("staffID: \(entry.4 ?? "nil")")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("context: \(entry.5 ?? "nil")")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("escalate: \(entry.6 ? "true" : "false")")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.bottom, 2)
                    }
                }
                .frame(maxHeight: 180)
            }
            .onAppear {
                Task { events = await fetchEvents() }
            }
        }
    }

    struct Demo: View {
        @State private var showDestructiveSheet = false
        @State private var showNonDestructiveSheet = false
        @State private var lastAction = NSLocalizedString("confirm_action_none", value: "None", comment: "No action taken yet")
        @State private var testMode: Bool = true
        @State private var diagnostics: [(Date, String, [String: Any]?, String?, String?, String?, Bool)] = []

        var body: some View {
            VStack(spacing: AppSpacing.large) {
                Text(NSLocalizedString("confirm_action_last_action", value: "Last Action: ", comment: "Last action prefix") + lastAction)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityLabel(Text(NSLocalizedString("confirm_action_last_action_accessibility", value: "Last Action: \(lastAction)", comment: "Accessibility: last action")))

                Button(NSLocalizedString("confirm_action_delete_item", value: "Delete Item", comment: "Delete item button")) {
                    showDestructiveSheet = true
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .confirmActionSheet(
                    isPresented: $showDestructiveSheet,
                    title: NSLocalizedString("confirm_action_are_you_sure", value: "Are you sure?", comment: "Destructive dialog title"),
                    message: NSLocalizedString("confirm_action_cannot_be_undone", value: "This action cannot be undone.", comment: "Destructive dialog message"),
                    confirmTitle: NSLocalizedString("confirm_action_delete", value: "Delete", comment: "Delete confirm button"),
                    confirmRole: .destructive,
                    cancelTitle: NSLocalizedString("confirm_action_cancel", value: "Cancel", comment: "Cancel button"),
                    hapticFeedback: true,
                    auditTag: "delete_item",
                    onConfirm: {
                        lastAction = NSLocalizedString("confirm_action_deleted", value: "Deleted", comment: "Deleted state")
                    },
                    onCancel: {
                        lastAction = NSLocalizedString("confirm_action_delete_cancelled", value: "Delete Cancelled", comment: "Delete cancelled state")
                    }
                )
                .accessibilityLabel(Text(NSLocalizedString("confirm_action_delete_item", value: "Delete Item", comment: "Delete item accessibility label")))

                Button(NSLocalizedString("confirm_action_archive_item", value: "Archive Item", comment: "Archive item button")) {
                    showNonDestructiveSheet = true
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .confirmActionSheet(
                    isPresented: $showNonDestructiveSheet,
                    title: NSLocalizedString("confirm_action_archive_title", value: "Archive this item?", comment: "Archive dialog title"),
                    message: NSLocalizedString("confirm_action_restore_later", value: "You can restore it later from archives.", comment: "Archive dialog message"),
                    confirmTitle: NSLocalizedString("confirm_action_archive", value: "Archive", comment: "Archive confirm button"),
                    confirmRole: .none,
                    cancelTitle: NSLocalizedString("confirm_action_dismiss", value: "Dismiss", comment: "Dismiss button"),
                    hapticFeedback: false,
                    auditTag: "archive_item",
                    onConfirm: {
                        lastAction = NSLocalizedString("confirm_action_archived", value: "Archived", comment: "Archived state")
                    },
                    onCancel: {
                        lastAction = NSLocalizedString("confirm_action_archive_cancelled", value: "Archive Cancelled", comment: "Archive cancelled state")
                    }
                )
                .accessibilityLabel(Text(NSLocalizedString("confirm_action_archive_item", value: "Archive Item", comment: "Archive item accessibility label")))

                Toggle(NSLocalizedString("confirm_action_testmode_toggle", value: "TestMode (console only)", comment: "Test mode toggle"), isOn: $testMode)
                    .onChange(of: testMode) { newValue in
                        if let logger = ConfirmActionSheet.analyticsLogger as? DefaultConfirmActionSheetAnalyticsLogger {
                            logger.testMode = newValue
                        }
                    }
                    .padding(.top, AppSpacing.medium)

                DiagnosticsView(fetchEvents: {
                    await ConfirmActionSheet.recentEvents
                })
            }
            .padding(AppSpacing.medium)
        }
    }

    static var previews: some View {
        let logger = DefaultConfirmActionSheetAnalyticsLogger(testMode: true)
        ConfirmActionSheet.analyticsLogger = logger
        return Group {
            Demo()
                .previewDisplayName("iOS / iPadOS")
                .previewDevice("iPhone 14")
            Demo()
                .previewDisplayName("macOS")
                .previewLayout(.sizeThatFits)
        }
    }
}

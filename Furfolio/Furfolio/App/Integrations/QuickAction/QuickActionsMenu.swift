//
//  QuickActionsMenu.swift
//  Furfolio
//
//  Enhanced 2025: analytics/audit–ready, Trust Center–capable, preview/test–injectable, robust accessibility, denial feedback, badge support, staff-role aware.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol QuickActionsMenuAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullQuickActionsMenuAnalyticsLogger: QuickActionsMenuAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol QuickActionsMenuTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
    func denialMessage(for action: String, context: [String: Any]?) -> String?
    func currentUserRole() -> String
}
public extension QuickActionsMenuTrustCenterDelegate {
    func denialMessage(for action: String, context: [String: Any]?) -> String? { nil }
    func currentUserRole() -> String { "Unknown" }
}
public struct NullQuickActionsMenuTrustCenterDelegate: QuickActionsMenuTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
    public func currentUserRole() -> String { "Unknown" }
}

// MARK: - QuickActionsMenu (Enterprise Enhanced)

public struct QuickActionsMenu: View {
    public let phone: String?
    public let onCall: (() -> Void)?
    public let onMessage: (() -> Void)?
    public let onAddAppointment: (() -> Void)?
    public let onAddNote: (() -> Void)?
    public let onEdit: (() -> Void)?
    public let onDelete: (() -> Void)?
    
    /// Custom actions may provide an optional badge and minimumRole/isEnabled for permission.
    public var customActions: [(label: String, systemImage: String, color: Color, badge: String?, minRole: String?, isEnabled: Bool, action: () -> Void)] = []
    public var asMenu: Bool = false
    public var helperText: String?
    public var showDivider: Bool = false

    @State private var deniedMessage: String?

    public static var analyticsLogger: QuickActionsMenuAnalyticsLogger = NullQuickActionsMenuAnalyticsLogger()
    public static var trustCenterDelegate: QuickActionsMenuTrustCenterDelegate = NullQuickActionsMenuTrustCenterDelegate()

    public init(
        phone: String? = nil,
        onCall: (() -> Void)? = nil,
        onMessage: (() -> Void)? = nil,
        onAddAppointment: (() -> Void)? = nil,
        onAddNote: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        customActions: [(label: String, systemImage: String, color: Color, badge: String?, minRole: String?, isEnabled: Bool, action: () -> Void)] = [],
        asMenu: Bool = false,
        helperText: String? = nil,
        showDivider: Bool = false
    ) {
        self.phone = phone
        self.onCall = onCall
        self.onMessage = onMessage
        self.onAddAppointment = onAddAppointment
        self.onAddNote = onAddNote
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.customActions = customActions
        self.asMenu = asMenu
        self.helperText = helperText
        self.showDivider = showDivider
    }

    public var body: some View {
        VStack(spacing: AppSpacing.xxSmall) {
            if asMenu {
                Menu {
                    standardMenuActions()
                    ForEach(Array(customActions.enumerated()), id: \.offset) { _, action in
                        let enabled = isCustomActionAllowed(action)
                        Button {
                            actionHandler("custom", ["label": action.label], action.action, isEnabled: enabled)
                        } label: {
                            HStack {
                                Label(action.label, systemImage: action.systemImage)
                                    .font(AppFonts.body)
                                    .foregroundColor(enabled ? action.color : AppColors.disabled)
                                if let badge = action.badge {
                                    BadgeView(text: badge)
                                }
                            }
                        }
                        .disabled(!enabled)
                        .accessibilityLabel(action.label)
                        .accessibilityHint(enabled ? "Performs the \(action.label) action" : "Not permitted for your role")
                    }
                } label: {
                    Label("Quick Actions", systemImage: "ellipsis.circle")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                        .accessibilityLabel("Quick Actions menu")
                        .accessibilityHint("Tap to show quick action options")
                }
                if let helperText = helperText {
                    Text(helperText)
                        .font(AppFonts.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityHint("Helper information: \(helperText)")
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xxSmall)
                        .dynamicTypeSize(.medium ... .xxxLarge)
                }
            } else {
                HStack(spacing: AppSpacing.large) {
                    standardActionButtons()
                    ForEach(Array(customActions.enumerated()), id: \.offset) { _, action in
                        let enabled = isCustomActionAllowed(action)
                        ActionButton(
                            label: action.label,
                            systemImage: action.systemImage,
                            color: enabled ? action.color : AppColors.disabled,
                            badge: action.badge,
                            action: {
                                actionHandler("custom", ["label": action.label], action.action, isEnabled: enabled)
                            },
                            isDestructive: false,
                            isEnabled: enabled
                        )
                        .accessibilityLabel(action.label)
                        .accessibilityHint(enabled ? "Performs the \(action.label) action" : "Not permitted for your role")
                        .disabled(!enabled)
                    }
                }
                .padding(.vertical, AppSpacing.medium)
                if let helperText = helperText {
                    Text(helperText)
                        .font(AppFonts.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityHint("Helper information: \(helperText)")
                        .multilineTextAlignment(.center)
                        .padding(.top, AppSpacing.xxSmall)
                        .dynamicTypeSize(.medium ... .xxxLarge)
                }
                if showDivider {
                    Divider()
                }
            }
        }
        .keyboardShortcut(.defaultAction)
        .alert(isPresented: .constant(deniedMessage != nil), content: {
            Alert(title: Text("Action Not Allowed"), message: Text(deniedMessage ?? "You do not have permission for this action."), dismissButton: .default(Text("OK")) {
                deniedMessage = nil
            })
        })
    }

    // MARK: - Standard Actions as Menu
    @ViewBuilder
    private func standardMenuActions() -> some View {
        if let onCall = onCall, let phone = phone {
            let allowed = Self.trustCenterDelegate.permission(for: "call", context: ["phone": phone, "role": Self.trustCenterDelegate.currentUserRole()])
            Button {
                actionHandler("call", ["phone": phone], onCall, isEnabled: allowed)
            } label: {
                Label("Call \(phone)", systemImage: "phone.fill")
            }
            .disabled(!allowed)
            .accessibilityLabel("Call \(phone)")
            .accessibilityHint(allowed ? "Initiates a phone call to \(phone)" : "Not permitted")
        }
        // ...repeat for other actions below, same as above, with role/context...
        if let onMessage = onMessage {
            let allowed = Self.trustCenterDelegate.permission(for: "message", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            Button {
                actionHandler("message", nil, onMessage, isEnabled: allowed)
            } label: {
                Label("Message", systemImage: "message.fill")
            }
            .disabled(!allowed)
            .accessibilityLabel("Message")
            .accessibilityHint(allowed ? "Sends a message" : "Not permitted")
        }
        if let onAddAppointment = onAddAppointment {
            let allowed = Self.trustCenterDelegate.permission(for: "addAppointment", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            Button {
                actionHandler("addAppointment", nil, onAddAppointment, isEnabled: allowed)
            } label: {
                Label("Add Appointment", systemImage: "calendar.badge.plus")
            }
            .disabled(!allowed)
            .accessibilityLabel("Add Appointment")
            .accessibilityHint(allowed ? "Adds a new appointment" : "Not permitted")
        }
        if let onAddNote = onAddNote {
            let allowed = Self.trustCenterDelegate.permission(for: "addNote", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            Button {
                actionHandler("addNote", nil, onAddNote, isEnabled: allowed)
            } label: {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }
            .disabled(!allowed)
            .accessibilityLabel("Add Note")
            .accessibilityHint(allowed ? "Adds a new note" : "Not permitted")
        }
        if let onEdit = onEdit {
            let allowed = Self.trustCenterDelegate.permission(for: "edit", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            Button {
                actionHandler("edit", nil, onEdit, isEnabled: allowed)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(!allowed)
            .accessibilityLabel("Edit")
            .accessibilityHint(allowed ? "Edits the item" : "Not permitted")
        }
        if let onDelete = onDelete {
            let allowed = Self.trustCenterDelegate.permission(for: "delete", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            Button(role: .destructive) {
                actionHandler("delete", nil, onDelete, isEnabled: allowed)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(!allowed)
            .accessibilityLabel("Delete")
            .accessibilityHint(allowed ? "Deletes the item" : "Not permitted")
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(.isDestructive)
        }
    }

    // MARK: - Standard Actions as Buttons
    @ViewBuilder
    private func standardActionButtons() -> some View {
        // Similar to above: check permission for each, then show or gray out
        if let onCall = onCall, let phone = phone {
            let allowed = Self.trustCenterDelegate.permission(for: "call", context: ["phone": phone, "role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Call",
                systemImage: "phone.fill",
                color: allowed ? AppColors.green : AppColors.disabled,
                action: { actionHandler("call", ["phone": phone], onCall, isEnabled: allowed) },
                isDestructive: false,
                isEnabled: allowed
            )
            .accessibilityLabel("Call \(phone)")
            .accessibilityHint(allowed ? "Initiates a phone call to \(phone)" : "Not permitted")
            .disabled(!allowed)
        }
        if let onMessage = onMessage {
            let allowed = Self.trustCenterDelegate.permission(for: "message", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Message",
                systemImage: "message.fill",
                color: allowed ? AppColors.blue : AppColors.disabled,
                action: { actionHandler("message", nil, onMessage, isEnabled: allowed) },
                isDestructive: false,
                isEnabled: allowed
            )
            .accessibilityLabel("Message")
            .accessibilityHint(allowed ? "Sends a message" : "Not permitted")
            .disabled(!allowed)
        }
        if let onAddAppointment = onAddAppointment {
            let allowed = Self.trustCenterDelegate.permission(for: "addAppointment", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Add",
                systemImage: "calendar.badge.plus",
                color: allowed ? AppColors.accent : AppColors.disabled,
                action: { actionHandler("addAppointment", nil, onAddAppointment, isEnabled: allowed) },
                isDestructive: false,
                isEnabled: allowed
            )
            .accessibilityLabel("Add Appointment")
            .accessibilityHint(allowed ? "Adds a new appointment" : "Not permitted")
            .disabled(!allowed)
        }
        if let onAddNote = onAddNote {
            let allowed = Self.trustCenterDelegate.permission(for: "addNote", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Note",
                systemImage: "note.text.badge.plus",
                color: allowed ? AppColors.orange : AppColors.disabled,
                action: { actionHandler("addNote", nil, onAddNote, isEnabled: allowed) },
                isDestructive: false,
                isEnabled: allowed
            )
            .accessibilityLabel("Add Note")
            .accessibilityHint(allowed ? "Adds a new note" : "Not permitted")
            .disabled(!allowed)
        }
        if let onEdit = onEdit {
            let allowed = Self.trustCenterDelegate.permission(for: "edit", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Edit",
                systemImage: "pencil",
                color: allowed ? AppColors.gray : AppColors.disabled,
                action: { actionHandler("edit", nil, onEdit, isEnabled: allowed) },
                isDestructive: false,
                isEnabled: allowed
            )
            .accessibilityLabel("Edit")
            .accessibilityHint(allowed ? "Edits the item" : "Not permitted")
            .disabled(!allowed)
        }
        if let onDelete = onDelete {
            let allowed = Self.trustCenterDelegate.permission(for: "delete", context: ["role": Self.trustCenterDelegate.currentUserRole()])
            ActionButton(
                label: "Delete",
                systemImage: "trash",
                color: allowed ? AppColors.red : AppColors.disabled,
                action: { actionHandler("delete", nil, onDelete, isEnabled: allowed) },
                isDestructive: true,
                isEnabled: allowed
            )
            .accessibilityLabel("Delete")
            .accessibilityHint(allowed ? "Deletes the item" : "Not permitted")
            .disabled(!allowed)
        }
    }

    /// Helper to check custom action is enabled for current user role
    private func isCustomActionAllowed(_ action: (label: String, systemImage: String, color: Color, badge: String?, minRole: String?, isEnabled: Bool, action: () -> Void)) -> Bool {
        guard let minRole = action.minRole else { return action.isEnabled }
        let currentRole = Self.trustCenterDelegate.currentUserRole()
        // You could define your own role hierarchy/logic here (e.g. ["Owner", "Manager", "Receptionist", ...])
        // For now, just check for equality (expand for your actual hierarchy)
        return action.isEnabled && currentRole == minRole
    }

    private func performHaptic(allowed: Bool = true) {
        #if os(iOS)
        if allowed {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        #endif
    }

    /// Handles action trigger, audit, trust center, haptics, and denial feedback.
    private func actionHandler(_ action: String, _ context: [String: Any]? = nil, _ closure: () -> Void, isEnabled: Bool = true) {
        if !isEnabled {
            deniedMessage = "You do not have permission for this action."
            Self.analyticsLogger.log(event: "\(action)_denied", info: context)
            performHaptic(allowed: false)
            return
        }
        let allowed = Self.trustCenterDelegate.permission(for: action, context: context)
        if !allowed {
            let denial = Self.trustCenterDelegate.denialMessage(for: action, context: context)
            deniedMessage = denial ?? "You do not have permission for this action."
            Self.analyticsLogger.log(event: "\(action)_denied", info: context)
            performHaptic(allowed: false)
            return
        }
        performHaptic()
        Self.analyticsLogger.log(event: action, info: context)
        closure()
    }
}

// MARK: - ActionButton/BadgeView updated for enabled/disabled state

private extension QuickActionsMenu {
    struct ActionButton: View {
        let label: String
        let systemImage: String
        let color: Color
        var badge: String? = nil
        let action: () -> Void
        var isDestructive: Bool = false
        var isEnabled: Bool = true

        var body: some View {
            Button(action: isEnabled ? action : {}, label: {
                VStack(spacing: AppSpacing.xSmall) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: systemImage)
                            .font(AppFonts.title)
                            .foregroundColor(color)
                            .frame(minWidth: 44, minHeight: 44)
                        if let badge = badge {
                            BadgeView(text: badge)
                                .offset(x: 12, y: -10)
                        }
                    }
                    Text(label)
                        .font(AppFonts.caption2)
                        .foregroundColor(AppColors.textPrimary)
                        .dynamicTypeSize(.medium ... .xxxLarge)
                }
                .padding(AppSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.card)
                        .appShadow(AppShadows.card)
                )
                .opacity(isEnabled ? 1 : 0.5)
            })
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityAddTraits(isDestructive ? .isDestructive : [])
            .disabled(!isEnabled)
        }
    }

    struct BadgeView: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.red))
                .accessibilityLabel("Badge: \(text)")
        }
    }
}

// MARK: - Previews

#Preview {
    struct SpyLogger: QuickActionsMenuAnalyticsLogger {
        func log(event: String, info: [String: Any]?) {
            print("[QuickActionsMenuAnalytics] \(event): \(info ?? [:])")
        }
    }
    struct SpyTrustCenter: QuickActionsMenuTrustCenterDelegate {
        func permission(for action: String, context: [String : Any]?) -> Bool {
            if action == "delete" { return false }
            return true
        }
        func denialMessage(for action: String, context: [String: Any]?) -> String? {
            if action == "delete" { return "Demo: Deletion is not permitted in preview." }
            return nil
        }
    }

    QuickActionsMenu.analyticsLogger = SpyLogger()
    QuickActionsMenu.trustCenterDelegate = SpyTrustCenter()

    return VStack(spacing: AppSpacing.xxLarge) {
        Group {
            Text("Horizontal Actions")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
            QuickActionsMenu(
                phone: "555-1234",
                onCall: { print("Call") },
                onMessage: { print("Message") },
                onAddAppointment: { print("Add Appt") },
                onAddNote: { print("Note") },
                onEdit: { print("Edit") },
                onDelete: { print("Delete") },
                helperText: "Tap an icon to quickly perform an action.",
                showDivider: true
            )

            Divider()

            Text("As Menu")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
            QuickActionsMenu(
                phone: "555-1234",
                onCall: { print("Call") },
                onMessage: { print("Message") },
                onAddAppointment: { print("Add Appt") },
                onAddNote: { print("Note") },
                onEdit: { print("Edit") },
                onDelete: { print("Delete") },
                asMenu: true,
                helperText: "Select an action from the menu."
            )
        }

        Divider()

        Group {
            Text("Horizontal with Custom Actions")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
            QuickActionsMenu(
                customActions: [
                    (label: "VIP", systemImage: "star.fill", color: AppColors.yellow, badge: "VIP", action: { print("VIP") }),
                    (label: "Urgent", systemImage: "bolt.fill", color: AppColors.purple, badge: "!", action: { print("Urgent") })
                ],
                helperText: "Includes custom actions with badges"
            )

            Divider()

            Text("Menu with Only Destructive")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
            QuickActionsMenu(
                onDelete: { print("Delete") },
                asMenu: true,
                helperText: "Destructive action only"
            )

            Divider()

            Text("Horizontal without Helper")
                .font(AppFonts.headline)
                .foregroundColor(AppColors.textPrimary)
            QuickActionsMenu(
                onCall: { print("Call") },
                onEdit: { print("Edit") }
            )
        }
    }
    .padding(AppSpacing.large)
    .background(AppColors.backgroundGrouped)
}

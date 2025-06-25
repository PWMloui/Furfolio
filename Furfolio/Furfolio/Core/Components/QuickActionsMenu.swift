//
//  QuickActionsMenu.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable, robust accessibility.
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
}
public struct NullQuickActionsMenuTrustCenterDelegate: QuickActionsMenuTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
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
    /// Custom actions must provide a label, system image, **tokenized color** (AppColors.*), and action closure.
    public var customActions: [(label: String, systemImage: String, color: Color, action: () -> Void)] = []
    public var asMenu: Bool = false
    public var helperText: String?
    public var showDivider: Bool = false

    // Audit/analytics logger & trust center (injectable for QA, Trust Center, preview)
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
        customActions: [(label: String, systemImage: String, color: Color, action: () -> Void)] = [],
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
                    if let onCall = onCall, let phone = phone {
                        Button {
                            actionHandler("call", ["phone": phone], onCall)
                        } label: {
                            Label("Call \(phone)", systemImage: "phone.fill")
                        }
                        .accessibilityLabel("Call \(phone)")
                        .accessibilityHint("Initiates a phone call to \(phone)")
                    }
                    if let onMessage = onMessage {
                        Button {
                            actionHandler("message", nil, onMessage)
                        } label: {
                            Label("Message", systemImage: "message.fill")
                        }
                        .accessibilityLabel("Message")
                        .accessibilityHint("Sends a message")
                    }
                    if let onAddAppointment = onAddAppointment {
                        Button {
                            actionHandler("addAppointment", nil, onAddAppointment)
                        } label: {
                            Label("Add Appointment", systemImage: "calendar.badge.plus")
                        }
                        .accessibilityLabel("Add Appointment")
                        .accessibilityHint("Adds a new appointment")
                    }
                    if let onAddNote = onAddNote {
                        Button {
                            actionHandler("addNote", nil, onAddNote)
                        } label: {
                            Label("Add Note", systemImage: "note.text.badge.plus")
                        }
                        .accessibilityLabel("Add Note")
                        .accessibilityHint("Adds a new note")
                    }
                    if let onEdit = onEdit {
                        Button {
                            actionHandler("edit", nil, onEdit)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .accessibilityLabel("Edit")
                        .accessibilityHint("Edits the item")
                    }
                    if let onDelete = onDelete {
                        Button(role: .destructive) {
                            actionHandler("delete", nil, onDelete)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete")
                        .accessibilityHint("Deletes the item")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAddTraits(.isDestructive)
                    }
                    ForEach(Array(customActions.enumerated()), id: \.offset) { _, action in
                        Button {
                            actionHandler("custom", ["label": action.label], action.action)
                        } label: {
                            Label(action.label, systemImage: action.systemImage)
                                .font(AppFonts.body)
                                .foregroundColor(action.color)
                        }
                        .accessibilityLabel(action.label)
                        .accessibilityHint("Performs the \(action.label) action")
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
                    if let onCall = onCall, let phone = phone {
                        ActionButton(
                            label: "Call",
                            systemImage: "phone.fill",
                            color: AppColors.green,
                            action: {
                                actionHandler("call", ["phone": phone], onCall)
                            }
                        )
                        .accessibilityLabel("Call \(phone)")
                        .accessibilityHint("Initiates a phone call to \(phone)")
                    }
                    if let onMessage = onMessage {
                        ActionButton(
                            label: "Message",
                            systemImage: "message.fill",
                            color: AppColors.blue,
                            action: {
                                actionHandler("message", nil, onMessage)
                            }
                        )
                        .accessibilityLabel("Message")
                        .accessibilityHint("Sends a message")
                    }
                    if let onAddAppointment = onAddAppointment {
                        ActionButton(
                            label: "Add",
                            systemImage: "calendar.badge.plus",
                            color: AppColors.accent,
                            action: {
                                actionHandler("addAppointment", nil, onAddAppointment)
                            }
                        )
                        .accessibilityLabel("Add Appointment")
                        .accessibilityHint("Adds a new appointment")
                    }
                    if let onAddNote = onAddNote {
                        ActionButton(
                            label: "Note",
                            systemImage: "note.text.badge.plus",
                            color: AppColors.orange,
                            action: {
                                actionHandler("addNote", nil, onAddNote)
                            }
                        )
                        .accessibilityLabel("Add Note")
                        .accessibilityHint("Adds a new note")
                    }
                    if let onEdit = onEdit {
                        ActionButton(
                            label: "Edit",
                            systemImage: "pencil",
                            color: AppColors.gray,
                            action: {
                                actionHandler("edit", nil, onEdit)
                            }
                        )
                        .accessibilityLabel("Edit")
                        .accessibilityHint("Edits the item")
                    }
                    if let onDelete = onDelete {
                        ActionButton(
                            label: "Delete",
                            systemImage: "trash",
                            color: AppColors.red,
                            action: {
                                actionHandler("delete", nil, onDelete)
                            },
                            isDestructive: true
                        )
                        .accessibilityLabel("Delete")
                        .accessibilityHint("Deletes the item")
                        .accessibilityAddTraits(.isDestructive)
                    }
                    ForEach(Array(customActions.enumerated()), id: \.offset) { _, action in
                        ActionButton(
                            label: action.label,
                            systemImage: action.systemImage,
                            color: action.color,
                            action: {
                                actionHandler("custom", ["label": action.label], action.action)
                            }
                        )
                        .accessibilityLabel(action.label)
                        .accessibilityHint("Performs the \(action.label) action")
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
    }

    private func performHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func actionHandler(_ action: String, _ context: [String: Any]? = nil, _ closure: () -> Void) {
        guard Self.trustCenterDelegate.permission(for: action, context: context) else {
            Self.analyticsLogger.log(event: "\(action)_denied", info: context)
            return
        }
        performHaptic()
        Self.analyticsLogger.log(event: action, info: context)
        closure()
    }
}

private extension QuickActionsMenu {
    struct ActionButton: View {
        let label: String
        let systemImage: String
        let color: Color
        let action: () -> Void
        var isDestructive: Bool = false

        var body: some View {
            Button(action: action) {
                VStack(spacing: AppSpacing.xSmall) {
                    Image(systemName: systemImage)
                        .font(AppFonts.title)
                        .foregroundColor(color)
                        .frame(minWidth: 44, minHeight: 44)
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
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityAddTraits(isDestructive ? .isDestructive : [])
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
            // Example: Deny delete for demo
            if action == "delete" { return false }
            return true
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
                    (label: "Custom 1", systemImage: "star.fill", color: AppColors.yellow, action: { print("Custom 1") }),
                    (label: "Custom 2", systemImage: "bolt.fill", color: AppColors.purple, action: { print("Custom 2") })
                ],
                helperText: "Includes custom actions"
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

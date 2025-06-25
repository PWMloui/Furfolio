//
//  NotificationSettingsView.swift
//  Furfolio
//
//  Enhanced: tokenized, auditable, diagnostics-ready, modular, and preview/test-injectable.
//

import SwiftUI
import UserNotifications

// MARK: - Audit Logger Protocol

public protocol NotificationAuditLogger {
    func log(event: NotificationAuditEvent)
}
public struct NullNotificationAuditLogger: NotificationAuditLogger {
    public init() {}
    public func log(event: NotificationAuditEvent) {}
}
public struct NotificationAuditEvent {
    public let key: String
    public let newValue: Bool
    public let timestamp: Date
    public let userID: String?
    public init(key: String, newValue: Bool, userID: String? = nil) {
        self.key = key
        self.newValue = newValue
        self.timestamp = .init()
        self.userID = userID
    }
}

// MARK: - ViewModel for Notification Settings

class NotificationSettingsViewModel: ObservableObject {
    // User preferences (AppStorage-backed)
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true {
        didSet { logNotificationSettingChange("notificationsEnabled", notificationsEnabled) }
    }
    @AppStorage("appointmentRemindersEnabled") var appointmentRemindersEnabled: Bool = true {
        didSet { logNotificationSettingChange("appointmentRemindersEnabled", appointmentRemindersEnabled) }
    }
    @AppStorage("taskRemindersEnabled") var taskRemindersEnabled: Bool = true {
        didSet { logNotificationSettingChange("taskRemindersEnabled", taskRemindersEnabled) }
    }
    @AppStorage("marketingNotificationsEnabled") var marketingNotificationsEnabled: Bool = false {
        didSet { logNotificationSettingChange("marketingNotificationsEnabled", marketingNotificationsEnabled) }
    }
    @AppStorage("expenseRemindersEnabled") var expenseRemindersEnabled: Bool = false {
        didSet { logNotificationSettingChange("expenseRemindersEnabled", expenseRemindersEnabled) }
    }
    @AppStorage("inventoryNotificationsEnabled") var inventoryNotificationsEnabled: Bool = false {
        didSet { logNotificationSettingChange("inventoryNotificationsEnabled", inventoryNotificationsEnabled) }
    }

    // Alert state
    @Published var showPermissionAlert: Bool = false

    // For navigation, onboarding, etc.
    let learnMoreURL = URL(string: "https://furfolio.app/docs/notifications")!

    // Diagnostics
    var diagnosticsSummary: String {
        let enabled = [
            notificationsEnabled,
            appointmentRemindersEnabled,
            taskRemindersEnabled,
            marketingNotificationsEnabled,
            expenseRemindersEnabled,
            inventoryNotificationsEnabled
        ].filter { $0 }.count
        return "Enabled: \(enabled)/6"
    }

    // Audit/analytics
    private let auditLogger: NotificationAuditLogger
    private let userID: String?

    // Init (inject for preview/test)
    init(auditLogger: NotificationAuditLogger = NullNotificationAuditLogger(), userID: String? = nil) {
        self.auditLogger = auditLogger
        self.userID = userID
    }

    // MARK: - Permission Handling
    func handleNotificationsEnabledChanged(to newValue: Bool) {
        if newValue {
            requestNotificationPermissions()
        }
    }

    private func requestNotificationPermissions() {
        #if !targetEnvironment(macCatalyst)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized {
                DispatchQueue.main.async {
                    self.showPermissionAlert = true
                }
            }
        }
        #endif
    }

    // MARK: - Audit Logging
    func logNotificationSettingChange(_ key: String, _ newValue: Bool) {
        auditLogger.log(event: NotificationAuditEvent(key: key, newValue: newValue, userID: userID))
    }
}

// MARK: - View

struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: NotificationSettingsViewModel

    init(viewModel: NotificationSettingsViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header:
                    Text(NSLocalizedString("Push Notifications", comment: "Section header"))
                        .accessibilityAddTraits(.isHeader)
                ) {
                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                            Text(NSLocalizedString("Enable Notifications", comment: "Toggle title"))
                                .font(AppFonts.body ?? .body)
                            Text(NSLocalizedString("Receive important alerts, reminders, and updates from Furfolio.", comment: "Toggle description"))
                                .font(AppFonts.caption ?? .caption)
                                .foregroundColor(AppColors.textSecondary ?? .secondary)
                        }
                    }
                    .onChange(of: viewModel.notificationsEnabled) { newValue in
                        viewModel.handleNotificationsEnabledChanged(to: newValue)
                    }
                    .accessibilityLabel(Text(NSLocalizedString("Enable Notifications", comment: "Toggle title")))
                    .accessibilityHint(Text(NSLocalizedString("Toggle to receive important alerts, reminders, and updates from Furfolio.", comment: "Toggle accessibility hint")))

                    HStack {
                        Spacer()
                        Link(NSLocalizedString("Learn More", comment: "Learn more link"), destination: viewModel.learnMoreURL)
                            .font(AppFonts.caption ?? .caption)
                            .accessibilityLabel(Text(NSLocalizedString("Learn more about notifications", comment: "Accessibility label for learn more link")))
                            .accessibilityHint(Text(NSLocalizedString("Opens Furfolio documentation about notifications in your browser.", comment: "Accessibility hint for learn more link")))
                        Spacer()
                    }
                }
                .accessibilityElement(children: .contain)

                if viewModel.notificationsEnabled {
                    Section(header:
                        Text(NSLocalizedString("Notification Types", comment: "Section header"))
                            .accessibilityAddTraits(.isHeader)
                    ) {
                        Toggle(isOn: $viewModel.appointmentRemindersEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                                Text(NSLocalizedString("Appointment Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Get reminders for upcoming grooming appointments.", comment: "Toggle description"))
                                    .font(AppFonts.caption2 ?? .caption2)
                                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.taskRemindersEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                                Text(NSLocalizedString("Task Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Be notified about tasks and to-dos.", comment: "Toggle description"))
                                    .font(AppFonts.caption2 ?? .caption2)
                                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.marketingNotificationsEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                                Text(NSLocalizedString("Marketing & Tips", comment: "Toggle title"))
                                Text(NSLocalizedString("Occasional updates, business tips, and special offers.", comment: "Toggle description"))
                                    .font(AppFonts.caption2 ?? .caption2)
                                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.expenseRemindersEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                                Text(NSLocalizedString("Expense Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Get reminders for expense tracking and payments. (Coming Soon)", comment: "Toggle description"))
                                    .font(AppFonts.caption2 ?? .caption2)
                                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.inventoryNotificationsEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
                                Text(NSLocalizedString("Inventory Notifications", comment: "Toggle title"))
                                Text(NSLocalizedString("Be alerted about low inventory and supply levels. (Coming Soon)", comment: "Toggle description"))
                                    .font(AppFonts.caption2 ?? .caption2)
                                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                }

                // Diagnostics/Debug
                Section {
                    Text("\(NSLocalizedString("Diagnostics", comment: "")): \(viewModel.diagnosticsSummary)")
                        .font(AppFonts.footnote ?? .footnote)
                        .foregroundColor(AppColors.textSecondary ?? .secondary)
                        .accessibilityHidden(true)
                }
            }
            .navigationTitle(NSLocalizedString("Notifications", comment: "Navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Close", comment: "Close button")) {
                        dismiss()
                    }
                }
            }
            .alert(
                NSLocalizedString("Notifications Disabled", comment: "Permission alert title"),
                isPresented: $viewModel.showPermissionAlert
            ) {
                Button(NSLocalizedString("OK", comment: "OK button"), role: .cancel) {}
            } message: {
                Text(NSLocalizedString("Notifications are disabled for Furfolio in Settings. To receive alerts, please enable notifications in your device Settings app.", comment: "Permission alert message"))
            }
        }
    }
}

// MARK: - Previews

#Preview {
    Group {
        NotificationSettingsView(viewModel: {
            let mock = NotificationSettingsViewModel()
            mock.notificationsEnabled = true
            mock.appointmentRemindersEnabled = true
            mock.taskRemindersEnabled = false
            mock.marketingNotificationsEnabled = true
            mock.expenseRemindersEnabled = false
            mock.inventoryNotificationsEnabled = false
            return mock
        }())
        .previewDisplayName("Default Preview")

        NotificationSettingsView(viewModel: {
            let mock = NotificationSettingsViewModel()
            mock.notificationsEnabled = true
            mock.appointmentRemindersEnabled = true
            mock.taskRemindersEnabled = false
            mock.marketingNotificationsEnabled = true
            mock.expenseRemindersEnabled = false
            mock.inventoryNotificationsEnabled = false
            return mock
        }())
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Large Text Preview")
    }
}

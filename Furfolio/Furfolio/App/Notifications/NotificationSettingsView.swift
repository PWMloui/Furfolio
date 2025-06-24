//
//  NotificationSettingsView.swift
//  Furfolio
//
//  Architectural summary:
//  - This view provides a centralized interface for users to manage their notification preferences across all Furfolio-supported platforms (iOS, iPadOS, macOS).
//  - The view is ready for Trust Center/audit trail support, with hooks for logging notification setting changes.
//  - Notification preferences are managed via a dedicated ObservableObject ViewModel, enabling multi-user, testing, and preview support.
//  - The UI is built with NavigationStack for modern SwiftUI navigation and consistent experience on all platforms.
//  - Adaptive layout, onboarding/documentation links, and localization placeholders are included for future expansion.
//
//  Trust Center/Multi-platform ready.

import SwiftUI
import UserNotifications

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
    // New toggles for future features
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
        // Placeholder for Trust Center/audit logging
        // Example: TrustCenter.log(event: .notificationSettingChanged(key, newValue))
        // print("[Audit] \(key) changed to \(newValue)")
    }
}

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
                        VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                            Text(NSLocalizedString("Enable Notifications", comment: "Toggle title"))
                                .font(AppFonts.body) // replaced .fontWeight(.semibold) with AppFonts.body
                            Text(NSLocalizedString("Receive important alerts, reminders, and updates from Furfolio.", comment: "Toggle description"))
                                .font(AppFonts.caption) // replaced .font(.caption)
                                .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
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
                            .font(AppFonts.caption) // replaced .font(.caption)
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
                            VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                                Text(NSLocalizedString("Appointment Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Get reminders for upcoming grooming appointments.", comment: "Toggle description"))
                                    .font(AppFonts.caption2) // replaced .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.taskRemindersEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                                Text(NSLocalizedString("Task Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Be notified about tasks and to-dos.", comment: "Toggle description"))
                                    .font(AppFonts.caption2) // replaced .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.marketingNotificationsEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                                Text(NSLocalizedString("Marketing & Tips", comment: "Toggle title"))
                                Text(NSLocalizedString("Occasional updates, business tips, and special offers.", comment: "Toggle description"))
                                    .font(AppFonts.caption2) // replaced .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.expenseRemindersEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                                Text(NSLocalizedString("Expense Reminders", comment: "Toggle title"))
                                Text(NSLocalizedString("Get reminders for expense tracking and payments. (Coming Soon)", comment: "Toggle description"))
                                    .font(AppFonts.caption2) // replaced .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
                            }
                        }
                        Toggle(isOn: $viewModel.inventoryNotificationsEnabled) {
                            VStack(alignment: .leading, spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small exists
                                Text(NSLocalizedString("Inventory Notifications", comment: "Toggle title"))
                                Text(NSLocalizedString("Be alerted about low inventory and supply levels. (Coming Soon)", comment: "Toggle description"))
                                    .font(AppFonts.caption2) // replaced .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary) // replaced .foregroundColor(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
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

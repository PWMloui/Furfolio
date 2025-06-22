//
//  FurfolioAlertView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - FurfolioAlert (Business Alert Model, Modular, Accessible, Localized)

/// Represents a modular, accessible, and localized alert used throughout the Furfolio app,
/// specifically designed for business management scenarios.
/// This struct supports semantic roles, localization, accessibility features, and customization with icons,
/// enabling clear communication of various alert types such as informational, warning, error, success, and destructive alerts.
/// Conforms to `Codable`, `Sendable`, and `Equatable` to facilitate multi-user syncing, audit logging, and offline support,
/// ensuring robustness in business-critical environments.
struct FurfolioAlert: Identifiable, Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable, Equatable {
        case info
        case warning
        case error
        case success
        case destructive
    }

    let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    let role: Role
    let iconName: String?
    let accessibilityLabel: LocalizedStringKey?
    let accessibilityHint: LocalizedStringKey?

    /// Initializes a new FurfolioAlert.
    /// - Parameters:
    ///   - title: The visible title displayed in the alert. This should be localized to ensure clarity and usability for all users.
    ///   - message: Optional alert message (localized).
    ///   - primaryButton: The primary alert button, defaulting to "OK".
    ///   - secondaryButton: Optional secondary alert button.
    ///   - role: The semantic role of the alert for visual and accessibility purposes.
    ///   - iconName: Optional SF Symbol name to display as an icon.
    ///   - accessibilityLabel: Optional label for accessibility.
    ///   - accessibilityHint: Optional hint for accessibility.
    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        primaryButton: Alert.Button = .default(Text("OK")),
        secondaryButton: Alert.Button? = nil,
        role: Role = .info,
        iconName: String? = nil,
        accessibilityLabel: LocalizedStringKey? = nil,
        accessibilityHint: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.role = role
        self.iconName = iconName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }

    /// Creates a simple informational alert with an "OK" button.
    /// - Parameters:
    ///   - title: The alert title (localized).
    ///   - message: Optional alert message (localized).
    /// - Returns: A FurfolioAlert configured with default OK action and info role.
    static func defaultAction(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil
    ) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .default(Text("OK")),
            role: .info
        )
    }
}

extension View {
    /// Presents a FurfolioAlert using a binding to an optional FurfolioAlert.
    /// Passes accessibility labels and hints to the underlying Alert.
    /// - Parameter alert: Binding to an optional FurfolioAlert.
    /// - Returns: A view presenting the alert when non-nil.
    func furfolioAlert(_ alert: Binding<FurfolioAlert?>) -> some View {
        self.alert(item: alert) { alert in
            let alertTitle = Text(alert.title)
            let alertMessage = alert.message.map(Text.init)

            let alertView: Alert
            if let secondary = alert.secondaryButton {
                alertView = Alert(
                    title: alertTitle,
                    message: alertMessage,
                    primaryButton: alert.primaryButton,
                    secondaryButton: secondary
                )
            } else {
                alertView = Alert(
                    title: alertTitle,
                    message: alertMessage,
                    dismissButton: alert.primaryButton
                )
            }

            return alertView
                .accessibilityLabel(alert.accessibilityLabel.map(Text.init))
                .accessibilityHint(alert.accessibilityHint.map(Text.init))
        }
    }
}

// MARK: - Previews for onboarding, role demonstration, and icon usage

struct FurfolioAlertView_Previews: PreviewProvider {
    struct Demo: View {
        @State private var alert: FurfolioAlert?

        var body: some View {
            VStack(spacing: 24) {
                Button("Show Destructive Alert") {
                    alert = FurfolioAlert(
                        title: "Delete Item",
                        message: "This action cannot be undone.",
                        primaryButton: .destructive(Text("Delete")) {
                            print("Item deleted")
                        },
                        secondaryButton: .cancel(),
                        role: .destructive,
                        iconName: "trash.fill",
                        accessibilityLabel: "Delete confirmation",
                        accessibilityHint: "Deletes the selected item permanently"
                    )
                }

                Button("Show Success Alert") {
                    alert = FurfolioAlert(
                        title: "Success",
                        message: "Your changes have been saved.",
                        primaryButton: .default(Text("OK")),
                        role: .success,
                        iconName: "checkmark.seal.fill"
                    )
                }

                Button("Show Warning Alert") {
                    alert = FurfolioAlert(
                        title: "Warning",
                        message: "Please review the entered data.",
                        role: .warning,
                        iconName: "exclamationmark.triangle.fill"
                    )
                }

                Button("Show Info Alert") {
                    alert = FurfolioAlert.defaultAction(
                        title: "Information",
                        message: "This is an informational alert."
                    )
                }
            }
            .padding()
            .furfolioAlert($alert)
        }
    }

    static var previews: some View {
        Demo()
    }
}

extension Alert {
    /// Adds accessibility label if provided.
    fileprivate func accessibilityLabel(_ label: Text?) -> Alert {
        guard let label = label else { return self }
        return Alert(
            title: self.title.accessibilityLabel(label),
            message: self.message,
            dismissButton: self.dismissButton,
            primaryButton: self.primaryButton,
            secondaryButton: self.secondaryButton
        )
    }

    /// Adds accessibility hint if provided.
    fileprivate func accessibilityHint(_ hint: Text?) -> Alert {
        guard let hint = hint else { return self }
        return Alert(
            title: self.title.accessibilityHint(hint),
            message: self.message,
            dismissButton: self.dismissButton,
            primaryButton: self.primaryButton,
            secondaryButton: self.secondaryButton
        )
    }
}

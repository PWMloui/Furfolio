//
//  FurfolioAlertView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, token-compliant, Trust Center–ready, accessibility, preview/test–injectable.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol FurfolioAlertAnalyticsLogger {
    func log(event: String, alert: FurfolioAlert)
}
public struct NullFurfolioAlertAnalyticsLogger: FurfolioAlertAnalyticsLogger {
    public init() {}
    public func log(event: String, alert: FurfolioAlert) {}
}

// MARK: - FurfolioAlert (Business Alert Model, Modular, Accessible, Localized, Audit)

struct FurfolioAlert: Identifiable, Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable, Equatable, CaseIterable {
        case info
        case warning
        case error
        case success
        case destructive

        /// Tokenized SF Symbol for each role (can be replaced per brand/theme).
        var iconName: String {
            switch self {
            case .info:        return "info.circle.fill"
            case .warning:     return "exclamationmark.triangle.fill"
            case .error:       return "xmark.octagon.fill"
            case .success:     return "checkmark.seal.fill"
            case .destructive: return "trash.fill"
            }
        }

        /// Tokenized color name (hook into theme).
        var color: Color {
            switch self {
            case .info:        return AppColors.info
            case .warning:     return AppColors.warning
            case .error:       return AppColors.danger
            case .success:     return AppColors.success
            case .destructive: return AppColors.danger
            }
        }
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
    let auditTag: String? // For Trust Center/audit scenarios

    /// Initializes a new FurfolioAlert.
    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        primaryButton: Alert.Button = .default(Text("OK")),
        secondaryButton: Alert.Button? = nil,
        role: Role = .info,
        iconName: String? = nil,
        accessibilityLabel: LocalizedStringKey? = nil,
        accessibilityHint: LocalizedStringKey? = nil,
        auditTag: String? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.role = role
        self.iconName = iconName
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.auditTag = auditTag
    }

    /// Info alert shortcut (tokenized).
    static func info(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .default(Text("OK")),
            role: .info,
            iconName: Role.info.iconName
        )
    }
    /// Error alert shortcut.
    static func error(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil, auditTag: String? = nil) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .default(Text("OK")),
            role: .error,
            iconName: Role.error.iconName,
            auditTag: auditTag
        )
    }
    /// Destructive alert shortcut.
    static func destructive(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        auditTag: String? = nil,
        onDelete: @escaping () -> Void
    ) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .destructive(Text("Delete"), action: onDelete),
            secondaryButton: .cancel(),
            role: .destructive,
            iconName: Role.destructive.iconName,
            auditTag: auditTag
        )
    }
}

// MARK: - Analytics Logger (swap in your own for QA/Trust Center/print)

extension FurfolioAlert {
    static var analyticsLogger: FurfolioAlertAnalyticsLogger = NullFurfolioAlertAnalyticsLogger()
}

// MARK: - View Modifier (Audit/Analytics–ready)

extension View {
    /// Presents a FurfolioAlert using a binding to an optional FurfolioAlert.
    /// Logs alert presents and Trust Center audit tags.
    func furfolioAlert(_ alert: Binding<FurfolioAlert?>) -> some View {
        self.alert(item: alert) { alert in
            FurfolioAlert.analyticsLogger.log(event: "present", alert: alert)
            if let tag = alert.auditTag {
                FurfolioAlert.analyticsLogger.log(event: "audit_tag", alert: alert)
                // Trust Center hook: export to audit log if tag present
            }
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
            // Add accessibility
            return alertView
                .accessibilityLabel(alert.accessibilityLabel.map(Text.init))
                .accessibilityHint(alert.accessibilityHint.map(Text.init))
        }
    }
}

// MARK: - Previews: demo analytics and Trust Center audit

struct FurfolioAlertView_Previews: PreviewProvider {
    struct SpyLogger: FurfolioAlertAnalyticsLogger {
        func log(event: String, alert: FurfolioAlert) {
            print("[FurfolioAlertAnalytics] \(event) \(alert.role.rawValue) \(alert.title) \(alert.auditTag ?? "")")
        }
    }
    struct Demo: View {
        @State private var alert: FurfolioAlert?

        var body: some View {
            VStack(spacing: 24) {
                Button("Show Destructive Alert") {
                    alert = FurfolioAlert.destructive(
                        title: "Delete Item",
                        message: "This action cannot be undone.",
                        auditTag: "delete_item",
                        onDelete: {
                            FurfolioAlert.analyticsLogger.log(event: "destructive_action", alert: FurfolioAlert.error("Deleted!"))
                        }
                    )
                }
                Button("Show Success Alert") {
                    alert = FurfolioAlert(
                        title: "Success",
                        message: "Your changes have been saved.",
                        primaryButton: .default(Text("OK")),
                        role: .success,
                        iconName: FurfolioAlert.Role.success.iconName
                    )
                }
                Button("Show Warning Alert") {
                    alert = FurfolioAlert(
                        title: "Warning",
                        message: "Please review the entered data.",
                        role: .warning,
                        iconName: FurfolioAlert.Role.warning.iconName
                    )
                }
                Button("Show Info Alert") {
                    alert = FurfolioAlert.info(
                        "Information",
                        message: "This is an informational alert."
                    )
                }
            }
            .padding()
            .furfolioAlert($alert)
        }
    }
    static var previews: some View {
        FurfolioAlert.analyticsLogger = SpyLogger()
        return Demo()
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

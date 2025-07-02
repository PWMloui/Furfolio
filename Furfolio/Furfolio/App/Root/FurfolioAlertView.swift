//
//  FurfolioAlertView.swift
//  Furfolio
//
//  ENHANCED 2025-06-30: Role/staff/context audit, escalation, trust center/BI ready, modular, tokenized, accessible, fully localizable.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol FurfolioAlertAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func fetchRecentEvents(maxCount: Int) async -> [String]
    func escalate(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?) async
}

public struct NullFurfolioAlertAnalyticsLogger: FurfolioAlertAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(maxCount: Int) async -> [String] { [] }
    public func escalate(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?) async {}
}

public final class InMemoryFurfolioAlertAnalyticsLogger: FurfolioAlertAnalyticsLogger {
    public var testMode: Bool = false
    private var events: [String] = []
    private let queue = DispatchQueue(label: "FurfolioAlertAnalyticsLoggerQueue")
    public init(testMode: Bool = false) { self.testMode = testMode }
    public func log(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let logEntry = "[FurfolioAlertAnalytics] \(event) \(alert.role.rawValue) \(alert.titleString) \(alert.auditTag ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]"
        queue.sync {
            events.append(logEntry)
            if events.count > 20 { events.removeFirst(events.count - 20) }
        }
        if testMode { print(logEntry) }
        await Task.yield()
    }
    public func escalate(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?) async {
        let logEntry = "[FurfolioAlertAnalytics][ESCALATE] \(event) \(alert.role.rawValue) \(alert.titleString) \(alert.auditTag ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]"
        queue.sync {
            events.append(logEntry)
            if events.count > 20 { events.removeFirst(events.count - 20) }
        }
        print(logEntry)
        await Task.yield()
    }
    public func fetchRecentEvents(maxCount: Int) async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async {
                let recent = Array(self.events.suffix(maxCount))
                continuation.resume(returning: recent)
            }
        }
    }
}

// MARK: - Global Audit Context (Set from App/Session for all alerts)

public struct FurfolioAlertAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "FurfolioAlertView"
}

// MARK: - FurfolioAlert (No changes, already modular/auditable/localized)

struct FurfolioAlert: Identifiable, Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable, Equatable, CaseIterable {
        case info, warning, error, success, destructive
        var iconName: String {
            switch self {
            case .info:        return "info.circle.fill"
            case .warning:     return "exclamationmark.triangle.fill"
            case .error:       return "xmark.octagon.fill"
            case .success:     return "checkmark.seal.fill"
            case .destructive: return "trash.fill"
            }
        }
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
    let auditTag: String?
    var titleString: String {
        let mirror = Mirror(reflecting: title)
        if let value = mirror.children.first(where: { $0.label == "key" })?.value as? String { return value }
        return "\(title)"
    }
    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        primaryButton: Alert.Button = .default(Text(NSLocalizedString("OK", comment: "Default OK button title"))),
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
    static func info(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .default(Text(NSLocalizedString("OK", comment: "Default OK button title"))),
            role: .info,
            iconName: Role.info.iconName
        )
    }
    static func error(_ title: LocalizedStringKey, message: LocalizedStringKey? = nil, auditTag: String? = nil) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .default(Text(NSLocalizedString("OK", comment: "Default OK button title"))),
            role: .error,
            iconName: Role.error.iconName,
            auditTag: auditTag
        )
    }
    static func destructive(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        auditTag: String? = nil,
        onDelete: @escaping () -> Void
    ) -> FurfolioAlert {
        FurfolioAlert(
            title: title,
            message: message,
            primaryButton: .destructive(Text(NSLocalizedString("Delete", comment: "Delete button title")), action: onDelete),
            secondaryButton: .cancel(),
            role: .destructive,
            iconName: Role.destructive.iconName,
            auditTag: auditTag
        )
    }
}

// MARK: - Analytics Logger (swap in your own for Trust Center, QA, etc.)

extension FurfolioAlert {
    static var analyticsLogger: FurfolioAlertAnalyticsLogger = NullFurfolioAlertAnalyticsLogger()
}

// MARK: - View Modifier (Audit/Analytics/Trust Center ready)

extension View {
    func furfolioAlert(_ alert: Binding<FurfolioAlert?>) -> some View {
        self.alert(item: alert) { alert in
            let ctx = FurfolioAlertAuditContext.context
            let role = FurfolioAlertAuditContext.role
            let staffID = FurfolioAlertAuditContext.staffID
            Task {
                await FurfolioAlert.analyticsLogger.log(
                    event: NSLocalizedString("present", comment: "Alert presented event"),
                    alert: alert, role: role, staffID: staffID, context: ctx, escalate: false
                )
                if let tag = alert.auditTag {
                    await FurfolioAlert.analyticsLogger.escalate(
                        event: NSLocalizedString("audit_tag", comment: "Alert audit tag event"),
                        alert: alert, role: role, staffID: staffID, context: ctx
                    )
                }
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
            return alertView
                .accessibilityLabel(alert.accessibilityLabel.map(Text.init))
                .accessibilityHint(alert.accessibilityHint.map(Text.init))
        }
    }
}

// MARK: - Previews: demo analytics, audit, trust center escalation

struct FurfolioAlertView_Previews: PreviewProvider {
    struct SpyLogger: FurfolioAlertAnalyticsLogger {
        var testMode: Bool = true
        func log(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[FurfolioAlertAnalytics] \(event) \(alert.role.rawValue) \(alert.titleString) \(alert.auditTag ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
        }
        func fetchRecentEvents(maxCount: Int) async -> [String] { [] }
        func escalate(event: String, alert: FurfolioAlert, role: String?, staffID: String?, context: String?) async {
            print("[FurfolioAlertAnalytics][ESCALATE] \(event) \(alert.role.rawValue) \(alert.titleString) \(alert.auditTag ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
        }
    }
    struct Demo: View {
        @State private var alert: FurfolioAlert?
        var body: some View {
            VStack(spacing: 24) {
                Button(NSLocalizedString("Show Destructive Alert", comment: "Button title to show destructive alert")) {
                    alert = FurfolioAlert.destructive(
                        title: NSLocalizedString("Delete Item", comment: "Destructive alert title"),
                        message: NSLocalizedString("This action cannot be undone.", comment: "Destructive alert message"),
                        auditTag: "delete_item",
                        onDelete: {
                            Task {
                                await FurfolioAlert.analyticsLogger.log(
                                    event: NSLocalizedString("destructive_action", comment: "Destructive action performed"),
                                    alert: FurfolioAlert.error(NSLocalizedString("Deleted!", comment: "Deleted confirmation alert title")),
                                    role: "Owner", staffID: "staff001", context: "Preview", escalate: true
                                )
                            }
                        }
                    )
                }
                Button(NSLocalizedString("Show Success Alert", comment: "Button title to show success alert")) {
                    alert = FurfolioAlert(
                        title: NSLocalizedString("Success", comment: "Success alert title"),
                        message: NSLocalizedString("Your changes have been saved.", comment: "Success alert message"),
                        primaryButton: .default(Text(NSLocalizedString("OK", comment: "Default OK button title"))),
                        role: .success,
                        iconName: FurfolioAlert.Role.success.iconName
                    )
                }
                Button(NSLocalizedString("Show Warning Alert", comment: "Button title to show warning alert")) {
                    alert = FurfolioAlert(
                        title: NSLocalizedString("Warning", comment: "Warning alert title"),
                        message: NSLocalizedString("Please review the entered data.", comment: "Warning alert message"),
                        role: .warning,
                        iconName: FurfolioAlert.Role.warning.iconName
                    )
                }
                Button(NSLocalizedString("Show Info Alert", comment: "Button title to show info alert")) {
                    alert = FurfolioAlert.info(
                        NSLocalizedString("Information", comment: "Information alert title"),
                        message: NSLocalizedString("This is an informational alert.", comment: "Information alert message")
                    )
                }
            }
            .padding()
            .furfolioAlert($alert)
        }
    }
    static var previews: some View {
        FurfolioAlert.analyticsLogger = SpyLogger()
        FurfolioAlertAuditContext.role = "Owner"
        FurfolioAlertAuditContext.staffID = "staff001"
        FurfolioAlertAuditContext.context = "Preview"
        return Demo()
    }
}

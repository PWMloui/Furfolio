//
//  ThemeCustomizerView.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ThemeCustomizerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ThemeCustomizerView"
}

public protocol ThemeCustomizerAnalyticsLogger {
    var testMode: Bool { get }
    func log(
        action: String,
        parameter: String?,
        value: Any?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    func recentEvents() -> [ThemeCustomizerAnalyticsEvent]
}

public struct ThemeCustomizerAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let action: String
    public let parameter: String?
    public let valueDescription: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

public final class DefaultThemeCustomizerAnalyticsLogger: ThemeCustomizerAnalyticsLogger {
    public var testMode: Bool = false
    private var buffer: [ThemeCustomizerAnalyticsEvent] = []
    private let bufferLimit = 20

    public func log(action: String, parameter: String?, value: Any?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let event = ThemeCustomizerAnalyticsEvent(
            timestamp: Date(),
            action: action,
            parameter: parameter,
            valueDescription: value.map { "\($0)" },
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        if testMode {
            print("ThemeCustomizerAnalyticsEvent: \(event)")
        }
        buffer.append(event)
        if buffer.count > bufferLimit {
            buffer.removeFirst()
        }
    }

    public func recentEvents() -> [ThemeCustomizerAnalyticsEvent] {
        buffer
    }
}

struct ThemeCustomizerView: View {
    // Analytics logger for audit and compliance tracking
    var analyticsLogger: ThemeCustomizerAnalyticsLogger? = DefaultThemeCustomizerAnalyticsLogger()

    @State private var selectedParameter: String? = nil
    @State private var appliedValue: Any? = nil

    var body: some View {
        VStack {
            // Theme customization UI here
            Text("Theme Customizer")

            Button("Apply Theme") {
                // Example theme application logic
                selectedParameter = "PrimaryColor"
                appliedValue = "Blue"

                // Log the apply_theme action for audit/compliance
                Task {
                    await analyticsLogger?.log(
                        action: "apply_theme",
                        parameter: selectedParameter,
                        value: appliedValue,
                        role: ThemeCustomizerAuditContext.role,
                        staffID: ThemeCustomizerAuditContext.staffID,
                        context: ThemeCustomizerAuditContext.context,
                        escalate: (selectedParameter?.lowercased().contains("danger") ?? false) || (appliedValue as? String)?.lowercased().contains("danger") ?? false
                    )
                }
            }

            #if DEBUG
            // Diagnostics / debug section to list recent audit events
            List {
                Section(header: Text("Recent Audit Events")) {
                    ForEach(analyticsLogger?.recentEvents() ?? []) { event in
                        VStack(alignment: .leading) {
                            Text("Action: \(event.action)")
                            Text("Parameter: \(event.parameter ?? "nil")")
                            Text("Value: \(event.valueDescription ?? "nil")")
                            Text("Role: \(event.role ?? "nil")")
                            Text("Staff ID: \(event.staffID ?? "nil")")
                            Text("Context: \(event.context ?? "nil")")
                            Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            Text("Timestamp: \(event.timestamp)")
                        }
                        .font(.caption)
                        .padding(4)
                    }
                }
            }
            #endif
        }
    }
}

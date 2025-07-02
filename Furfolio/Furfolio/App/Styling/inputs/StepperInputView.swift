//
//  StepperInputView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, token-compliant, Trust Center–capable, accessible, preview/test–injectable.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct StepperInputAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "StepperInputView"
}

// MARK: - Analytics/Audit Protocol

public protocol StepperInputAnalyticsLogger {
    var testMode: Bool { get }
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    func recentEvents() -> [StepperInputAnalyticsEvent]
}

public struct StepperInputAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let info: [String: Any]?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

public struct NullStepperInputAnalyticsLogger: StepperInputAnalyticsLogger {
    public init() {}
    public var testMode: Bool { false }
    public func log(
        event: String,
        info: [String : Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[StepperInputAnalytics] \(event): info=\(info ?? [:]), role=\(role ?? "nil"), staffID=\(staffID ?? "nil"), context=\(context ?? "nil"), escalate=\(escalate)")
        }
    }
    public func recentEvents() -> [StepperInputAnalyticsEvent] { [] }
}

// MARK: - StepperInputView (Enterprise Enhanced)

struct StepperInputView: View {
    /// An optional label to display next to the stepper.
    var label: LocalizedStringKey?

    /// The binding to the integer value this stepper controls.
    @Binding var value: Int

    /// The allowed range for the value.
    var range: ClosedRange<Int> = 0...100

    /// The amount to increment or decrement with each tap.
    var step: Int = 1

    /// Optional tag for audit/analytics/Trust Center.
    var auditTag: String? = nil

    /// Analytics logger (swap for QA/print/Trust Center)
    static var analyticsLogger: StepperInputAnalyticsLogger = NullStepperInputAnalyticsLogger()

    private static var recentEvents: [StepperInputAnalyticsEvent] = []

    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityLabel(Text(label))
            }

            Spacer()

            HStack(spacing: AppSpacing.medium) {
                // MARK: - Decrement Button
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .disabled(value <= range.lowerBound)
                .accessibilityLabel(Text("Decrease value"))
                .accessibilityHint(Text("Decreases to minimum of \(range.lowerBound)"))
                .accessibilityAddTraits(.isButton)

                // MARK: - Value Display
                Text("\(value)")
                    .font(AppFonts.headline.monospacedDigit())
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("Current value"))
                    .accessibilityValue(Text("\(value)"))

                // MARK: - Increment Button
                Button {
                    increment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(value >= range.upperBound)
                .accessibilityLabel(Text("Increase value"))
                .accessibilityHint(Text("Increases to maximum of \(range.upperBound)"))
                .accessibilityAddTraits(.isButton)
            }
            .font(AppFonts.title2)
            .foregroundColor(AppColors.primary)
        }
        .padding(AppSpacing.medium)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.medium)
        .appShadow(AppShadows.card)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                increment()
            case .decrement:
                decrement()
            @unknown default:
                break
            }
        }
        .accessibilityIdentifier("StepperInputView_\(label.map { "\($0)" } ?? "value")")
    }

    private func increment() {
        guard value < range.upperBound else { return }
        value += step
        HapticManager.selection()
        let isEscalate = auditTag?.lowercased().contains(where: { ["danger", "delete", "critical"].contains($0) }) ?? false
        let event = StepperInputAnalyticsEvent(
            timestamp: Date(),
            event: "increment",
            info: [
                "label": label?.stringValue ?? "",
                "newValue": value,
                "auditTag": auditTag as Any
            ],
            role: StepperInputAuditContext.role,
            staffID: StepperInputAuditContext.staffID,
            context: StepperInputAuditContext.context,
            escalate: isEscalate
        )
        Self.recentEvents.append(event)
        if Self.recentEvents.count > 20 {
            Self.recentEvents.removeFirst()
        }
        Task {
            await Self.analyticsLogger.log(
                event: event.event,
                info: event.info,
                role: event.role,
                staffID: event.staffID,
                context: event.context,
                escalate: event.escalate
            )
        }
    }

    private func decrement() {
        guard value > range.lowerBound else { return }
        value -= step
        HapticManager.selection()
        let isEscalate = auditTag?.lowercased().contains(where: { ["danger", "delete", "critical"].contains($0) }) ?? false
        let event = StepperInputAnalyticsEvent(
            timestamp: Date(),
            event: "decrement",
            info: [
                "label": label?.stringValue ?? "",
                "newValue": value,
                "auditTag": auditTag as Any
            ],
            role: StepperInputAuditContext.role,
            staffID: StepperInputAuditContext.staffID,
            context: StepperInputAuditContext.context,
            escalate: isEscalate
        )
        Self.recentEvents.append(event)
        if Self.recentEvents.count > 20 {
            Self.recentEvents.removeFirst()
        }
        Task {
            await Self.analyticsLogger.log(
                event: event.event,
                info: event.info,
                role: event.role,
                staffID: event.staffID,
                context: event.context,
                escalate: event.escalate
            )
        }
    }

    public static func fetchRecentEvents() -> [StepperInputAnalyticsEvent] {
        return recentEvents
    }
}

// MARK: - Preview with Analytics Logger

#if DEBUG
struct StepperInputView_Previews: PreviewProvider {
    struct SpyLogger: StepperInputAnalyticsLogger {
        var testMode: Bool { true }
        func log(
            event: String,
            info: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            print("[StepperInputAnalytics] \(event): info=\(info ?? [:]), role=\(role ?? "nil"), staffID=\(staffID ?? "nil"), context=\(context ?? "nil"), escalate=\(escalate)")
        }
        func recentEvents() -> [StepperInputAnalyticsEvent] {
            []
        }
    }
    struct PreviewWrapper: View {
        @State private var groomingDuration = 60
        @State private var quantity = 1

        var body: some View {
            Form {
                Section("Appointment Settings") {
                    StepperInputView(
                        label: "Duration (min)",
                        value: $groomingDuration,
                        range: 15...180,
                        step: 5,
                        auditTag: "appointment_duration"
                    )
                }

                Section("Inventory") {
                    StepperInputView(
                        label: "Shampoo Bottles",
                        value: $quantity,
                        range: 0...10,
                        auditTag: "inventory_quantity"
                    )
                }

                Section("Audit Events") {
                    List(StepperInputView.fetchRecentEvents()) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Event: \(event.event)")
                            Text("Timestamp: \(event.timestamp)")
                            Text("Role: \(event.role ?? "nil")")
                            Text("StaffID: \(event.staffID ?? "nil")")
                            Text("Context: \(event.context ?? "nil")")
                            Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            Text("Info: \(event.info ?? [:])")
                        }
                        .font(AppFonts.caption)
                        .padding(.vertical, 4)
                    }
                }
            }
            .font(AppFonts.body)
            .foregroundColor(AppColors.textPrimary)
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
        }
    }

    static var previews: some View {
        StepperInputView.analyticsLogger = SpyLogger()
        return PreviewWrapper()
    }
}
#endif

// MARK: - LocalizedStringKey -> String helper for logging

private extension LocalizedStringKey {
    var stringValue: String {
        let mirror = Mirror(reflecting: self)
        if let label = mirror.children.first(where: { $0.label == "key" })?.value as? String {
            return label
        }
        return "\(self)"
    }
}

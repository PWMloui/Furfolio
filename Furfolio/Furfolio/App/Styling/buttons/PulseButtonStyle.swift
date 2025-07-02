//
//  PulseButtonStyle.swift
//  Furfolio
//
//  Enhanced: Enterprise architecture, async/await analytics/audit/Trust Center ready, diagnostics, accessibility, localization, compliance, and preview/testable.
//  Last updated: 2025-06-27
//
/**
 # PulseButtonStyle Architecture & Compliance

 - **Architecture:** Token-based theming, diagnostics-ready, analytics/audit/Trust Center hooks, accessibility compliance, and modular for future extension.
 - **Extensibility:** Swap analytics logger, theming tokens, accessibility attributes, and haptics.
 - **Analytics/Audit:** Supports async/await analytics logger with testMode (console only for QA/tests/previews), capped event buffer (last 20), and public API.
 - **Diagnostics:** Recent event buffer for admin/diagnostic UI and log exporting.
 - **Localization/Compliance:** All user-facing/log event strings are localized via NSLocalizedString.
 - **Accessibility:** Full support for custom accessibility label/hint, decorative overlay marked hidden, .combine grouping.
 - **Preview/Test:** Null logger for test/preview, PreviewProvider demo with testMode and event inspection.
 */

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct PulseButtonAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "PulseButtonStyle"
}

// MARK: - Analytics/Audit Protocol

/// Analytics event struct for PulseButtonStyle audit logs.
public struct PulseButtonAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let color: Color
    public let pressed: Bool
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Analytics logger for PulseButtonStyle with async/await and testMode support.
public protocol PulseButtonAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, color: Color, pressed: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func recentEvents() -> [PulseButtonAnalyticsEvent]
}
public struct NullPulseButtonAnalyticsLogger: PulseButtonAnalyticsLogger {
    public init() {}
    public var testMode: Bool = false
    public func log(event: String, color: Color, pressed: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("[PulseButton][TESTMODE] event: \(event), color: \(color), pressed: \(pressed), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [PulseButtonAnalyticsEvent] { [] }
}

/// Default implementation with capped event buffer (last 20 events) and audit compliance.
public final class DefaultPulseButtonAnalyticsLogger: PulseButtonAnalyticsLogger {
    public var testMode: Bool = false
    private var buffer: [PulseButtonAnalyticsEvent] = []
    private let lock = NSLock()
    public init() {}
    public func log(event: String, color: Color, pressed: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let msg = String(
            format: NSLocalizedString("pulse_button_event_format",
                                      value: "%@ color:%@ pressed:%@",
                                      comment: "PulseButton event log format"),
            event, "\(color)", "\(pressed)"
        )
        let auditEvent = PulseButtonAnalyticsEvent(
            timestamp: Date(),
            event: msg,
            color: color,
            pressed: pressed,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        lock.lock()
        if buffer.count >= 20 { buffer.removeFirst() }
        buffer.append(auditEvent)
        lock.unlock()
        if testMode {
            print("[PulseButton][TESTMODE] event: \(auditEvent.event), color: \(auditEvent.color), pressed: \(auditEvent.pressed), role: \(auditEvent.role ?? "nil"), staffID: \(auditEvent.staffID ?? "nil"), context: \(auditEvent.context ?? "nil"), escalate: \(auditEvent.escalate)")
        }
    }
    public func recentEvents() -> [PulseButtonAnalyticsEvent] {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }
}

// MARK: - PulseButtonStyle

/// A button style that applies a pulsing animation when pressed, with shadow, haptics, audit/analytics, and token-based theming.
struct PulseButtonStyle: ButtonStyle {
    // MARK: - Theming Tokens (safe fallback)
    var color: Color = AppColors.accent ?? .accentColor
    var scale: CGFloat = AppSpacing.pulseButtonScale ?? 1.09
    var shadowColor: Color = (AppColors.accent ?? .accentColor).opacity(0.19)
    var shadowRadius: CGFloat = AppRadius.buttonShadow ?? 9
    var pulseDuration: Double = AppTheme.Animation.pulse ?? 0.21
    var useShadow: Bool = true
    var haptics: Bool = true
    var accessibilityLabel: String? = nil
    var accessibilityHint: String? = nil

    /// Analytics logger for QA/BI/Trust Center/compliance.
    var analyticsLogger: PulseButtonAnalyticsLogger = NullPulseButtonAnalyticsLogger()

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .scaleEffect(isPressed ? scale : 1.0)
            .shadow(
                color: isPressed && useShadow ? shadowColor : .clear,
                radius: shadowRadius,
                x: 0,
                y: 2
            )
            .animation(.easeOut(duration: pulseDuration), value: isPressed)
            .overlay(
                Circle()
                    .stroke(color.opacity(isPressed ? 0.28 : 0.0), lineWidth: isPressed ? 5 : 0)
                    .scaleEffect(isPressed ? 1.35 : 0.5)
                    .opacity(isPressed ? 0.9 : 0)
                    .animation(.easeOut(duration: 0.26), value: isPressed)
                    .accessibilityHidden(true) // Decorative only
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                accessibilityLabel != nil
                ? Text(NSLocalizedString(accessibilityLabel!, value: accessibilityLabel!, comment: "PulseButton accessibility label"))
                : nil
            )
            .accessibilityHint(
                accessibilityHint != nil
                ? Text(NSLocalizedString(accessibilityHint!, value: accessibilityHint!, comment: "PulseButton accessibility hint"))
                : nil
            )
            .onChange(of: isPressed) { pressed in
                Task {
                    if pressed && haptics {
                        PulseButtonStyle.triggerHaptic()
                    }
                    let lowercasedEvent = pressed ? "pulse_pressed" : "pulse_released"
                    let eventString = NSLocalizedString(lowercasedEvent, value: lowercasedEvent, comment: "PulseButton press/release event")
                    // Determine escalation based on event or accessibility label containing sensitive keywords
                    let combinedCheckString = (eventString + " " + (accessibilityLabel ?? "")).lowercased()
                    let escalate = combinedCheckString.contains("delete") || combinedCheckString.contains("danger") || combinedCheckString.contains("critical")
                    await analyticsLogger.log(
                        event: eventString,
                        color: color,
                        pressed: pressed,
                        role: PulseButtonAuditContext.role,
                        staffID: PulseButtonAuditContext.staffID,
                        context: PulseButtonAuditContext.context,
                        escalate: escalate
                    )
                }
            }
    }

    // MARK: - Haptic Feedback
    private static func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Diagnostics/Public API

#if DEBUG
struct PulseButtonStyle_Previews: PreviewProvider {
    class SpyLogger: PulseButtonAnalyticsLogger {
        var testMode: Bool = true
        private var buffer: [PulseButtonAnalyticsEvent] = []
        private let lock = NSLock()
        func log(event: String, color: Color, pressed: Bool, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let auditEvent = PulseButtonAnalyticsEvent(
                timestamp: Date(),
                event: event,
                color: color,
                pressed: pressed,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            lock.lock()
            if buffer.count >= 20 { buffer.removeFirst() }
            buffer.append(auditEvent)
            lock.unlock()
            print("[Spy] event: \(auditEvent.event), color: \(auditEvent.color), pressed: \(auditEvent.pressed), role: \(auditEvent.role ?? "nil"), staffID: \(auditEvent.staffID ?? "nil"), context: \(auditEvent.context ?? "nil"), escalate: \(auditEvent.escalate)")
        }
        func recentEvents() -> [PulseButtonAnalyticsEvent] {
            lock.lock(); defer { lock.unlock() }
            return buffer
        }
    }
    @State static var events: [PulseButtonAnalyticsEvent] = []

    static var previews: some View {
        let logger = SpyLogger()
        VStack(spacing: 32) {
            Button(NSLocalizedString("pulse_action", value: "Pulse Action", comment: "Pulse action button")) { }
                .buttonStyle(
                    PulseButtonStyle(
                        color: .pink,
                        accessibilityLabel: "pulse_action",
                        accessibilityHint: "pulse_action_hint",
                        analyticsLogger: logger
                    )
                )
                .font(.headline)
                .padding(.horizontal, 28)
                .padding(.vertical, 13)
                .background(Color.pink.opacity(0.12))
                .cornerRadius(13)

            Button {
            } label: {
                Label(
                    NSLocalizedString("confirm", value: "Confirm", comment: "Confirm label"),
                    systemImage: "checkmark.seal.fill"
                )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
            .buttonStyle(
                PulseButtonStyle(
                    color: .green,
                    scale: 1.12,
                    shadowColor: .green.opacity(0.22),
                    analyticsLogger: logger
                )
            )
            .background(Color.green.opacity(0.08))
            .cornerRadius(10)

            Button("Show Recent Analytics Events") {
                events = logger.recentEvents()
            }
            .padding(.top, 24)

            if !events.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Timestamp: \(event.timestamp.formatted(date: .numeric, time: .standard))")
                                    .font(.caption2)
                                Text("Event: \(event.event)")
                                    .font(.caption2)
                                Text("Color: \(event.color.description)")
                                    .font(.caption2)
                                Text("Pressed: \(event.pressed.description)")
                                    .font(.caption2)
                                Text("Role: \(event.role ?? "nil")")
                                    .font(.caption2)
                                Text("StaffID: \(event.staffID ?? "nil")")
                                    .font(.caption2)
                                Text("Context: \(event.context ?? "nil")")
                                    .font(.caption2)
                                Text("Escalate: \(event.escalate.description)")
                                    .font(.caption2)
                                Divider()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 130)
                .background(Color(.systemGray6))
                .cornerRadius(7)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif

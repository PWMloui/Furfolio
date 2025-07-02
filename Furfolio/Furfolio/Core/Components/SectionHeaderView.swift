//
//  SectionHeaderView.swift
//  Furfolio
//
//  Architecture & Extensibility:
//  SectionHeaderView is a highly extensible SwiftUI component designed for displaying section headers with optional trailing actions.
//  It supports comprehensive analytics and audit logging hooks, enabling integration with enterprise Trust Center requirements.
//
//  Analytics/Audit/Trust Center Hooks:
//  The component integrates an async/await-ready analytics logger protocol, allowing asynchronous logging of user interactions and rendering events.
//  It supports a testMode for console-only logging during QA, testing, and preview phases.
//  A capped internal buffer retains the last 20 analytics events for diagnostics and administrative review.
//
//  Diagnostics & Localization:
//  Analytics event strings and logs are fully localized using NSLocalizedString with appropriate keys and comments to support internationalization.
//  The component exposes a public API to fetch recent analytics events for diagnostics and Trust Center auditing.
//
//  Accessibility & Compliance:
//  Accessibility labels, traits, and hints are carefully applied to support VoiceOver and other assistive technologies.
//  The component ensures compliance with accessibility standards and enterprise UI guidelines.
//
//  Preview/Testability:
//  The PreviewProvider demonstrates the component’s usage with analytics logging, testMode toggling, accessibility features, and diagnostics buffer inspection.
//  This enables easy testing and verification of analytics, accessibility, and UI behavior in development environments.
//
//  Future maintainers are encouraged to extend the analytics logger protocol for custom backends and to use the diagnostics buffer for monitoring user interactions.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SectionHeaderAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SectionHeaderView"
}

// MARK: - Analytics/Audit Protocol

/// Protocol defining an asynchronous analytics logger for SectionHeaderView events.
/// Supports a testMode flag for console-only logging during QA/tests/previews.
public protocol SectionHeaderAnalyticsLogger {
    /// Indicates whether logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an event with optional info dictionary and audit fields.
    /// - Parameters:
    ///   - event: The event name to log.
    ///   - info: Optional dictionary with additional event information.
    ///   - role: Optional user/staff role.
    ///   - staffID: Optional staff/user ID.
    ///   - context: Optional UI or business context.
    ///   - escalate: Flag for critical/danger events.
    func log(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async
}

/// A no-op analytics logger used for previews and tests that do not require real logging.
public struct NullSectionHeaderAnalyticsLogger: SectionHeaderAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, info: [String : Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
}

// MARK: - SectionHeaderView (Enterprise Enhanced)

/// A SwiftUI view representing a section header with optional trailing action button.
/// Integrates asynchronous analytics logging, localization, accessibility, diagnostics, and audit context.
struct SectionHeaderView: View {
    /// The localized title to be displayed.
    let title: LocalizedStringKey

    /// The optional localized label for a trailing action button (e.g., "See All").
    var actionLabel: LocalizedStringKey? = nil

    /// The optional closure to be executed when the action button is tapped.
    var action: (() -> Void)? = nil

    /// Analytics logger instance (swap in QA/print/Trust Center/test implementations).
    static var analyticsLogger: SectionHeaderAnalyticsLogger = NullSectionHeaderAnalyticsLogger()

    /// Internal capped buffer holding the last 20 analytics events for diagnostics.
    @State private static var analyticsEventBuffer: [(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

    /// Maximum number of events to retain in the diagnostics buffer.
    private static let maxBufferSize = 20

    /// Public API to fetch recent analytics events for diagnostics or administrative review.
    public static func fetchRecentAnalyticsEvents() -> [(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] {
        return analyticsEventBuffer
    }

    /// Adds a new event to the analytics buffer, capping its size.
    private static func addEventToBuffer(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) {
        analyticsEventBuffer.append((event: event, info: info, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date()))
        if analyticsEventBuffer.count > maxBufferSize {
            analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - maxBufferSize)
        }
    }

    var body: some View {
        HStack {
            Text(title)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
                .textCase(.uppercase)
                .accessibilityLabel(Text("\(title) section header"))
                .accessibilityAddTraits(.isHeader)

            Spacer()

            if let actionLabel = actionLabel, let action = action {
                Button(action: {
                    Task {
                        let localizedEvent = NSLocalizedString(
                            "section_action_tapped",
                            value: "section_action_tapped",
                            comment: "Analytics event name for section action button tapped"
                        )
                        let info: [String: Any] = [
                            "title": "\(title)",
                            "actionLabel": "\(actionLabel)"
                        ]
                        let escalate = "\(actionLabel)".lowercased().contains("danger") || "\(actionLabel)".lowercased().contains("critical") || "\(actionLabel)".lowercased().contains("delete")
                        await Self.analyticsLogger.log(
                            event: localizedEvent,
                            info: info,
                            role: SectionHeaderAuditContext.role,
                            staffID: SectionHeaderAuditContext.staffID,
                            context: SectionHeaderAuditContext.context,
                            escalate: escalate
                        )
                        Self.addEventToBuffer(
                            event: localizedEvent,
                            info: info,
                            role: SectionHeaderAuditContext.role,
                            staffID: SectionHeaderAuditContext.staffID,
                            context: SectionHeaderAuditContext.context,
                            escalate: escalate
                        )
                        action()
                    }
                }) {
                    Text(actionLabel)
                        .font(AppFonts.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                        .padding(.leading, AppSpacing.small)
                }
                .accessibilityLabel(Text(actionLabel))
                .accessibilityHint(Text(String(format: NSLocalizedString(
                    "tap_to_action_label",
                    value: "Tap to %@.",
                    comment: "Accessibility hint for action button"
                ), "\(actionLabel)")))
            }
        }
        .padding(.bottom, AppSpacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SectionHeaderView_\(title)")
        .onAppear {
            Task {
                let localizedEvent = NSLocalizedString(
                    "section_header_rendered",
                    value: "section_header_rendered",
                    comment: "Analytics event name for section header rendered"
                )
                let actionLabelString = actionLabel != nil ? "\(actionLabel!)" : nil
                let info: [String: Any] = [
                    "title": "\(title)",
                    "actionLabel": actionLabelString as Any
                ]
                let escalate = actionLabelString?.lowercased().contains("danger") == true ||
                               actionLabelString?.lowercased().contains("critical") == true ||
                               actionLabelString?.lowercased().contains("delete") == true
                await Self.analyticsLogger.log(
                    event: localizedEvent,
                    info: info,
                    role: SectionHeaderAuditContext.role,
                    staffID: SectionHeaderAuditContext.staffID,
                    context: SectionHeaderAuditContext.context,
                    escalate: escalate
                )
                Self.addEventToBuffer(
                    event: localizedEvent,
                    info: info,
                    role: SectionHeaderAuditContext.role,
                    staffID: SectionHeaderAuditContext.staffID,
                    context: SectionHeaderAuditContext.context,
                    escalate: escalate
                )
            }
        }
    }
}

// MARK: - Preview with analytics logger, testMode, accessibility, and diagnostics buffer

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
    /// Spy logger that prints logs to console and supports testMode.
    struct SpyLogger: SectionHeaderAnalyticsLogger {
        let testMode: Bool

        func log(event: String, info: [String : Any]?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            if testMode {
                print("[SectionHeaderAnalytics - TEST MODE] \(event): \(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
            } else {
                print("[SectionHeaderAnalytics] \(event): \(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
            }
        }
    }

    /// A view to display recent analytics events for diagnostics in the preview.
    struct AnalyticsDiagnosticsView: View {
        @State private var recentEvents: [(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Analytics Events:")
                    .font(.headline)
                if recentEvents.isEmpty {
                    Text("No events logged yet.")
                        .italic()
                } else {
                    ScrollView {
                        ForEach(Array(recentEvents.enumerated()), id: \.offset) { index, eventTuple in
                            VStack(alignment: .leading) {
                                Text("\(index + 1). \(eventTuple.event)")
                                    .fontWeight(.semibold)
                                if let info = eventTuple.info {
                                    Text("Info: \(info.description)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                HStack {
                                    Text("role: \(eventTuple.role ?? "-")")
                                    Text("staffID: \(eventTuple.staffID ?? "-")")
                                    Text("context: \(eventTuple.context ?? "-")")
                                    Text("escalate: \(eventTuple.escalate ? "YES" : "NO")")
                                }
                                .font(.caption2)
                                .foregroundColor(.gray)
                                Text(eventTuple.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .frame(maxHeight: 180)
                }
                Button("Refresh Events") {
                    recentEvents = SectionHeaderView.fetchRecentAnalyticsEvents()
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Analytics diagnostics view"))
        }
    }

    static var previews: some View {
        // Set analytics logger with testMode enabled for console logging.
        SectionHeaderView.analyticsLogger = SpyLogger(testMode: true)

        return Form {
            Section(
                header: SectionHeaderView(title: "Upcoming Appointments")
            ) {
                Text("Appointment 1 Row")
                Text("Appointment 2 Row")
            }

            Section(
                header: SectionHeaderView(title: "Recent Activity", actionLabel: "See All") {
                    print("See All tapped!")
                }
            ) {
                Text("Activity 1 Row")
                Text("Activity 2 Row")
            }

            Section(header: Text("Diagnostics")) {
                AnalyticsDiagnosticsView()
            }
        }
        .previewLayout(.sizeThatFits)
        .accessibilityElement(children: .contain)
    }
}
#endif

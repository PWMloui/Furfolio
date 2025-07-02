/**
 CustomerRetentionAnalyzer.swift
 Furfolio

 # Architecture Overview

 `CustomerRetentionAnalyzer` is a centralized, extensible, and audit/analytics–ready service for client retention analysis in Furfolio. It provides:
 - **Core Analysis**: Classifies clients into retention tags (e.g., new, active, at risk, inactive, returning) based on appointment history and configurable thresholds.
 - **Extensibility**: All analytics, audit, and Trust Center hooks are protocol-based and injectable for testability, previews, and compliance.
 - **Analytics/Audit/Trust Center Hooks**: All significant analysis and filtering actions are logged via the `RetentionAnalyticsLogger` protocol, which is async/await–ready and supports diagnostics buffers and test/preview modes.
 - **Diagnostics/Buffering**: The last 20 analytics events are buffered and accessible for admin/diagnostics.
 - **Localization**: All user-facing and log event strings are fully localized using `NSLocalizedString` with descriptive keys, values, and comments for compliance and internationalization.
 - **Accessibility**: Designed for use with SwiftUI, supporting accessibility in previews and diagnostics.
 - **Compliance**: Trust Center permission checks are enforced before remote data access; all analytics are compliant with audit/trust requirements.
 - **Preview/Testability**: Null and test loggers are provided for previews, QA, and test harnesses. The PreviewProvider demonstrates analytics logging, diagnostics, testMode, and accessibility.

 # For Future Maintainers
 - **Add new analytics hooks**: Conform to the `RetentionAnalyticsLogger` protocol and inject via `CustomerRetentionAnalyzer.analyticsLogger`.
 - **Diagnostics**: Use `CustomerRetentionAnalyzer.shared.recentAnalyticsEvents` to fetch the last 20 analytics events for admin/diagnostics UIs.
 - **Localization**: All log/event/user-facing strings must use `NSLocalizedString` with a descriptive key, value, and comment.
 - **Accessibility**: When adding UI, use `.accessibilityLabel`, `.accessibilityValue`, etc., and ensure diagnostics are readable.
 - **Testing/Preview**: Use `NullRetentionAnalyticsLogger` or set `testMode = true` on the logger for console-only, non-persistent logging.
 - **Compliance**: All remote or sensitive actions must use the Trust Center permission hook.
 - **Extending**: To add new retention tags or business rules, update `RetentionTag` and the analysis logic, ensuring all analytics logging is updated and localized.
*/

//
//  CustomerRetentionAnalyzer.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–compliant, preview/test–injectable, token-compliant, BI-ready.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct RetentionAnalyzerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "CustomerRetentionAnalyzer"
}

// MARK: - Audit/Analytics Protocol

/// Protocol for analytics/audit logging of retention events, now with trust center context/escalate.
public protocol RetentionAnalyticsLogger: AnyObject {
    /// Set to true to enable test/QA/preview mode (console-only, no persistent logging).
    var testMode: Bool { get set }
    /// Log an analytics event. Should be async/await–ready.
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// Null logger (no-op) for previews/tests.
public final class NullRetentionAnalyticsLogger: RetentionAnalyticsLogger {
    public init() {}
    public var testMode: Bool = false
    public func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[NullRetentionAnalyticsLogger] \(event) info:\(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - RetentionResult

public struct RetentionResult {
    public let tag: RetentionTag
    public let daysSinceLastVisit: Int?
}

// MARK: - RetentionError

public enum RetentionError: Error {
    case remoteFetchNotImplemented
    case permissionDenied
}

// MARK: - CustomerRetentionAnalyzer
@MainActor
public final class CustomerRetentionAnalyzer {
    /// Shared singleton instance for app-wide use
    public static let shared = CustomerRetentionAnalyzer()

    /// Analytics logger (injectable for test/preview/diagnostics)
    public static var analyticsLogger: RetentionAnalyticsLogger = NullRetentionAnalyticsLogger()

    /// Capped buffer for recent analytics events (last 20)
    private(set) public var recentAnalyticsEvents: [(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] = []
    private let analyticsEventBufferLimit = 20

    /// Trust Center permission check closure. Return false to deny.
    public var trustCenterPermissionCheck: ((_ action: String, _ context: [String: Any]?) -> Bool)? = nil

    /// Deprecated audit log hook. Use analyticsLogger instead.
    @available(*, deprecated, message: "Use analyticsLogger protocol instead.")
    public var auditLogHook: ((String, [String: Any]?, Error?) -> Void)?

    private init() {}

    // MARK: - Thresholds (tokenized, single source)
    public struct Thresholds {
        public static var newClientDays: Int = 14
        public static var retentionRiskDays: Int = 60
        public static var inactiveDays: Int = 180
        public static var activeDays: Int = 30
    }

    // MARK: - Analytics Logging Helper
    /// Logs an analytics event and appends to diagnostics buffer, with trust center/audit fields.
    @discardableResult
    public func logAnalyticsEvent(
        _ event: String,
        info: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        // Escalate if "critical", "danger", or "delete" appear in event or info
        let lowerEvent = event.lowercased()
        let infoString = info?.description.lowercased() ?? ""
        let shouldEscalate = escalate ||
            lowerEvent.contains("critical") || lowerEvent.contains("danger") || lowerEvent.contains("delete") ||
            infoString.contains("critical") || infoString.contains("danger") || infoString.contains("delete")
        let roleVal = role ?? RetentionAnalyzerAuditContext.role
        let staffVal = staffID ?? RetentionAnalyzerAuditContext.staffID
        let ctxVal = context ?? RetentionAnalyzerAuditContext.context
        let timestamp = Date()
        if recentAnalyticsEvents.count >= analyticsEventBufferLimit {
            recentAnalyticsEvents.removeFirst()
        }
        recentAnalyticsEvents.append((event: event, info: info, role: roleVal, staffID: staffVal, context: ctxVal, escalate: shouldEscalate, timestamp: timestamp))
        await Self.analyticsLogger.log(event: event, info: info, role: roleVal, staffID: staffVal, context: ctxVal, escalate: shouldEscalate)
    }

    /// Public API to fetch recent analytics events (for admin/diagnostics) with audit fields.
    public func getRecentAnalyticsEvents() -> [(event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool, timestamp: Date)] {
        return recentAnalyticsEvents
    }

    // MARK: - Core Analysis Logic
    /**
     Returns the retention tag for the given owner, logging analytics and diagnostics.
     - Parameter owner: The dog owner to analyze.
     - Returns: The calculated RetentionTag.
     */
    public func retentionTag(for owner: DogOwner) -> RetentionTag {
        Task { @MainActor in
            // A newly added owner with no appointments is considered a new client.
            guard let lastAppointmentDate = owner.lastAppointmentDate else {
                await self.logAnalyticsEvent(
                    NSLocalizedString("retentionTag_newClient",
                        value: "New client identified (no appointments)",
                        comment: "Analytics: Owner classified as new client (no appointments)"),
                    info: [
                        NSLocalizedString("owner", value: "Owner", comment: "Analytics: Owner name key"): owner.ownerName,
                        NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key"): RetentionTag.newClient.rawValue
                    ]
                    // audit fields default
                )
                return
            }

            let daysSinceLastAppointment = Calendar.current.dateComponents([.day], from: lastAppointmentDate, to: Date()).day ?? 0

            // Log analysis details for BI/audit
            var eventInfo: [String: Any] = [
                NSLocalizedString("owner", value: "Owner", comment: "Analytics: Owner name key"): owner.ownerName,
                NSLocalizedString("daysSinceLastAppointment", value: "Days Since Last Appointment", comment: "Analytics: Days since last appointment key"): daysSinceLastAppointment,
                NSLocalizedString("appointmentCount", value: "Appointment Count", comment: "Analytics: Appointment count key"): owner.appointments.count
            ]

            // Check statuses in order of precedence (inactive > risk > new > active > returning).
            if daysSinceLastAppointment > Thresholds.inactiveDays {
                eventInfo[NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key")] = RetentionTag.inactive.rawValue
                await self.logAnalyticsEvent(
                    NSLocalizedString("retentionTag_inactive",
                        value: "Owner marked as inactive",
                        comment: "Analytics: Owner classified as inactive"),
                    info: eventInfo
                )
                return
            }
            if daysSinceLastAppointment > Thresholds.retentionRiskDays {
                eventInfo[NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key")] = RetentionTag.retentionRisk.rawValue
                await self.logAnalyticsEvent(
                    NSLocalizedString("retentionTag_risk",
                        value: "Owner at retention risk",
                        comment: "Analytics: Owner classified as retention risk"),
                    info: eventInfo
                )
                return
            }
            if owner.appointments.count <= 1 && daysSinceLastAppointment <= Thresholds.newClientDays {
                eventInfo[NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key")] = RetentionTag.newClient.rawValue
                await self.logAnalyticsEvent(
                    NSLocalizedString("retentionTag_newClient_recent",
                        value: "New client (recent appointment)",
                        comment: "Analytics: Owner classified as new client (recent)"),
                    info: eventInfo
                )
                return
            }
            if daysSinceLastAppointment <= Thresholds.activeDays {
                eventInfo[NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key")] = RetentionTag.active.rawValue
                await self.logAnalyticsEvent(
                    NSLocalizedString("retentionTag_active",
                        value: "Owner is active",
                        comment: "Analytics: Owner classified as active"),
                    info: eventInfo
                )
                return
            }
            eventInfo[NSLocalizedString("tag", value: "Tag", comment: "Analytics: Retention tag key")] = RetentionTag.returning.rawValue
            await self.logAnalyticsEvent(
                NSLocalizedString("retentionTag_returning",
                    value: "Owner is returning",
                    comment: "Analytics: Owner classified as returning"),
                info: eventInfo
            )
        }
        // Synchronous return for compatibility (actual analytics is async)
        guard let lastAppointmentDate = owner.lastAppointmentDate else { return .newClient }
        let daysSinceLastAppointment = Calendar.current.dateComponents([.day], from: lastAppointmentDate, to: Date()).day ?? 0
        if daysSinceLastAppointment > Thresholds.inactiveDays { return .inactive }
        if daysSinceLastAppointment > Thresholds.retentionRiskDays { return .retentionRisk }
        if owner.appointments.count <= 1 && daysSinceLastAppointment <= Thresholds.newClientDays { return .newClient }
        if daysSinceLastAppointment <= Thresholds.activeDays { return .active }
        return .returning
    }

    // MARK: - Batch Analytics & Filtering
    /**
     Filters owners by retention tag and logs analytics.
     - Parameters:
       - owners: List of owners.
       - tag: Tag to filter by.
     - Returns: Filtered owners.
     */
    public func filterOwners(in owners: [DogOwner], by tag: RetentionTag) -> [DogOwner] {
        let filtered = owners.filter { retentionTag(for: $0) == tag }
        Task { @MainActor in
            await self.logAnalyticsEvent(
                NSLocalizedString("filterOwners",
                    value: "Filtered owners by tag",
                    comment: "Analytics: Owners filtered by retention tag"),
                info: [
                    NSLocalizedString("filterTag", value: "Filter Tag", comment: "Analytics: Filter tag key"): tag.rawValue,
                    NSLocalizedString("filteredCount", value: "Filtered Count", comment: "Analytics: Filtered count key"): filtered.count
                ]
            )
        }
        return filtered
    }

    /**
     Returns stats (counts) for each retention tag, with analytics logging.
     - Parameter owners: List of owners to analyze.
     - Returns: Dictionary of tag counts.
     */
    public func retentionStats(for owners: [DogOwner]) -> [RetentionTag: Int] {
        var stats: [RetentionTag: Int] = [:]
        for owner in owners {
            let tag = retentionTag(for: owner)
            stats[tag, default: 0] += 1
        }
        Task { @MainActor in
            await self.logAnalyticsEvent(
                NSLocalizedString("retentionStats",
                    value: "Retention stats calculated",
                    comment: "Analytics: Retention stats calculated"),
                info: stats.mapValues { $0 }
            )
        }
        return stats
    }

    /**
     Returns owners at retention risk, with analytics logging.
     - Parameter owners: List of owners.
     - Returns: Owners at risk.
     */
    public func ownersAtRisk(in owners: [DogOwner]) -> [DogOwner] {
        let atRisk = filterOwners(in: owners, by: .retentionRisk)
        Task { @MainActor in
            await self.logAnalyticsEvent(
                NSLocalizedString("ownersAtRisk",
                    value: "Owners at retention risk",
                    comment: "Analytics: Owners at retention risk"),
                info: [NSLocalizedString("count", value: "Count", comment: "Analytics: Count key"): atRisk.count]
            )
        }
        return atRisk
    }

    /**
     Returns inactive owners, with analytics logging.
     - Parameter owners: List of owners.
     - Returns: Inactive owners.
     */
    public func inactiveOwners(in owners: [DogOwner]) -> [DogOwner] {
        let inactive = filterOwners(in: owners, by: .inactive)
        Task { @MainActor in
            await self.logAnalyticsEvent(
                NSLocalizedString("inactiveOwners",
                    value: "Inactive owners",
                    comment: "Analytics: Inactive owners"),
                info: [NSLocalizedString("count", value: "Count", comment: "Analytics: Count key"): inactive.count]
            )
        }
        return inactive
    }

    /**
     Returns new client owners, with analytics logging.
     - Parameter owners: List of owners.
     - Returns: New client owners.
     */
    public func newClientOwners(in owners: [DogOwner]) -> [DogOwner] {
        let newClients = filterOwners(in: owners, by: .newClient)
        Task { @MainActor in
            await self.logAnalyticsEvent(
                NSLocalizedString("newClientOwners",
                    value: "New client owners",
                    comment: "Analytics: New client owners"),
                info: [NSLocalizedString("count", value: "Count", comment: "Analytics: Count key"): newClients.count]
            )
        }
        return newClients
    }

    // MARK: - Remote Analytics (Trust Center/permission-aware, async/await)
    /**
     Fetches remote retention data for a business, enforcing Trust Center permission and analytics logging.
     - Parameter businessId: The business identifier.
     - Throws: RetentionError.permissionDenied or .remoteFetchNotImplemented.
     - Returns: List of DogOwner (future).
     */
    public func fetchRemoteRetentionData(for businessId: String) async throws -> [DogOwner] {
        // Permission check (Trust Center)
        if let permission = trustCenterPermissionCheck, !permission("fetchRemoteRetentionData", ["businessId": businessId]) {
            await self.logAnalyticsEvent(
                NSLocalizedString("remoteFetch_permissionDenied",
                    value: "Remote fetch permission denied",
                    comment: "Analytics: Remote retention fetch permission denied"),
                info: [NSLocalizedString("businessId", value: "Business ID", comment: "Analytics: Business ID key"): businessId]
            )
            throw RetentionError.permissionDenied
        }
        await self.logAnalyticsEvent(
            NSLocalizedString("fetchRemoteRetentionData_invoked",
                value: "Remote retention data fetch invoked",
                comment: "Analytics: Remote retention data fetch invoked"),
            info: [NSLocalizedString("businessId", value: "Business ID", comment: "Analytics: Business ID key"): businessId]
        )
        // TODO: Implement secure, localized remote fetch logic (ensure audit logging and Trust Center permissions)
        throw RetentionError.remoteFetchNotImplemented
    }
}

// MARK: - SwiftUI Preview (Enhanced for diagnostics/audit context)

#if DEBUG
import SwiftUI

/// Async/await–ready logger for QA/tests/previews. Logs to console only if testMode is true.
@available(iOS 18.0, *)
final class ConsoleSpyLogger: RetentionAnalyticsLogger {
    var testMode: Bool = false
    @MainActor
    func log(
        event: String,
        info: [String : Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[RetentionAnalytics][TESTMODE] \(event): \(info ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        } else {
            print("[RetentionAnalytics] \(event): \(info ?? [:])")
        }
    }
}

@available(iOS 18.0, *)
struct CustomerRetentionAnalyzer_Previews: PreviewProvider {
    static var previews: some View {
        // Use testMode logger for preview
        let logger = ConsoleSpyLogger()
        logger.testMode = true
        CustomerRetentionAnalyzer.analyticsLogger = logger
        let analyzer = CustomerRetentionAnalyzer.shared
        let container = try! ModelContainer(for: [DogOwner.self, Appointment.self], inMemory: true)

        // Create sample owners
        let newOwner = DogOwner(ownerName: NSLocalizedString("preview_newOwner", value: "New Owner", comment: "Preview new owner name"))
        newOwner.appointments = [Appointment(date: Date().addingTimeInterval(-5 * 86400), serviceType: .basicBath, owner: newOwner)]

        let activeOwner = DogOwner(ownerName: NSLocalizedString("preview_activeOwner", value: "Active Owner", comment: "Preview active owner name"))
        activeOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: activeOwner),
            Appointment(date: Date().addingTimeInterval(-20 * 86400), serviceType: .fullGroom, owner: activeOwner)
        ]

        let riskOwner = DogOwner(ownerName: NSLocalizedString("preview_riskOwner", value: "Risk Owner", comment: "Preview risk owner name"))
        riskOwner.appointments = [Appointment(date: Date().addingTimeInterval(-75 * 86400), serviceType: .nailTrim, owner: riskOwner)]

        let inactiveOwner = DogOwner(ownerName: NSLocalizedString("preview_inactiveOwner", value: "Inactive Owner", comment: "Preview inactive owner name"))
        inactiveOwner.appointments = [Appointment(date: Date().addingTimeInterval(-200 * 86400), serviceType: .fullGroom, owner: inactiveOwner)]

        let returningOwner = DogOwner(ownerName: NSLocalizedString("preview_returningOwner", value: "Returning Owner", comment: "Preview returning owner name"))
        returningOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: returningOwner),
            Appointment(date: Date().addingTimeInterval(-45 * 86400), serviceType: .fullGroom, owner: returningOwner)
        ]

        let allOwners = [newOwner, activeOwner, riskOwner, inactiveOwner, returningOwner]
        let stats = analyzer.retentionStats(for: allOwners)

        return VStack(alignment: .leading, spacing: 16) {
            Text(NSLocalizedString("preview_retentionAnalysisResults", value: "Retention Analysis Results", comment: "Preview: Retention analysis results header"))
                .font(AppTheme.Fonts.title)
                .padding(.bottom)
                .accessibilityLabel(Text(NSLocalizedString("accessibility_retentionAnalysisHeader", value: "Retention Analysis Results", comment: "Accessibility: Retention analysis results header")))

            ForEach(RetentionTag.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { tag in
                HStack {
                    RetentionTagView(tag: tag)
                        .accessibilityLabel(Text(NSLocalizedString("accessibility_retentionTag", value: "Retention Tag", comment: "Accessibility: Retention tag label")) + Text(": ") + Text(tag.rawValue))
                    Spacer()
                    Text("\(stats[tag] ?? 0) " + NSLocalizedString("preview_clients", value: "client(s)", comment: "Preview: clients plural"))
                        .font(AppTheme.Fonts.body)
                        .accessibilityValue(Text("\(stats[tag] ?? 0)"))
                }
            }
            Divider()
            // Diagnostics buffer preview: show all audit fields for each event
            Text(NSLocalizedString("preview_diagnosticsBuffer", value: "Analytics Diagnostics Buffer (last 20 events):", comment: "Preview: Analytics diagnostics buffer header"))
                .font(.subheadline)
                .accessibilityLabel(Text(NSLocalizedString("accessibility_diagnosticsBufferHeader", value: "Analytics Diagnostics Buffer", comment: "Accessibility: Analytics diagnostics buffer header")))
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(analyzer.getRecentAnalyticsEvents().enumerated().map({ $0 }), id: \.offset) { idx, tuple in
                        Text("\(idx + 1). [\(tuple.timestamp)] \(tuple.event) \(tuple.info.map { "\($0)" } ?? "") role:\(tuple.role ?? "-") staffID:\(tuple.staffID ?? "-") context:\(tuple.context ?? "-") escalate:\(tuple.escalate)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("\(idx + 1). \(tuple.event)"))
                    }
                }
            }
            .frame(maxHeight: 180)
            .accessibilityElement(children: .contain)
            // Show testMode state
            HStack {
                Text(NSLocalizedString("preview_testMode", value: "Test Mode:", comment: "Preview: Test mode label"))
                    .bold()
                Text(logger.testMode ? NSLocalizedString("preview_enabled", value: "Enabled", comment: "Preview: Test mode enabled") : NSLocalizedString("preview_disabled", value: "Disabled", comment: "Preview: Test mode disabled"))
                    .foregroundColor(logger.testMode ? .green : .red)
                    .accessibilityValue(Text(logger.testMode ? NSLocalizedString("preview_enabled", value: "Enabled", comment: "Preview: Test mode enabled") : NSLocalizedString("preview_disabled", value: "Disabled", comment: "Preview: Test mode disabled")))
            }
            .accessibilityElement(children: .combine)
        }
        .padding()
        .modelContainer(container)
        .accessibilityElement(children: .contain)
    }
}
#endif

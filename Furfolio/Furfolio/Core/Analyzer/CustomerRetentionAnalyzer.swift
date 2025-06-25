//
//  CustomerRetentionAnalyzer.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–compliant, preview/test–injectable, token-compliant, BI-ready.
//

import Foundation

// MARK: - Audit/Analytics Protocol

public protocol RetentionAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullRetentionAnalyticsLogger: RetentionAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
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

    // MARK: - Singleton Instance

    public static let shared = CustomerRetentionAnalyzer()

    private init() {}

    // MARK: - Analytics Logger

    public static var analyticsLogger: RetentionAnalyticsLogger = NullRetentionAnalyticsLogger()

    // MARK: - Thresholds (tokenized, single source)

    public struct Thresholds {
        public static var newClientDays: Int = 14
        public static var retentionRiskDays: Int = 60
        public static var inactiveDays: Int = 180
        public static var activeDays: Int = 30
    }

    // MARK: - Trust Center Permission Hook (audit/role/permission)

    public var trustCenterPermissionCheck: ((_ action: String, _ context: [String: Any]?) -> Bool)? = nil

    // MARK: - Audit Log Hook (deprecated, use analyticsLogger)

    @available(*, deprecated, message: "Use analyticsLogger protocol instead.")
    public var auditLogHook: ((String, [String: Any]?, Error?) -> Void)?

    // MARK: - Core Analysis Logic

    public func retentionTag(for owner: DogOwner) -> RetentionTag {
        // A newly added owner with no appointments is considered a new client.
        guard let lastAppointmentDate = owner.lastAppointmentDate else {
            Self.analyticsLogger.log(event: "retentionTag_newClient", info: [
                "owner": owner.ownerName,
                "tag": RetentionTag.newClient.rawValue
            ])
            return .newClient
        }

        let daysSinceLastAppointment = Calendar.current.dateComponents([.day], from: lastAppointmentDate, to: Date()).day ?? 0

        // Log analysis details for BI/audit
        var eventInfo: [String: Any] = [
            "owner": owner.ownerName,
            "daysSinceLastAppointment": daysSinceLastAppointment,
            "appointmentCount": owner.appointments.count
        ]

        // Check statuses in order of precedence (inactive > risk > new > active > returning).
        if daysSinceLastAppointment > Thresholds.inactiveDays {
            eventInfo["tag"] = RetentionTag.inactive.rawValue
            Self.analyticsLogger.log(event: "retentionTag_inactive", info: eventInfo)
            return .inactive
        }

        if daysSinceLastAppointment > Thresholds.retentionRiskDays {
            eventInfo["tag"] = RetentionTag.retentionRisk.rawValue
            Self.analyticsLogger.log(event: "retentionTag_risk", info: eventInfo)
            return .retentionRisk
        }

        if owner.appointments.count <= 1 && daysSinceLastAppointment <= Thresholds.newClientDays {
            eventInfo["tag"] = RetentionTag.newClient.rawValue
            Self.analyticsLogger.log(event: "retentionTag_newClient_recent", info: eventInfo)
            return .newClient
        }

        if daysSinceLastAppointment <= Thresholds.activeDays {
            eventInfo["tag"] = RetentionTag.active.rawValue
            Self.analyticsLogger.log(event: "retentionTag_active", info: eventInfo)
            return .active
        }

        eventInfo["tag"] = RetentionTag.returning.rawValue
        Self.analyticsLogger.log(event: "retentionTag_returning", info: eventInfo)
        return .returning
    }

    // MARK: - Batch Analytics & Filtering

    public func filterOwners(in owners: [DogOwner], by tag: RetentionTag) -> [DogOwner] {
        let filtered = owners.filter { retentionTag(for: $0) == tag }
        Self.analyticsLogger.log(event: "filterOwners", info: [
            "filterTag": tag.rawValue,
            "filteredCount": filtered.count
        ])
        return filtered
    }

    public func retentionStats(for owners: [DogOwner]) -> [RetentionTag: Int] {
        var stats: [RetentionTag: Int] = [:]
        for owner in owners {
            let tag = retentionTag(for: owner)
            stats[tag, default: 0] += 1
        }
        Self.analyticsLogger.log(event: "retentionStats", info: stats.mapValues { $0 })
        return stats
    }

    public func ownersAtRisk(in owners: [DogOwner]) -> [DogOwner] {
        let atRisk = filterOwners(in: owners, by: .retentionRisk)
        Self.analyticsLogger.log(event: "ownersAtRisk", info: ["count": atRisk.count])
        return atRisk
    }

    public func inactiveOwners(in owners: [DogOwner]) -> [DogOwner] {
        let inactive = filterOwners(in: owners, by: .inactive)
        Self.analyticsLogger.log(event: "inactiveOwners", info: ["count": inactive.count])
        return inactive
    }

    public func newClientOwners(in owners: [DogOwner]) -> [DogOwner] {
        let newClients = filterOwners(in: owners, by: .newClient)
        Self.analyticsLogger.log(event: "newClientOwners", info: ["count": newClients.count])
        return newClients
    }

    // MARK: - Remote Analytics (Trust Center/permission-aware, async/await)

    public func fetchRemoteRetentionData(for businessId: String) async throws -> [DogOwner] {
        // Permission check (Trust Center)
        if let permission = trustCenterPermissionCheck, !permission("fetchRemoteRetentionData", ["businessId": businessId]) {
            Self.analyticsLogger.log(event: "remoteFetch_permissionDenied", info: ["businessId": businessId])
            throw RetentionError.permissionDenied
        }
        Self.analyticsLogger.log(event: "fetchRemoteRetentionData_invoked", info: ["businessId": businessId])
        // TODO: Implement secure, localized remote fetch logic (ensure audit logging and Trust Center permissions)
        throw RetentionError.remoteFetchNotImplemented
    }
}

// MARK: - SwiftUI Preview (Unchanged, add analytics logger for QA/print)

#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
struct CustomerRetentionAnalyzer_Previews: PreviewProvider {
    struct SpyLogger: RetentionAnalyticsLogger {
        func log(event: String, info: [String : Any]?) {
            print("[RetentionAnalytics] \(event): \(info ?? [:])")
        }
    }
    static var previews: some View {
        CustomerRetentionAnalyzer.analyticsLogger = SpyLogger()
        // ... (rest of preview unchanged)
        let container = try! ModelContainer(for: [DogOwner.self, Appointment.self], inMemory: true)
        
        let analyzer = CustomerRetentionAnalyzer.shared

        // Create sample owners
        let newOwner = DogOwner(ownerName: "New Owner")
        newOwner.appointments = [Appointment(date: Date().addingTimeInterval(-5 * 86400), serviceType: .basicBath, owner: newOwner)]
        
        let activeOwner = DogOwner(ownerName: "Active Owner")
        activeOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: activeOwner),
            Appointment(date: Date().addingTimeInterval(-20 * 86400), serviceType: .fullGroom, owner: activeOwner)
        ]
        
        let riskOwner = DogOwner(ownerName: "Risk Owner")
        riskOwner.appointments = [Appointment(date: Date().addingTimeInterval(-75 * 86400), serviceType: .nailTrim, owner: riskOwner)]
        
        let inactiveOwner = DogOwner(ownerName: "Inactive Owner")
        inactiveOwner.appointments = [Appointment(date: Date().addingTimeInterval(-200 * 86400), serviceType: .fullGroom, owner: inactiveOwner)]
        
        let returningOwner = DogOwner(ownerName: "Returning Owner")
        returningOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: returningOwner),
            Appointment(date: Date().addingTimeInterval(-45 * 86400), serviceType: .fullGroom, owner: returningOwner)
        ]

        let allOwners = [newOwner, activeOwner, riskOwner, inactiveOwner, returningOwner]
        let stats = analyzer.retentionStats(for: allOwners)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Retention Analysis Results")
                .font(AppTheme.Fonts.title)
                .padding(.bottom)

            ForEach(RetentionTag.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { tag in
                HStack {
                    RetentionTagView(tag: tag)
                    Spacer()
                    Text("\(stats[tag] ?? 0) client(s)")
                        .font(AppTheme.Fonts.body)
                }
            }
        }
        .padding()
        .modelContainer(container)
    }
}
#endif

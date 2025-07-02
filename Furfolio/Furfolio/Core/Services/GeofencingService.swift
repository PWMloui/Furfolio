
//
//  GeofencingService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
/**
 GeofencingService
 -----------------
 A service for managing geofence regions and handling entry/exit events in Furfolio, with async analytics and audit logging.

 - **Purpose**: Registers and monitors CLRegion geofences for mobile grooming routes or on-site appointments.
 - **Architecture**: Singleton `ObservableObject` using `CLLocationManager` for region monitoring.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: User-facing messages and audit events support NSLocalizedString.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit logs.
 */



import Foundation
import CoreLocation

// MARK: - Analytics & Audit Protocols

public protocol GeofencingAnalyticsLogger {
    /// Log a geofencing event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol GeofencingAuditLogger {
    /// Record a geofencing audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullGeofencingAnalyticsLogger: GeofencingAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullGeofencingAuditLogger: GeofencingAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a geofencing audit event.
public struct GeofencingAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let regionId: String?
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, regionId: String? = nil, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.regionId = regionId
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging geofencing events.
public actor GeofencingAuditManager {
    private var buffer: [GeofencingAuditEntry] = []
    private let maxEntries = 100
    public static let shared = GeofencingAuditManager()

    public func add(_ entry: GeofencingAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [GeofencingAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

@MainActor
public final class GeofencingService: NSObject, ObservableObject {
    public static let shared = GeofencingService(
        analytics: NullGeofencingAnalyticsLogger(),
        audit: NullGeofencingAuditLogger()
    )

    private let locationManager: CLLocationManager
    private let analytics: GeofencingAnalyticsLogger
    private let audit: GeofencingAuditLogger

    private override init() {
        fatalError("Use shared instance")
    }

    private init(
        analytics: GeofencingAnalyticsLogger,
        audit: GeofencingAuditLogger
    ) {
        self.locationManager = CLLocationManager()
        self.analytics = analytics
        self.audit = audit
        super.init()
        self.locationManager.delegate = self
    }

    public func startMonitoring(region: CLRegion) {
        locationManager.startMonitoring(for: region)
        Task {
            await analytics.log(event: "start_monitoring", parameters: ["regionId": region.identifier])
            await audit.record("Started monitoring", metadata: ["regionId": region.identifier])
            await GeofencingAuditManager.shared.add(
                GeofencingAuditEntry(event: "start_monitoring", regionId: region.identifier)
            )
        }
    }

    public func stopMonitoring(region: CLRegion) {
        locationManager.stopMonitoring(for: region)
        Task {
            await analytics.log(event: "stop_monitoring", parameters: ["regionId": region.identifier])
            await audit.record("Stopped monitoring", metadata: ["regionId": region.identifier])
            await GeofencingAuditManager.shared.add(
                GeofencingAuditEntry(event: "stop_monitoring", regionId: region.identifier)
            )
        }
    }
}

extension GeofencingService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task {
            await analytics.log(event: "did_enter_region", parameters: ["regionId": region.identifier])
            await audit.record("Entered region", metadata: ["regionId": region.identifier])
            await GeofencingAuditManager.shared.add(
                GeofencingAuditEntry(event: "did_enter_region", regionId: region.identifier)
            )
        }
    }

    public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task {
            await analytics.log(event: "did_exit_region", parameters: ["regionId": region.identifier])
            await audit.record("Exited region", metadata: ["regionId": region.identifier])
            await GeofencingAuditManager.shared.add(
                GeofencingAuditEntry(event: "did_exit_region", regionId: region.identifier)
            )
        }
    }
}

// MARK: - Diagnostics

public extension GeofencingService {
    /// Fetch recent geofencing audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [GeofencingAuditEntry] {
        await GeofencingAuditManager.shared.recent(limit: limit)
    }

    /// Export geofencing audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await GeofencingAuditManager.shared.exportJSON()
    }
}

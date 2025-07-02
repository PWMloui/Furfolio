//
//  WatchConnectivityService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A service to manage communication between the iOS app and the watchOS companion app.
//

import Foundation
import WatchConnectivity
import Combine

/**
 WatchConnectivityService
 -------------------------
 Manages communication between the iOS and watchOS apps with async analytics and audit logging.

 - **Purpose**: Sends application context and messages, and handles incoming data.
 - **Architecture**: Singleton `ObservableObject` using `WCSession`.
 - **Concurrency & Async Logging**: Wraps all WCSession operations in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Log messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol WatchConnectivityAnalyticsLogger {
    /// Log a connectivity event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol WatchConnectivityAuditLogger {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullWatchConnectivityAnalyticsLogger: WatchConnectivityAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullWatchConnectivityAuditLogger: WatchConnectivityAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a watch connectivity audit event.
public struct WatchConnectivityAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging watch connectivity events.
public actor WatchConnectivityAuditManager {
    private var buffer: [WatchConnectivityAuditEntry] = []
    private let maxEntries = 100
    public static let shared = WatchConnectivityAuditManager()

    public func add(_ entry: WatchConnectivityAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [WatchConnectivityAuditEntry] {
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

// MARK: - Data Transfer Objects (DTOs)

/// A lightweight, Codable struct representing a summary of an appointment for the watch.
struct AppointmentSummary: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let dogName: String
    let serviceType: String
}

/// A lightweight, Codable struct representing a summary of a task for the watch.
struct TaskSummary: Codable, Identifiable {
    let id: UUID
    let title: String
    let priority: Priority // Assuming Priority enum is Codable
}

/// The main context object sent from the phone to the watch.
struct WatchAppContext: Codable {
    let upcomingAppointments: [AppointmentSummary]
    let openTasks: [TaskSummary]
    let lastUpdated: Date
}

// MARK: - Watch Connectivity Service

/// Manages the WCSession and facilitates data transfer between the iOS and watchOS apps.
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    
    static let shared = WatchConnectivityService(
        analytics: NullWatchConnectivityAnalyticsLogger(),
        audit: NullWatchConnectivityAuditLogger()
    )

    private let analytics: WatchConnectivityAnalyticsLogger
    private let audit: WatchConnectivityAuditLogger

    @Published private(set) var lastReceivedContext: WatchAppContext?
    @Published private(set) var isReachable: Bool = false

    private let session: WCSession

    // MARK: - Initialization
    
    private init(
        analytics: WatchConnectivityAnalyticsLogger,
        audit: WatchConnectivityAuditLogger
    ) {
        self.session = .default
        self.analytics = analytics
        self.audit = audit
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - iOS App Methods
    
    #if os(iOS)
    /// Gathers current data, packages it, and sends it to the watch as application context.
    /// This should be called when data changes or periodically in the background.
    func sendContextToWatch() {
        guard session.isPaired, session.isWatchAppInstalled else { return }
        
        Task {
            await analytics.log(event: "send_context_start", metadata: ["isPaired": session.isPaired])
            await audit.record("Context send started", metadata: ["paired": "\(session.isPaired)"])
            await WatchConnectivityAuditManager.shared.add(
                WatchConnectivityAuditEntry(event: "send_context_start", detail: nil)
            )
        }
        
        Task {
            // Fetch real data from your DataStoreService
            let appointments = await DataStoreService.shared.fetchAppointments(upcomingOnly: true)
            let tasks = await DataStoreService.shared.fetchAll(Task.self).filter { !$0.completed }

            // Map to lightweight DTOs
            let appointmentSummaries = appointments.prefix(5).map { appt in
                AppointmentSummary(id: appt.id, startTime: appt.date, dogName: appt.dog?.name ?? "N/A", serviceType: appt.serviceType.displayName)
            }
            let taskSummaries = tasks.prefix(5).map { task in
                TaskSummary(id: task.id, title: task.title, priority: task.priority)
            }
            
            let context = WatchAppContext(
                upcomingAppointments: appointmentSummaries,
                openTasks: taskSummaries,
                lastUpdated: Date()
            )
            
            do {
                let data = try JSONEncoder().encode(context)
                try session.updateApplicationContext(["appContext": data])
                
                Task {
                    await analytics.log(event: "send_context_complete", metadata: nil)
                    await audit.record("Context send completed", metadata: nil)
                    await WatchConnectivityAuditManager.shared.add(
                        WatchConnectivityAuditEntry(event: "send_context_complete", detail: nil)
                    )
                }
                
                print(NSLocalizedString("WatchConnectivityService: Sent context to watch.", comment: ""))
            } catch {
                print(NSLocalizedString("WatchConnectivityService: Failed to send context - \(error.localizedDescription)", comment: ""))
            }
        }
    }
    #endif

    // MARK: - watchOS App Methods
    
    /// Sends a message from the watch to the phone (e.g., to mark a task complete).
    func sendMessageToPhone(_ message: [String: Any]) {
        Task {
            await analytics.log(event: "send_message_start", metadata: message)
            await audit.record("Message send started", metadata: message.mapValues { "\($0)" })
            await WatchConnectivityAuditManager.shared.add(
                WatchConnectivityAuditEntry(event: "send_message_start", detail: "\(message)")
            )
        }
        
        guard session.isReachable else {
            print(NSLocalizedString("WatchConnectivityService: iPhone is not reachable.", comment: ""))
            return
        }
        session.sendMessage(message, replyHandler: nil) { error in
            Task {
                await self.analytics.log(event: "send_message_result", metadata: error == nil ? ["status":"success"] : ["status":"error"])
                await self.audit.record("Message send result", metadata: ["error": error?.localizedDescription ?? "none"])
                await WatchConnectivityAuditManager.shared.add(
                    WatchConnectivityAuditEntry(event: error == nil ? "send_message_success" : "send_message_error", detail: error?.localizedDescription)
                )
            }
            if let error = error {
                print(NSLocalizedString("WatchConnectivityService: Failed to send message to phone - \(error.localizedDescription)", comment: ""))
            }
        }
    }
}

// MARK: - WCSessionDelegate Conformance

extension WatchConnectivityService: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = (activationState == .activated)
            print(NSLocalizedString("WatchConnectivityService: Session activation completed with state: \(activationState.rawValue)", comment: ""))
            if let error = error {
                print(NSLocalizedString("WatchConnectivityService: Activation error: \(error.localizedDescription)", comment: ""))
            }
        }
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // Required for iOS
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // Required for iOS, reactivate session
        session.activate()
    }
    
    /// Receives a message from the watch on the phone.
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task {
            await analytics.log(event: "receive_message", metadata: message)
            await audit.record("Message received", metadata: message.mapValues { "\($0)" })
            await WatchConnectivityAuditManager.shared.add(
                WatchConnectivityAuditEntry(event: "receive_message", detail: "\(message)")
            )
        }
        // Handle incoming commands from the watch on the iOS app
        // e.g., if message["action"] == "completeTask", get task ID and update in SwiftData
        print(NSLocalizedString("WatchConnectivityService: Received message on iPhone: \(message)", comment: ""))
    }
    #endif
    
    /// Receives application context on the watch.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        Task {
            await analytics.log(event: "receive_context", metadata: ["items": applicationContext.keys.joined(separator: ",")])
            await audit.record("Context received", metadata: nil)
            await WatchConnectivityAuditManager.shared.add(
                WatchConnectivityAuditEntry(event: "receive_context", detail: nil)
            )
        }
        
        guard let data = applicationContext["appContext"] as? Data else {
            return
        }
        
        do {
            let context = try JSONDecoder().decode(WatchAppContext.self, from: data)
            DispatchQueue.main.async {
                self.lastReceivedContext = context
                print(NSLocalizedString("WatchConnectivityService: Received and decoded context on watch.", comment: ""))
            }
        } catch {
            print(NSLocalizedString("WatchConnectivityService: Failed to decode context on watch - \(error.localizedDescription)", comment: ""))
        }
    }
}

// MARK: - Diagnostics

public extension WatchConnectivityService {
    /// Fetch recent audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [WatchConnectivityAuditEntry] {
        await WatchConnectivityAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await WatchConnectivityAuditManager.shared.exportJSON()
    }
}

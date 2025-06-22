
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
    
    static let shared = WatchConnectivityService()

    // MARK: - Published Properties for watchOS UI
    
    @Published private(set) var lastReceivedContext: WatchAppContext?
    @Published private(set) var isReachable: Bool = false

    private let session: WCSession

    // MARK: - Initialization
    
    private override init() {
        self.session = .default
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
                print("WatchConnectivityService: Sent context to watch.")
            } catch {
                print("WatchConnectivityService: Failed to send context - \(error.localizedDescription)")
            }
        }
    }
    #endif

    // MARK: - watchOS App Methods
    
    /// Sends a message from the watch to the phone (e.g., to mark a task complete).
    func sendMessageToPhone(_ message: [String: Any]) {
        guard session.isReachable else {
            print("WatchConnectivityService: iPhone is not reachable.")
            return
        }
        session.sendMessage(message, replyHandler: nil) { error in
            print("WatchConnectivityService: Failed to send message to phone - \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate Conformance

extension WatchConnectivityService: WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = (activationState == .activated)
            print("WatchConnectivityService: Session activation completed with state: \(activationState.rawValue)")
            if let error = error {
                print("WatchConnectivityService: Activation error: \(error.localizedDescription)")
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
        // Handle incoming commands from the watch on the iOS app
        // e.g., if message["action"] == "completeTask", get task ID and update in SwiftData
        print("WatchConnectivityService: Received message on iPhone: \(message)")
    }
    #endif
    
    /// Receives application context on the watch.
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        guard let data = applicationContext["appContext"] as? Data else {
            return
        }
        
        do {
            let context = try JSONDecoder().decode(WatchAppContext.self, from: data)
            DispatchQueue.main.async {
                self.lastReceivedContext = context
                print("WatchConnectivityService: Received and decoded context on watch.")
            }
        } catch {
            print("WatchConnectivityService: Failed to decode context on watch - \(error.localizedDescription)")
        }
    }
}

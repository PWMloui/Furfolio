//
//  AppUpdateManager.swift
//  Furfolio
//
//  ENHANCED 2025-06-30: Role/staff/context audit, escalation, trust center/BI ready, extensible, modular.
//

import Foundation

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Escalation)

public protocol AppUpdateAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}

/// No-op logger (for default/preview/testing)
public struct NullAppUpdateAnalyticsLogger: AppUpdateAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
}

/// Console logger for QA/testing
public class ConsoleAppUpdateAnalyticsLogger: AppUpdateAnalyticsLogger {
    public var testMode: Bool = true
    public init(testMode: Bool = true) { self.testMode = testMode }
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        if testMode { print("[AppUpdate][LOG] \(event) | Info: \(info ?? "-") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]") }
    }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        if testMode { print("[AppUpdate][ESCALATE] \(event) | Info: \(info ?? "-") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]") }
    }
}

// MARK: - AppUpdateManager

final class AppUpdateManager: ObservableObject {
    // MARK: - Analytics Logger
    
    /// Shared analytics logger, can be replaced (admin, BI, trust center, QA)
    static var analyticsLogger: AppUpdateAnalyticsLogger = NullAppUpdateAnalyticsLogger()
    
    /// Role/staff/business context for audit (set at login/session)
    static var currentRole: String? = nil
    static var currentStaffID: String? = nil
    static var currentContext: String? = "AppUpdateManager"
    
    // MARK: - Configuration Tokens
    
    private let versionAPIURL = URL(string: "https://furfolio.app/api/version")!
    private let changelogAPIURL = URL(string: "https://furfolio.app/api/changelog")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id000000000")!
    private let mandatoryUpdatePolicyKey = "mandatory_update"
    
    // MARK: - Published Properties
    
    @Published var updateAvailable: Bool = false
    @Published var mandatoryUpdate: Bool = false
    @Published var changelog: String? = nil
    @Published var latestVersion: String? = nil
    @Published var updateChecked: Date? = nil
    
    // MARK: - Diagnostics

    public struct AnalyticsEvent: Codable, Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let event: String
        public let info: String?
        public let role: String?
        public let staffID: String?
        public let context: String?
        public let escalate: Bool
    }
    private var analyticsEventHistory: [AnalyticsEvent] = []
    private let analyticsEventHistoryQueue = DispatchQueue(label: "com.furfolio.AppUpdateManager.analyticsEventHistoryQueue", attributes: .concurrent)
    
    // MARK: - Test Mode

    var testMode: Bool = false
    
    // MARK: - Initializer

    init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    // MARK: - Update Check (local/remote)

    func checkForUpdates(completion: ((Bool, String?) -> Void)? = nil) {
        Task {
            await Self.logEvent("checkForUpdates_called", info: nil, escalate: false, testMode: self.testMode)
            
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            let request = URLRequest(url: versionAPIURL)
            
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    self?.updateChecked = Date()
                    if let error = error {
                        Task { await Self.logEvent("update_check_failed", info: error.localizedDescription, escalate: true, testMode: self?.testMode ?? false) }
                        completion?(false, nil)
                        return
                    }
                    guard let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let latest = json["latest_version"] as? String else {
                        Task { await Self.logEvent("update_check_parse_error", info: nil, escalate: true, testMode: self?.testMode ?? false) }
                        completion?(false, nil)
                        return
                    }
                    self?.latestVersion = latest
                    let isUpdateAvailable = latest.compare(currentVersion, options: .numeric) == .orderedDescending
                    self?.updateAvailable = isUpdateAvailable
                    self?.mandatoryUpdate = (json[self?.mandatoryUpdatePolicyKey ?? "mandatory_update"] as? Bool) ?? false
                    
                    Task {
                        await Self.logEvent("update_check_complete",
                                            info: String(format: NSLocalizedString("Available:%@ Latest:%@", comment: "Analytics log info for update check completion"), isUpdateAvailable.description, latest),
                                            escalate: false, testMode: self?.testMode ?? false)
                    }
                    completion?(isUpdateAvailable, latest)
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Show Update Prompt

    func showUpdatePrompt(forceMandatory: Bool? = nil) {
        let isMandatory = forceMandatory ?? mandatoryUpdate
        Task {
            await Self.logEvent("showUpdatePrompt",
                                info: NSLocalizedString(isMandatory ? "mandatory" : "optional", comment: "Update prompt type"),
                                escalate: isMandatory, testMode: self.testMode)
        }
        // Implement UI trigger (NotificationCenter, Combine, delegate, etc.)
    }
    
    // MARK: - Fetch Changelog

    func fetchChangelog(completion: ((String?) -> Void)? = nil) {
        Task {
            await Self.logEvent("fetchChangelog_called", info: nil, escalate: false, testMode: self.testMode)
            let task = URLSession.shared.dataTask(with: URLRequest(url: changelogAPIURL)) { [weak self] data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Task { await Self.logEvent("changelog_fetch_failed", info: error.localizedDescription, escalate: false, testMode: self?.testMode ?? false) }
                        completion?(nil)
                        return
                    }
                    guard let data = data, let changelogText = String(data: data, encoding: .utf8) else {
                        Task { await Self.logEvent("changelog_parse_error", info: nil, escalate: false, testMode: self?.testMode ?? false) }
                        completion?(nil)
                        return
                    }
                    self?.changelog = changelogText
                    Task {
                        await Self.logEvent("changelog_fetched",
                                            info: String(format: NSLocalizedString("%@…", comment: "Changelog preview"), changelogText.prefix(32)),
                                            escalate: false, testMode: self?.testMode ?? false)
                    }
                    completion?(changelogText)
                }
            }
            task.resume()
        }
    }
    
    // MARK: - Handle Mandatory Update

    func handleMandatoryUpdate() {
        Task {
            await Self.logEvent("handleMandatoryUpdate_called", info: nil, escalate: true, testMode: self.testMode)
        }
        showUpdatePrompt(forceMandatory: true)
    }
    
    // MARK: - Trust Center/Audit Permission (stub)

    func auditPermission(for action: String) -> Bool {
        Task {
            await Self.logEvent("trust_center_permission_check", info: action, escalate: false, testMode: self.testMode)
        }
        // Integrate with Trust Center/RoleManager as needed
        return true
    }
    
    // MARK: - Diagnostics API

    public func fetchRecentAnalyticsEvents(count: Int = 20) -> [AnalyticsEvent] {
        var events: [AnalyticsEvent] = []
        analyticsEventHistoryQueue.sync {
            events = Array(self.analyticsEventHistory.suffix(count))
        }
        return events
    }
    
    // MARK: - Private Logging Helper

    private static func logEvent(_ event: String, info: String?, escalate: Bool, testMode: Bool) async {
        let role = Self.currentRole
        let staffID = Self.currentStaffID
        let ctx = Self.currentContext
        let timestamp = Date()
        let analyticsEvent = AnalyticsEvent(
            timestamp: timestamp,
            event: event,
            info: info,
            role: role,
            staffID: staffID,
            context: ctx,
            escalate: escalate
        )
        // Append to event history thread-safe
        DispatchQueue.global(qos: .utility).async {
            let manager = AppUpdateManager.sharedInstance
            manager.analyticsEventHistoryQueue.async(flags: .barrier) {
                manager.analyticsEventHistory.append(analyticsEvent)
                if manager.analyticsEventHistory.count > 40 { manager.analyticsEventHistory.removeFirst() }
            }
        }
        // Logging
        if testMode || Self.analyticsLogger.testMode {
            print("[AppUpdate][Event]: \(event) | Info: \(info ?? "-") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(ctx ?? "-")]")
        } else if escalate {
            await analyticsLogger.escalate(event: event, info: info, role: role, staffID: staffID, context: ctx)
        } else {
            await analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: ctx)
        }
    }
    
    // MARK: - Shared Instance for internal use

    private static let sharedInstance = AppUpdateManager()
}

//
//  AppUpdateManager.swift
//  Furfolio
//
//  Enhanced: audit/analytics–ready, extensible, token-compliant, preview/test-injectable, Trust Center compliant.
//

import Foundation

// MARK: - Audit/Analytics Protocol

public protocol AppUpdateAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullAppUpdateAnalyticsLogger: AppUpdateAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - AppUpdateManager (Version Check, Update Prompt, Changelog, Audit, Trust Center)

final class AppUpdateManager: ObservableObject {
    // Analytics logger for Trust Center/BI/QA/preview
    static var analyticsLogger: AppUpdateAnalyticsLogger = NullAppUpdateAnalyticsLogger()
    
    // MARK: - Tokens/config (centralized for maintainability)
    private let versionAPIURL = URL(string: "https://furfolio.app/api/version")! // Move to Tokens if needed
    private let changelogAPIURL = URL(string: "https://furfolio.app/api/changelog")!
    private let appStoreURL = URL(string: "https://apps.apple.com/app/id000000000")!
    private let mandatoryUpdatePolicyKey = "mandatory_update"
    
    @Published var updateAvailable: Bool = false
    @Published var mandatoryUpdate: Bool = false
    @Published var changelog: String? = nil
    @Published var latestVersion: String? = nil
    @Published var updateChecked: Date? = nil
    
    // MARK: - Update Check (local/remote)
    func checkForUpdates(completion: ((Bool, String?) -> Void)? = nil) {
        // Example: Async remote check (future–ready)
        Self.analyticsLogger.log(event: "checkForUpdates_called", info: nil)
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let request = URLRequest(url: versionAPIURL)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.updateChecked = Date()
                if let error = error {
                    Self.analyticsLogger.log(event: "update_check_failed", info: error.localizedDescription)
                    completion?(false, nil)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let latest = json["latest_version"] as? String else {
                    Self.analyticsLogger.log(event: "update_check_parse_error", info: nil)
                    completion?(false, nil)
                    return
                }
                self?.latestVersion = latest
                let isUpdateAvailable = latest.compare(currentVersion, options: .numeric) == .orderedDescending
                self?.updateAvailable = isUpdateAvailable
                self?.mandatoryUpdate = (json[self?.mandatoryUpdatePolicyKey ?? "mandatory_update"] as? Bool) ?? false
                Self.analyticsLogger.log(event: "update_check_complete", info: "Available:\(isUpdateAvailable) Latest:\(latest)")
                completion?(isUpdateAvailable, latest)
            }
        }
        task.resume()
    }
    
    // MARK: - Show Update Prompt
    func showUpdatePrompt(forceMandatory: Bool? = nil) {
        let isMandatory = forceMandatory ?? mandatoryUpdate
        Self.analyticsLogger.log(event: "showUpdatePrompt", info: isMandatory ? "mandatory" : "optional")
        // Implementation: Present UI (e.g., SwiftUI .sheet or alert) and handle App Store navigation.
        // Use NotificationCenter, Combine, or delegate to trigger the UI from your View.
        // Example:
        // NotificationCenter.default.post(name: .shouldShowUpdatePrompt, object: isMandatory)
    }
    
    // MARK: - Fetch Changelog
    func fetchChangelog(completion: ((String?) -> Void)? = nil) {
        Self.analyticsLogger.log(event: "fetchChangelog_called", info: nil)
        let task = URLSession.shared.dataTask(with: URLRequest(url: changelogAPIURL)) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    Self.analyticsLogger.log(event: "changelog_fetch_failed", info: error.localizedDescription)
                    completion?(nil)
                    return
                }
                guard let data = data, let changelogText = String(data: data, encoding: .utf8) else {
                    Self.analyticsLogger.log(event: "changelog_parse_error", info: nil)
                    completion?(nil)
                    return
                }
                self?.changelog = changelogText
                Self.analyticsLogger.log(event: "changelog_fetched", info: "\(changelogText.prefix(32))…")
                completion?(changelogText)
            }
        }
        task.resume()
    }
    
    // MARK: - Handle Mandatory Update
    func handleMandatoryUpdate() {
        Self.analyticsLogger.log(event: "handleMandatoryUpdate_called", info: nil)
        // Block UI, force update, or direct to App Store as per your update policy.
        // Example: Present a non-dismissible alert.
        showUpdatePrompt(forceMandatory: true)
    }
    
    // MARK: - Trust Center Integration (stub)
    func auditPermission(for action: String) -> Bool {
        Self.analyticsLogger.log(event: "trust_center_permission_check", info: action)
        // Future: Integrate with Trust Center/role manager.
        return true
    }
}

/*
 Usage Example:

 let updateManager = AppUpdateManager()
 updateManager.checkForUpdates { isAvailable, latestVersion in
     if isAvailable { updateManager.showUpdatePrompt() }
 }
 updateManager.fetchChangelog { changelog in
     print("Changelog: \(changelog ?? "none")")
 }
 // To handle forced update:
 if updateManager.mandatoryUpdate { updateManager.handleMandatoryUpdate() }
*/

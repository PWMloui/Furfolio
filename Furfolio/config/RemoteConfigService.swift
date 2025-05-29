//
//  RemoteConfigService.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import os
import FirebaseRemoteConfigService

/// A singleton service that fetches and exposes remote configuration flags.
final class RemoteConfigService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "RemoteConfigService")
    private let defaultValues: [String: NSObject]

    /// Convenience URL for the API base.
    var apiBaseURL: URL {
        URL(string: stringValue(for: .apiBaseURL))!
    }

    static let shared = RemoteConfigService()

    private let remoteConfig: RemoteConfig

    /// Notification posted when remote config values are updated.
    static let didUpdateNotification = Notification.Name("RemoteConfigServiceDidUpdate")

    private init() {
        // Initialize Remote Config with default settings
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // Fetch at most once per hour; adjust as needed
        settings.minimumFetchInterval = 3600
        remoteConfig.configSettings = settings

        // Register default values for all keys
        defaultValues = defaultsDictionary
        remoteConfig.setDefaults(defaultsDictionary)
    }

    /// Default values for remote config parameters
    private var defaultsDictionary: [String: NSObject] {
        var defaults: [String: NSObject] = [:]
        // List all keys with their default values here
        for key in RemoteConfigKey.allCases {
            defaults[key.rawValue] = key.defaultValue as NSObject
        }
        return defaults
    }

    /// All supported remote config keys
    enum RemoteConfigKey: String, CaseIterable {
        case enableDarkModeLock      = "enable_dark_mode_lock"
        case loyaltyThreshold        = "loyalty_threshold"
        case showAdvancedAnalytics   = "show_advanced_analytics"
        case apiBaseURL              = "api_base_url"
        // TODO: add more keys as needed

        /// Default value for each key
        var defaultValue: Any {
            switch self {
            case .enableDarkModeLock:    return false
            case .loyaltyThreshold:      return 10
            case .showAdvancedAnalytics: return false
            case .apiBaseURL:            return "https://api.furfolioapp.com"
            }
        }
    }

    /// Fetch and activate remote config values.
    func fetchAndActivate(completion: ((Bool, Error?) -> Void)? = nil) {
        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                self.logger.error("RemoteConfig fetch error: \(error.localizedDescription)")
                completion?(false, error)
            } else {
                let applied = (status == .successFetchedFromRemote || status == .successUsingPreFetchedData)
                self.logger.log("RemoteConfig fetch status: \(status.rawValue), applied: \(applied)")
                if applied {
                    NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
                }
                completion?(applied, nil)
            }
        }
    }

    /// Retrieve a Bool flag for the given key.
    func boolValue(for key: RemoteConfigKey) -> Bool {
        remoteConfig.configValue(forKey: key.rawValue).boolValue
    }

    /// Retrieve an Int flag for the given key.
    func intValue(for key: RemoteConfigKey) -> Int {
        remoteConfig.configValue(forKey: key.rawValue).numberValue?.intValue
            ?? (key.defaultValue as? Int ?? 0)
    }

    /// Retrieve a String flag for the given key.
    func stringValue(for key: RemoteConfigKey) -> String {
        remoteConfig.configValue(forKey: key.rawValue).stringValue
            ?? (key.defaultValue as? String ?? "")
    }

    /// Retrieves a generic config value for the given key, falling back to default.
    func configValue<T>(for key: RemoteConfigKey) -> T {
        let value = remoteConfig.configValue(forKey: key.rawValue).jsonValue as? T
        return value ?? (key.defaultValue as! T)
    }

    /// Clears all fetched remote config values and resets to defaults.
    func reset() {
        remoteConfig.setDefaults(defaultValues)
        logger.log("RemoteConfig defaults reset")
    }
}

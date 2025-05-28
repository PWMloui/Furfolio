//
//  RemoteConfigService.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

/// A singleton service that fetches and exposes remote configuration flags.
final class RemoteConfigService {
#if canImport(FirebaseRemoteConfig)
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
        // TODO: add more keys as needed

        /// Default value for each key
        var defaultValue: Any {
            switch self {
            case .enableDarkModeLock:    return false
            case .loyaltyThreshold:      return 10
            case .showAdvancedAnalytics: return false
            }
        }
    }

    /// Fetch and activate remote config values.
    func fetchAndActivate(completion: ((Bool, Error?) -> Void)? = nil) {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            if let error = error {
                print("🔴 RemoteConfig fetch error: \(error)")
            } else {
                print("✅ RemoteConfig fetched and activated: \(status)")
                NotificationCenter.default.post(name: Self.didUpdateNotification, object: nil)
            }
            completion?(status == .successFetchedFromRemote || status == .successUsingPreFetchedData, error)
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
#endif
}

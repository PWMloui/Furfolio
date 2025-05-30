//
//  FirebaseRemoteConfig.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import FirebaseRemoteConfig
import os

/// A typed wrapper around Firebase Remote Config for Furfolio.
final class FirebaseRemoteConfigService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FirebaseRemoteConfigService")
    static let shared = FirebaseRemoteConfigService()
    private let remoteConfig: RemoteConfig
    private let defaultValues: [String: NSObject]

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600 // 1 hour
        #endif
        remoteConfig.configSettings = settings

        // Set default values for all keys
        defaultValues = Dictionary(uniqueKeysWithValues:
            ConfigKey.allCases.map { ($0.rawValue, $0.defaultValue as? NSObject ?? "" as NSString) }
        )
        remoteConfig.setDefaults(defaultValues)
        logger.log("FirebaseRemoteConfigService initialized with defaults: \(defaultValues.keys)")
    }

    /// Remote config keys used by the app.
    enum ConfigKey: String, CaseIterable {
        case apiBaseURL = "api_base_url"
        case enableNewDashboard = "enable_new_dashboard"
        // Add more keys here as needed.

        /// Default value for each key
        var defaultValue: Any {
            switch self {
            case .apiBaseURL: return "https://api.furfolioapp.com"
            case .enableNewDashboard: return false
            }
        }
    }

    /// Convenience URL for the API base.
    var apiBaseURL: URL {
        URL(string: string(forKey: .apiBaseURL))!
    }

    /// Fetches and activates the latest remote config values.
    /// - Parameter completion: Callback with success flag and optional error.
    func fetchAndActivate(completion: ((Bool, Error?) -> Void)? = nil) {
        remoteConfig.fetchAndActivate { [logger] status, error in
            if let error = error {
                logger.error("RemoteConfig fetch error: \(error.localizedDescription)")
                completion?(false, error)
            } else {
                let success = (status == .successFetchedFromRemote || status == .successUsingPreFetchedData)
                logger.log("RemoteConfig fetch status: \(status.rawValue), applied: \(success)")
                completion?(success, nil)
            }
        }
    }

    /// Retrieves a String value for the given config key.
    func string(forKey key: ConfigKey) -> String {
        logger.log("Retrieving String for key: \(key.rawValue)")
        let value = remoteConfig.configValue(forKey: key.rawValue).stringValue ?? (key.defaultValue as? String ?? "")
        logger.log("Value for \(key.rawValue): \(value)")
        return value
    }

    /// Retrieves a Bool value for the given config key.
    func bool(forKey key: ConfigKey) -> Bool {
        logger.log("Retrieving Bool for key: \(key.rawValue)")
        let value = remoteConfig.configValue(forKey: key.rawValue).boolValue
        logger.log("Value for \(key.rawValue): \(value)")
        return value
    }

    /// Retrieves an Int value for the given config key.
    func int(forKey key: ConfigKey) -> Int {
        logger.log("Retrieving Int for key: \(key.rawValue)")
        let value = remoteConfig.configValue(forKey: key.rawValue).numberValue?.intValue ?? (key.defaultValue as? Int ?? 0)
        logger.log("Value for \(key.rawValue): \(value)")
        return value
    }

    /// Retrieves a Double value for the given config key.
    func double(forKey key: ConfigKey) -> Double {
        logger.log("Retrieving Double for key: \(key.rawValue)")
        let value = remoteConfig.configValue(forKey: key.rawValue).numberValue?.doubleValue ?? (key.defaultValue as? Double ?? 0.0)
        logger.log("Value for \(key.rawValue): \(value)")
        return value
    }

    /// Retrieves a generic config value for the given key, falling back to default.
    func configValue<T>(forKey key: ConfigKey) -> T {
        logger.log("Retrieving config value for key: \(key.rawValue)")
        let value = remoteConfig.configValue(forKey: key.rawValue).jsonValue as? T ?? (key.defaultValue as! T)
        logger.log("Value for \(key.rawValue): \(String(describing: value))")
        return value
    }

    /// Clears all fetched values and resets to defaults.
    func reset() {
        logger.log("Resetting RemoteConfig to defaults")
        remoteConfig.setDefaults(defaultValues)
    }
}

//
//  FirebaseRemoteConfig.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import Foundation
import FirebaseRemoteConfig

/// A typed wrapper around Firebase Remote Config for Furfolio.
final class FirebaseRemoteConfigService {
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
        remoteConfig.fetchAndActivate { status, error in
            if let error = error {
                print("🔥 RemoteConfig fetch error: \(error.localizedDescription)")
                completion?(false, error)
            } else {
                let success = (status == .successFetchedFromRemote || status == .successUsingPreFetchedData)
                print("✅ RemoteConfig fetch status: \(status.rawValue), applied: \(success)")
                completion?(success, nil)
            }
        }
    }

    /// Retrieves a String value for the given config key.
    func string(forKey key: ConfigKey) -> String {
        remoteConfig.configValue(forKey: key.rawValue).stringValue
        ?? (key.defaultValue as? String ?? "")
    }

    /// Retrieves a Bool value for the given config key.
    func bool(forKey key: ConfigKey) -> Bool {
        remoteConfig.configValue(forKey: key.rawValue).boolValue
    }

    /// Retrieves an Int value for the given config key.
    func int(forKey key: ConfigKey) -> Int {
        remoteConfig.configValue(forKey: key.rawValue).numberValue?.intValue
        ?? (key.defaultValue as? Int ?? 0)
    }

    /// Retrieves a Double value for the given config key.
    func double(forKey key: ConfigKey) -> Double {
        remoteConfig.configValue(forKey: key.rawValue).numberValue?.doubleValue
        ?? (key.defaultValue as? Double ?? 0.0)
    }

    /// Retrieves a generic config value for the given key, falling back to default.
    func configValue<T>(forKey key: ConfigKey) -> T {
        let value = remoteConfig.configValue(forKey: key.rawValue).jsonValue as? T
        return value ?? (key.defaultValue as! T)
    }

    /// Clears all fetched values and resets to defaults.
    func reset() {
        remoteConfig.setDefaults(defaultValues)
    }
}

//
//  SettingsManager.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//


import Foundation
import Combine
import os
import FirebaseRemoteConfigService

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "SettingsManager")
    
    /// Remote-configurable default loyalty threshold.
    private static var defaultLoyaltyThreshold: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .loyaltyThreshold)
    }
    
    /// Remote-configurable default reminder offset (minutes).
    private static var defaultReminderOffsetMinutes: Int {
        FirebaseRemoteConfigService.shared.configValue(forKey: .defaultReminderOffset)
    }
    
    private enum Keys {
        static let darkModeLock = "SettingsManager.darkModeLock"
        static let fontSizeScale = "SettingsManager.fontSizeScale"
        static let loyaltyThreshold = "SettingsManager.loyaltyThreshold"
        static let defaultReminderOffset = "SettingsManager.defaultReminderOffset"
        static let rewardThresholds = "SettingsManager.rewardThresholds"
        static let loyaltyPointsPerTier = "SettingsManager.loyaltyPointsPerTier"
    }
    
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    @Published var darkModeLock: Bool
    
    @Published var fontSizeScale: Double
    
    @Published var defaultReminderOffset: Int
    
    @Published var loyaltyThreshold: Int

    /// Monetary thresholds for daily revenue rewards.
    @Published var rewardThresholds: [Double]

    /// Loyalty points awarded per tier.
    @Published var loyaltyPointsPerTier: [Int]

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initialDefaults: [String: Any] = [
            Keys.darkModeLock: false,
            Keys.fontSizeScale: 1.0,
            Keys.defaultReminderOffset: Self.defaultReminderOffsetMinutes,
            Keys.loyaltyThreshold: Self.defaultLoyaltyThreshold,
            Keys.rewardThresholds: [100.0, 250.0, 500.0],
            Keys.loyaltyPointsPerTier: [1, 2, 3]
        ]
        defaults.register(defaults: initialDefaults)
        logger.log("Registered default settings")
        // Load stored or remote-configured values
        self.darkModeLock = defaults.bool(forKey: Keys.darkModeLock)
        self.fontSizeScale = defaults.double(forKey: Keys.fontSizeScale).nonZeroOrDefault(1.0)
        self.defaultReminderOffset = defaults.integer(forKey: Keys.defaultReminderOffset).nonZeroOrDefault(Self.defaultReminderOffsetMinutes)
        self.loyaltyThreshold = defaults.integer(forKey: Keys.loyaltyThreshold).nonZeroOrDefault(Self.defaultLoyaltyThreshold)
        self.rewardThresholds = defaults.object(forKey: Keys.rewardThresholds) as? [Double] ?? [100, 250, 500]
        self.loyaltyPointsPerTier = defaults.object(forKey: Keys.loyaltyPointsPerTier) as? [Int] ?? [1, 2, 3]

        logger.log("Loaded settings: darkModeLock=\(darkModeLock), fontSizeScale=\(fontSizeScale), defaultReminderOffset=\(defaultReminderOffset), loyaltyThreshold=\(loyaltyThreshold)")

        $darkModeLock
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.darkModeLock)
                self.logger.log("darkModeLock updated to \(newValue)")
            }
            .store(in: &cancellables)
        $fontSizeScale
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.fontSizeScale)
                self.logger.log("fontSizeScale updated to \(newValue)")
            }
            .store(in: &cancellables)
        $defaultReminderOffset
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.defaultReminderOffset)
                self.logger.log("defaultReminderOffset updated to \(newValue)")
            }
            .store(in: &cancellables)
        $loyaltyThreshold
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.loyaltyThreshold)
                self.logger.log("loyaltyThreshold updated to \(newValue)")
            }
            .store(in: &cancellables)
        $rewardThresholds
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.rewardThresholds)
                self.logger.log("rewardThresholds updated to \(newValue)")
            }
            .store(in: &cancellables)
        $loyaltyPointsPerTier
            .sink { newValue in
                defaults.set(newValue, forKey: Keys.loyaltyPointsPerTier)
                self.logger.log("loyaltyPointsPerTier updated to \(newValue)")
            }
            .store(in: &cancellables)
    }
    
    /// Resets all settings to default values.
    func resetToDefaults() {
        defaults.register(defaults: [
            Keys.darkModeLock: false,
            Keys.fontSizeScale: 1.0,
            Keys.defaultReminderOffset: 7,
            Keys.loyaltyThreshold: 5,
            Keys.rewardThresholds: [100.0, 250.0, 500.0],
            Keys.loyaltyPointsPerTier: [1, 2, 3]
        ])
        darkModeLock = defaults.bool(forKey: Keys.darkModeLock)
        fontSizeScale = defaults.double(forKey: Keys.fontSizeScale).nonZeroOrDefault(1.0)
        defaultReminderOffset = defaults.integer(forKey: Keys.defaultReminderOffset).nonZeroOrDefault(7)
        loyaltyThreshold = defaults.integer(forKey: Keys.loyaltyThreshold).nonZeroOrDefault(5)
        rewardThresholds = defaults.object(forKey: Keys.rewardThresholds) as? [Double] ?? [100, 250, 500]
        loyaltyPointsPerTier = defaults.object(forKey: Keys.loyaltyPointsPerTier) as? [Int] ?? [1, 2, 3]
        logger.log("Settings reset to defaults")
    }
}

private extension Double {
    func nonZeroOrDefault(_ defaultValue: Double) -> Double {
        return self == 0 ? defaultValue : self
    }
}

private extension Int {
    func nonZeroOrDefault(_ defaultValue: Int) -> Int {
        return self == 0 ? defaultValue : self
    }
}

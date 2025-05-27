//
//  SettingsManager.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//


import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
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
    
    @Published var darkModeLock: Bool {
        didSet { defaults.set(darkModeLock, forKey: Keys.darkModeLock) }
    }
    
    @Published var fontSizeScale: Double {
        didSet { defaults.set(fontSizeScale, forKey: Keys.fontSizeScale) }
    }
    
    @Published var defaultReminderOffset: Int {
        didSet { defaults.set(defaultReminderOffset, forKey: Keys.defaultReminderOffset) }
    }
    
    @Published var loyaltyThreshold: Int {
        didSet { defaults.set(loyaltyThreshold, forKey: Keys.loyaltyThreshold) }
    }

    /// Monetary thresholds for daily revenue rewards.
    @Published var rewardThresholds: [Double] {
        didSet { defaults.set(rewardThresholds, forKey: Keys.rewardThresholds) }
    }

    /// Loyalty points awarded per tier.
    @Published var loyaltyPointsPerTier: [Int] {
        didSet { defaults.set(loyaltyPointsPerTier, forKey: Keys.loyaltyPointsPerTier) }
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.darkModeLock = defaults.bool(forKey: Keys.darkModeLock)
        self.fontSizeScale = defaults.double(forKey: Keys.fontSizeScale).nonZeroOrDefault(1.0)
        self.defaultReminderOffset = defaults.integer(forKey: Keys.defaultReminderOffset).nonZeroOrDefault(7)
        self.loyaltyThreshold = defaults.integer(forKey: Keys.loyaltyThreshold).nonZeroOrDefault(5)
        self.rewardThresholds = defaults.object(forKey: Keys.rewardThresholds) as? [Double] ?? [100, 250, 500]
        self.loyaltyPointsPerTier = defaults.object(forKey: Keys.loyaltyPointsPerTier) as? [Int] ?? [1, 2, 3]

        $darkModeLock
            .sink { defaults.set($0, forKey: Keys.darkModeLock) }
            .store(in: &cancellables)
        $fontSizeScale
            .sink { defaults.set($0, forKey: Keys.fontSizeScale) }
            .store(in: &cancellables)
        $defaultReminderOffset
            .sink { defaults.set($0, forKey: Keys.defaultReminderOffset) }
            .store(in: &cancellables)
        $loyaltyThreshold
            .sink { defaults.set($0, forKey: Keys.loyaltyThreshold) }
            .store(in: &cancellables)
        $rewardThresholds
            .sink { defaults.set($0, forKey: Keys.rewardThresholds) }
            .store(in: &cancellables)
        $loyaltyPointsPerTier
            .sink { defaults.set($0, forKey: Keys.loyaltyPointsPerTier) }
            .store(in: &cancellables)
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

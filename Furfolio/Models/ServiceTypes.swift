//
//  ServiceTypes.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — added Comparable, SwiftUI Image helpers, iconText, and lazy formatters.
//

import Foundation
import SwiftUI
import os

/// Enumerates all grooming service types with defaults, localization, and rich descriptions.
enum ServiceType: String, Codable, CaseIterable, Identifiable, CustomStringConvertible, Comparable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceType")
    // MARK: – Cache
    
    /// Cache of currency formatters keyed by locale identifier.
    private static let currencyFormatterCache = NSCache<NSString, NumberFormatter>()
    
    case basicPackage   = "Basic Package"
    case fullPackage    = "Full Package"
    case spaBath  = "Custom Package"
    
    // MARK: – Identifiable
    
    /// Unique identifier for this service type.
    var id: String { rawValue }
    
    // MARK: – CustomStringConvertible
    
    /// Text description, same as localizedName.
    var description: String { localizedName }
    
    // MARK: – Comparable
    
    static func < (lhs: ServiceType, rhs: ServiceType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    // MARK: – Localization
    
    /// Localized display name for UI.
    var localizedName: String {
        NSLocalizedString(rawValue, comment: "Grooming service type")
    }
    
    // MARK: – Emoji & Symbol
    
    /// Emoji representing this service.
    var emojiIcon: String {
        switch self {
        case .basicPackage:  return "🛁"
        case .fullPackage:   return "✂️"
        case .spaBath: return "⚙️"
        }
    }
    
    /// SF Symbol name used for UI icons.
    var symbolName: String {
        switch self {
        case .basicPackage:  return "bathtub.fill"
        case .fullPackage:   return "scissors"
        case .spaBath: return "gearshape.fill"
        }
    }
    
    /// SwiftUI Image representing this service type.
    ///
    /// Styling and accessibility modifiers should be applied in the view layer.
    var image: Image {
        Image(systemName: symbolName)
    }
    
    /// Emoji plus name, e.g. "🛁 Basic Package".
    var iconText: String {
        "\(emojiIcon) \(localizedName)"
    }
    
    // MARK: – Default Durations (minutes)
    
    /// Suggested default duration (minutes) for scheduling.
    var defaultDurationMinutes: Int {
        switch self {
        case .basicPackage:  return 60
        case .fullPackage:   return 90
        case .spaBath: return 0  // Custom—you must set manually
        }
    }
    
    // MARK: – Default Prices (USD)
    
    /// Suggested base price (USD) for quoting.
    var defaultPrice: Double {
        switch self {
        case .basicPackage:  return 40.00
        case .fullPackage:   return 80.00
        case .spaBath: return 0.00  // Custom—you must set manually
        }
    }
    
    // MARK: – Helpers
    
    /// Returns a localized price string, e.g. "$40.00".
    func priceDescription(locale: Locale = .current) -> String {
        ServiceType.logger.log("Generating priceDescription for \(self.rawValue) at locale: \(locale.identifier)")
        let result = Self.priceFormatter(locale: locale)
            .string(from: NSNumber(value: defaultPrice))
            ?? String(format: "%.2f", defaultPrice)
        ServiceType.logger.log("priceDescription result: \(result)")
        return result
    }
    
    /// Human-readable duration, e.g. "1h 30m".
    var durationDescription: String {
        ServiceType.logger.log("Computing durationDescription for \(self.rawValue), minutes: \(defaultDurationMinutes)")
        guard defaultDurationMinutes > 0 else {
            let result = NSLocalizedString("Custom duration", comment: "No fixed duration")
            ServiceType.logger.log("durationDescription result: \(result)")
            return result
        }
        let seconds = TimeInterval(defaultDurationMinutes * 60)
        let result = Self.durationFormatter.string(from: seconds)
            ?? "\(defaultDurationMinutes) min"
        ServiceType.logger.log("durationDescription result: \(result)")
        return result
    }
    
    /// Combined quote, e.g. "Basic Package — $40.00 (60m)".
    func quoteDescription(locale: Locale = .current) -> String {
        ServiceType.logger.log("Generating quoteDescription for \(self.rawValue)")
        let quote = "\(localizedName) — \(priceDescription(locale: locale)) (\(durationDescription))"
        ServiceType.logger.log("quoteDescription result: \(quote)")
        return quote
    }
    
    /// All service types except `.custom`.
    static var predefined: [ServiceType] {
        allCases.filter { $0 != .spaBath }
    }
    
    // MARK: – Formatters
    
    /// Returns a currency formatter for the given locale, caching instances for reuse.
    private static func priceFormatter(locale: Locale) -> NumberFormatter {
        let key = locale.identifier as NSString
        if let cached = currencyFormatterCache.object(forKey: key) {
            return cached
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        currencyFormatterCache.setObject(formatter, forKey: key)
        return formatter
    }
    
    /// Shared formatter for duration strings.
    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        return f
    }()
}

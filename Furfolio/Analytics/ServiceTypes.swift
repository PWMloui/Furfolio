//
//  ServiceTypes.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — added Comparable, SwiftUI Image helpers, iconText, and lazy formatters.
//

import Foundation
import SwiftUI

/// Enumerates all grooming service types with defaults, localization, and rich descriptions.
enum ServiceType: String, Codable, CaseIterable, Identifiable, CustomStringConvertible, Comparable {
    // MARK: – Cache
    
    /// Cache of currency formatters keyed by locale identifier.
    private static let currencyFormatterCache = NSCache<NSString, NumberFormatter>()
    
    case basic    = "Basic Package"
    case full     = "Full Package"
    case custom   = "Custom Package"
    
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
        case .basic:  return "🛁"
        case .full:   return "✂️"
        case .custom: return "⚙️"
        }
    }
    
    /// SF Symbol name used for UI icons.
    var symbolName: String {
        switch self {
        case .basic:  return "bathtub.fill"
        case .full:   return "scissors"
        case .custom: return "gearshape.fill"
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
        case .basic:  return 60
        case .full:   return 90
        case .custom: return 0  // Custom—you must set manually
        }
    }
    
    // MARK: – Default Prices (USD)
    
    /// Suggested base price (USD) for quoting.
    var defaultPrice: Double {
        switch self {
        case .basic:  return 40.00
        case .full:   return 80.00
        case .custom: return 0.00  // Custom—you must set manually
        }
    }
    
    // MARK: – Helpers
    
    /// Returns a localized price string, e.g. "$40.00".
    func priceDescription(locale: Locale = .current) -> String {
        Self.priceFormatter(locale: locale)
            .string(from: NSNumber(value: defaultPrice))
            ?? String(format: "%.2f", defaultPrice)
    }
    
    /// Human-readable duration, e.g. "1h 30m".
    var durationDescription: String {
        guard defaultDurationMinutes > 0 else {
            return NSLocalizedString("Custom duration", comment: "No fixed duration")
        }
        let seconds = TimeInterval(defaultDurationMinutes * 60)
        return Self.durationFormatter.string(from: seconds)
            ?? "\(defaultDurationMinutes) min"
    }
    
    /// Combined quote, e.g. "Basic Package — $40.00 (60m)".
    func quoteDescription(locale: Locale = .current) -> String {
        "\(localizedName) — \(priceDescription(locale: locale)) (\(durationDescription))"
    }
    
    /// All service types except `.custom`.
    static var predefined: [ServiceType] {
        allCases.filter { $0 != .custom }
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

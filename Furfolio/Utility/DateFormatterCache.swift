//
//  DateFormatterCache.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import Foundation
import os
private let dateFormatterCacheLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DateFormatterCache")

/// A cache for expensive-to-create DateFormatter instances.
struct DateFormatterCache {

    private static let cache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 32 // Maximum number of cached formatters
        cache.totalCostLimit = 0 // Set to 0 for unlimited total cost, or adjust as needed
        return cache
    }()

    /// Returns a cached DateFormatter for the given date and time styles, locale, and time zone.
    /// - Parameters:
    ///   - dateStyle: The desired date style.
    ///   - timeStyle: The desired time style.
    ///   - locale: The locale to use for formatting. Defaults to `.current`.
    ///   - timeZone: The time zone to use for formatting. Defaults to `.current`.
    /// - Returns: A configured DateFormatter instance.
    static func formatter(dateStyle: DateFormatter.Style = .medium,
                          timeStyle: DateFormatter.Style = .short,
                          locale: Locale = .current,
                          timeZone: TimeZone = .current) -> DateFormatter {
        dateFormatterCacheLogger.log("Requesting DateFormatter for styles date:\(dateStyle.rawValue) time:\(timeStyle.rawValue) locale:\(locale.identifier) tz:\(timeZone.identifier)")
        let key = NSString(string: "\(dateStyle.rawValue)-\(timeStyle.rawValue)-\(locale.identifier)-\(timeZone.identifier)")
        if let existing = cache.object(forKey: key) {
            dateFormatterCacheLogger.log("Cache hit for formatter key: \(key)")
            return existing
        }
        let df = DateFormatter()
        df.dateStyle = dateStyle
        df.timeStyle = timeStyle
        df.locale = locale
        df.timeZone = timeZone
        cache.setObject(df, forKey: key)
        dateFormatterCacheLogger.log("Cache miss: created new DateFormatter for key: \(key)")
        return df
    }

    /// Returns a cached DateFormatter for the given date format string, locale, and time zone.
    /// - Parameters:
    ///   - format: The date format string.
    ///   - locale: The locale to use for formatting. Defaults to `.current`.
    ///   - timeZone: The time zone to use for formatting. Defaults to `.current`.
    /// - Returns: A configured DateFormatter instance.
    static func formatter(format: String, locale: Locale = .current, timeZone: TimeZone = .current) -> DateFormatter {
        dateFormatterCacheLogger.log("Requesting DateFormatter for format:\(format) locale:\(locale.identifier) tz:\(timeZone.identifier)")
        let key = NSString(string: "format-\(format)-\(locale.identifier)-\(timeZone.identifier)")
        if let existing = cache.object(forKey: key) {
            dateFormatterCacheLogger.log("Cache hit for formatter key: \(key)")
            return existing
        }
        let df = DateFormatter()
        df.dateFormat = format
        df.locale = locale
        df.timeZone = timeZone
        cache.setObject(df, forKey: key)
        dateFormatterCacheLogger.log("Cache miss: created new DateFormatter for key: \(key)")
        return df
    }

    /// Helper to format a Date into a string with the given styles, locale, and time zone.
    /// - Parameters:
    ///   - date: The date to format.
    ///   - dateStyle: The date style to use.
    ///   - timeStyle: The time style to use.
    ///   - locale: The locale to use for formatting. Defaults to `.current`.
    ///   - timeZone: The time zone to use for formatting. Defaults to `.current`.
    /// - Returns: The formatted date string.
    static func string(from date: Date,
                       dateStyle: DateFormatter.Style = .medium,
                       timeStyle: DateFormatter.Style = .short,
                       locale: Locale = .current,
                       timeZone: TimeZone = .current) -> String {
        return formatter(dateStyle: dateStyle, timeStyle: timeStyle, locale: locale, timeZone: timeZone).string(from: date)
    }

    /// Clears the entire cache (useful for memory warnings or testing).
    static func clearCache() {
        dateFormatterCacheLogger.log("Clearing all cached DateFormatter instances")
        cache.removeAllObjects()
    }
    private init() {}
}

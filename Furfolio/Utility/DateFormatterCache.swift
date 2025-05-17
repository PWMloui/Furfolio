//
//  DateFormatterCache.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import Foundation

/// A cache for expensive-to-create DateFormatter instances.
enum DateFormatterCache {

    private static var cache = [String: DateFormatter]()
    private static let lock = NSLock()

    /// Returns a cached DateFormatter for the given date and time styles.
    /// - Parameters:
    ///   - dateStyle: The desired date style.
    ///   - timeStyle: The desired time style.
    /// - Returns: A configured DateFormatter instance.
    static func formatter(dateStyle: DateFormatter.Style = .medium,
                          timeStyle: DateFormatter.Style = .short) -> DateFormatter {
        let key = "\(dateStyle.rawValue)-\(timeStyle.rawValue)"
        lock.lock()
        defer { lock.unlock() }
        if let existing = cache[key] {
            return existing
        }
        let df = DateFormatter()
        df.dateStyle = dateStyle
        df.timeStyle = timeStyle
        df.locale = Locale.current
        cache[key] = df
        return df
    }

    /// Helper to format a Date into a string with the given styles.
    /// - Parameters:
    ///   - date: The date to format.
    ///   - dateStyle: The date style to use.
    ///   - timeStyle: The time style to use.
    /// - Returns: The formatted date string.
    static func string(from date: Date,
                       dateStyle: DateFormatter.Style = .medium,
                       timeStyle: DateFormatter.Style = .short) -> String {
        return formatter(dateStyle: dateStyle, timeStyle: timeStyle).string(from: date)
    }

    /// Clears the entire cache (useful for memory warnings or testing).
    static func clearCache() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}

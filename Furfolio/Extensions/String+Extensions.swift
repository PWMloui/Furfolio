//
//  String+Extensions.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//


import Foundation
import os
private let stringExtLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "String+Extensions")

/// Utility extensions for String: trimming, localization, validation, and format-based conversions.
extension String {
  /// Thread-safe cache for DateFormatter instances keyed by format strings.
  private static let dateFormatterCache = NSCache<NSString, DateFormatter>()

  /// Retrieves a cached DateFormatter or creates and caches one for the given format.
  private static func dateFormatter(for format: String) -> DateFormatter {
    stringExtLogger.log("Requesting DateFormatter for format: \(format)")
    let key = format as NSString
    if let cached = dateFormatterCache.object(forKey: key) {
      stringExtLogger.log("Using cached DateFormatter for format: \(format)")
      return cached
    }
    let fmt = DateFormatter()
    fmt.dateFormat = format
    dateFormatterCache.setObject(fmt, forKey: key)
    stringExtLogger.log("Created new DateFormatter for format: \(format)")
    return fmt
  }

  /// Thread-safe cache for NumberFormatter instances keyed by locale identifiers.
  private static let currencyFormatterCache = NSCache<NSString, NumberFormatter>()

  /// Retrieves a cached NumberFormatter or creates and caches one for currency formatting for the given locale.
  private static func currencyFormatter(for locale: Locale) -> NumberFormatter {
    stringExtLogger.log("Requesting NumberFormatter for locale: \(locale.identifier)")
    let key = locale.identifier as NSString
    if let cached = currencyFormatterCache.object(forKey: key) {
      stringExtLogger.log("Using cached NumberFormatter for locale: \(locale.identifier)")
      return cached
    }
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = locale
    currencyFormatterCache.setObject(fmt, forKey: key)
    stringExtLogger.log("Created new NumberFormatter for locale: \(locale.identifier)")
    return fmt
  }
    /// Checks if the string contains only numeric digits.
    var isNumeric: Bool {
      !isEmpty && allSatisfy { $0.isNumber }
    }

    /// Checks if the string contains only alphanumeric characters.
    var isAlphanumeric: Bool {
      !isEmpty && allSatisfy { $0.isLetter || $0.isNumber }
    }

    /// Returns the string with leading and trailing whitespace and newlines removed.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Converts the string to an Int, if possible.
    var toInt: Int? {
      stringExtLogger.log("Converting to Int from string: \(self)")
      let result = Int(self)
      if let value = result {
        stringExtLogger.log("Conversion to Int succeeded: \(value)")
      } else {
        stringExtLogger.log("Conversion to Int failed: nil")
      }
      return result
    }

    /// Returns a URL if the string is a valid URL.
    var toURL: URL? {
      URL(string: self)
    }

    /// Localized version of the string using NSLocalizedString.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Checks if the string matches a basic email format.
    var isValidEmail: Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }

    /// Capitalizes only the first letter of the string.
    var capitalizedFirst: String {
      prefix(1).uppercased() + dropFirst()
    }

    /// Escapes HTML entities in the string.
    var htmlEscaped: String {
      let dict: [String: String] = ["&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;"]
      return reduce(into: "") { result, ch in
        result += dict[String(ch)] ?? String(ch)
      }
    }

    /// Unescapes HTML entities in the string.
    var htmlUnescaped: String {
      let dict: [String: String] = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&#39;": "'"]
      var result = self
      for (entity, character) in dict {
        result = result.replacingOccurrences(of: entity, with: character)
      }
      return result
    }

    /// Converts the string to a Double, if possible.
    var toDouble: Double? {
        stringExtLogger.log("Converting to Double from string: \(self)")
        let result = Double(self)
        if let value = result {
            stringExtLogger.log("Conversion to Double succeeded: \(value)")
        } else {
            stringExtLogger.log("Conversion to Double failed: nil")
        }
        return result
    }

    /// Converts the string to a Date using the provided format.
    func toDate(format: String = "yyyy-MM-dd'T'HH:mm:ssZ") -> Date? {
      stringExtLogger.log("Converting to Date from string: \(self) with format: \(format)")
      let formatter = Self.dateFormatter(for: format)
      let result = formatter.date(from: self)
      if let value = result {
        stringExtLogger.log("Conversion to Date succeeded: \(String(describing: value))")
      } else {
        stringExtLogger.log("Conversion to Date failed: nil")
      }
      return result
    }

    /// Formats the string as currency for the given locale.
    func asCurrency(locale: Locale = .current) -> String? {
      stringExtLogger.log("Formatting as currency from string: \(self) for locale: \(locale.identifier)")
      guard let value = Double(self) else {
        stringExtLogger.log("Formatting as currency failed: input is not a valid Double")
        return nil
      }
      let formatter = Self.currencyFormatter(for: locale)
      let result = formatter.string(from: NSNumber(value: value))
      if let formatted = result {
        stringExtLogger.log("Formatting as currency succeeded: \(formatted)")
      } else {
        stringExtLogger.log("Formatting as currency failed: nil")
      }
      return result
    }

    /// Checks if the string is a valid URL.
    var isValidURL: Bool {
      URL(string: self) != nil
    }

    /// Returns only the numeric digits from the string.
    var digitsOnly: String {
        filter { $0.isNumber }
    }

    /// Replaces occurrences matching the regex pattern with the given template.
    func regexReplace(
        pattern: String,
        with template: String
    ) -> String {
        let range = NSRange(startIndex..<endIndex, in: self)
        return (try? NSRegularExpression(pattern: pattern)
            .stringByReplacingMatches(
                in: self,
                options: [],
                range: range,
                withTemplate: template
            )) ?? self
    }

    /// Safely returns substring for the given integer range, else returns an empty string.
    subscript(safe range: Range<Int>) -> String {
        let lowerIndex = index(startIndex,
                               offsetBy: max(0, range.lowerBound),
                               limitedBy: endIndex) ?? endIndex
        let upperIndex = index(startIndex,
                               offsetBy: min(count, range.upperBound),
                               limitedBy: endIndex) ?? endIndex
        return String(self[lowerIndex..<upperIndex])
    }

    /// Converts the string to Decimal using the given locale’s decimal formatter.
    func toDecimal(locale: Locale = .current) -> Decimal? {
        stringExtLogger.log("Converting to Decimal from string: \(self) for locale: \(locale.identifier)")
        let formatter = Self.currencyFormatter(for: locale)
        formatter.numberStyle = .decimal
        let number = formatter.number(from: self)
        let result = number?.decimalValue
        if let value = result {
            stringExtLogger.log("Conversion to Decimal succeeded: \(value as NSNumber)")
        } else {
            stringExtLogger.log("Conversion to Decimal failed: nil")
        }
        return result
    }
}

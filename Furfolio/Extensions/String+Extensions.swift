//
//  String+Extensions.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//


import Foundation

/// Utility extensions for String: trimming, localization, validation, and format-based conversions.
extension String {
  /// Thread-safe cache for DateFormatter instances keyed by format strings.
  private static let dateFormatterCache = NSCache<NSString, DateFormatter>()

  /// Retrieves a cached DateFormatter or creates and caches one for the given format.
  private static func dateFormatter(for format: String) -> DateFormatter {
    let key = format as NSString
    if let cached = dateFormatterCache.object(forKey: key) {
      return cached
    }
    let fmt = DateFormatter()
    fmt.dateFormat = format
    dateFormatterCache.setObject(fmt, forKey: key)
    return fmt
  }

  /// Thread-safe cache for NumberFormatter instances keyed by locale identifiers.
  private static let currencyFormatterCache = NSCache<NSString, NumberFormatter>()

  /// Retrieves a cached NumberFormatter or creates and caches one for currency formatting for the given locale.
  private static func currencyFormatter(for locale: Locale) -> NumberFormatter {
    let key = locale.identifier as NSString
    if let cached = currencyFormatterCache.object(forKey: key) {
      return cached
    }
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = locale
    currencyFormatterCache.setObject(fmt, forKey: key)
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
      Int(self)
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
        Double(self)
    }

    /// Converts the string to a Date using the provided format.
    func toDate(format: String = "yyyy-MM-dd'T'HH:mm:ssZ") -> Date? {
      return Self.dateFormatter(for: format).date(from: self)
    }

    /// Formats the string as currency for the given locale.
    func asCurrency(locale: Locale = .current) -> String? {
      guard let value = Double(self) else { return nil }
      return Self.currencyFormatter(for: locale).string(from: NSNumber(value: value))
    }

    /// Checks if the string is a valid URL.
    var isValidURL: Bool {
      URL(string: self) != nil
    }
}

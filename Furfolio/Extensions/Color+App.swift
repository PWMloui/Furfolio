//
//  Color+App.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//


import SwiftUI
/// Defines the app’s color palette: brand, semantic, and utility colors.
extension Color {
  // MARK: - App Color Palette

  /// Primary brand color used for prominent UI elements.
  static let appPrimary = Color("AppPrimary")

  /// Secondary brand color for accents and highlights.
  static let appSecondary = Color("AppSecondary")

  /// Accent color for interactive controls.
  static let accent = Color("AccentColor")

  /// Default background color for most screens.
  static let background = Color("BackgroundColor")

  /// Background color for cards and panels.
  static let cardBackground = Color("CardBackground")

  // MARK: - Semantic Colors

  /// Indicates success states and confirmations.
  static let success = Color.green

  /// Indicates warning or cautionary states.
  static let warning = Color.yellow

  /// Indicates error or destructive actions.
  static let error = Color.red

  /// Indicates informational or neutral states.
  static let info = Color.blue

  /// Color used for disabled or inactive elements.
  static let disabled = Color.gray.opacity(0.6)

  /// Color for tappable text links.
  static let link = Color("LinkColor")

  /// Color for highlighted UI elements (e.g. badges, tags).
  static let highlight = Color("HighlightColor")

  /// Color for borders and dividers.
  static let border = Color("BorderColor")

  /// Light variant of success (for dark backgrounds).
  static var successLight: Color { success.opacity(0.7) }
  /// Dark variant of success.
  static var successDark: Color { success.opacity(1.3) }

  /// Light variant of warning.
  static var warningLight: Color { warning.opacity(0.7) }
  /// Dark variant of warning.
  static var warningDark: Color { warning.opacity(1.3) }

  /// Light variant of error.
  static var errorLight: Color { error.opacity(0.7) }
  /// Dark variant of error.
  static var errorDark: Color { error.opacity(1.3) }

  // MARK: - Brand Color Variants

  /// Lighter variant of the primary brand color.
  static var appPrimaryLight: Color { appPrimary.opacity(0.7) }

  /// Darker variant of the primary brand color.
  static var appPrimaryDark: Color { appPrimary.opacity(1.3) }

  /// Lighter variant of the secondary brand color.
  static var appSecondaryLight: Color { appSecondary.opacity(0.7) }

  /// Darker variant of the secondary brand color.
  static var appSecondaryDark: Color { appSecondary.opacity(1.3) }

  /// Lighter variant of the accent color.
  static var accentLight: Color { accent.opacity(0.7) }

  /// Darker variant of the accent color.
  static var accentDark: Color { accent.opacity(1.3) }

  // MARK: - Dynamic Colors

  /// Background color that adapts to light/dark mode.
  static var adaptiveBackground: Color {
    Color(UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor.black
        : UIColor(white: 0.95, alpha: 1)
    })
  }

  /// Card background that adapts to light/dark mode.
  static var adaptiveCardBackground: Color {
    Color(UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(white: 0.1, alpha: 1)
        : UIColor.white
    })
  }

  /// Standard separator color that adapts to light/dark mode.
  static var separator: Color {
    Color(UIColor.separator)
  }

  // MARK: - Hex Color Initialization

  /// Creates a Color from a hexadecimal color code string.
  ///
  /// - Parameter hex: String in formats “RRGGBB”, “AARRGGBB”, or shorthand “RGB”.
  ///                  Non-hex characters are ignored. If the string length
  ///                  is unrecognized, returns black.
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

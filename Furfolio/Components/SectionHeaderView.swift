//
//  SectionHeaderView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import os

/// Environment key for default padding used in section headers.
private struct SectionHeaderPaddingKey: EnvironmentKey {
  static let defaultValue = EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16)
}
/// Environment key for default background color used in section headers.
private struct SectionHeaderBackgroundKey: EnvironmentKey {
  static let defaultValue = AppTheme.background
}

/// Environment key for default font used in section headers.
private struct SectionHeaderFontKey: EnvironmentKey {
  static let defaultValue: Font = AppTheme.title
}
/// Environment key for default foreground color used in section headers.
private struct SectionHeaderForegroundKey: EnvironmentKey {
  static let defaultValue: Color = AppTheme.primaryText
}

extension EnvironmentValues {
  var sectionHeaderPadding: EdgeInsets {
    get { self[SectionHeaderPaddingKey.self] }
    set { self[SectionHeaderPaddingKey.self] = newValue }
  }
  var sectionHeaderBackground: Color {
    get { self[SectionHeaderBackgroundKey.self] }
    set { self[SectionHeaderBackgroundKey.self] = newValue }
  }
  var sectionHeaderFont: Font {
    get { self[SectionHeaderFontKey.self] }
    set { self[SectionHeaderFontKey.self] = newValue }
  }
  var sectionHeaderForeground: Color {
    get { self[SectionHeaderForegroundKey.self] }
    set { self[SectionHeaderForegroundKey.self] = newValue }
  }
}

/// A reusable view for section headers, applying consistent styling across the app.
struct SectionHeaderView: View {
  /// The text displayed as the section header.
  let title: String
  let padding: EdgeInsets?
  let backgroundColor: Color?
  let font: Font?
  let foregroundColor: Color?

  @Environment(\.sectionHeaderPadding) private var defaultPadding
  @Environment(\.sectionHeaderBackground) private var defaultBackground
  @Environment(\.sectionHeaderFont) private var defaultFont
  @Environment(\.sectionHeaderForeground) private var defaultForeground

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "SectionHeaderView")

  /// Creates a styled section header.
  ///
  /// - Parameters:
  ///   - title: The text displayed as the section header.
  ///   - padding: Optional custom padding; falls back to theme default.
  ///   - backgroundColor: Optional background color; falls back to theme default.
  ///   - font: Optional font; falls back to theme default.
  ///   - foregroundColor: Optional text color; falls back to theme default.
  init(
    title: String,
    padding: EdgeInsets? = nil,
    backgroundColor: Color? = nil,
    font: Font? = nil,
    foregroundColor: Color? = nil
  ) {
    self.title = title
    self.padding = padding
    self.backgroundColor = backgroundColor
    self.font = font
    self.foregroundColor = foregroundColor
  }

  /// The view body that renders the title text with the section header style.
  var body: some View {
    let pad = padding ?? defaultPadding
    let bg  = backgroundColor ?? defaultBackground
    let fnt = font ?? defaultFont
    let fg  = foregroundColor ?? defaultForeground

    Text(title)
      .font(fnt)
      .foregroundColor(fg)
      .accessibilityAddTraits(.isHeader)
      .onAppear {
          logger.log("SectionHeaderView displayed: \(title)")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(pad)
      .background(bg)
  }
}

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
  static var previews: some View {
    SectionHeaderView(title: "Example Section Header",
                      padding: EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20),
                      backgroundColor: Color(.secondarySystemBackground))
      .padding()
      .previewLayout(.sizeThatFits)
  }
}
#endif

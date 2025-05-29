//
//  TagLabelView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import os

private struct TagLabelFontKey: EnvironmentKey {
  static let defaultValue: Font = AppTheme.caption
}
private struct TagLabelCornerRadiusKey: EnvironmentKey {
  static let defaultValue: CGFloat = AppTheme.cornerRadius
}
private struct TagLabelHorizontalPaddingKey: EnvironmentKey {
  static let defaultValue: CGFloat = 8
}
private struct TagLabelVerticalPaddingKey: EnvironmentKey {
  static let defaultValue: CGFloat = 4
}
private struct TagLabelBackgroundColorKey: EnvironmentKey {
  static let defaultValue: Color = AppTheme.accent
}
private struct TagLabelTextColorKey: EnvironmentKey {
  static let defaultValue: Color = AppTheme.background
}

extension EnvironmentValues {
  var tagLabelFont: Font {
    get { self[TagLabelFontKey.self] }
    set { self[TagLabelFontKey.self] = newValue }
  }
  var tagLabelCornerRadius: CGFloat {
    get { self[TagLabelCornerRadiusKey.self] }
    set { self[TagLabelCornerRadiusKey.self] = newValue }
  }
  var tagLabelHorizontalPadding: CGFloat {
    get { self[TagLabelHorizontalPaddingKey.self] }
    set { self[TagLabelHorizontalPaddingKey.self] = newValue }
  }
  var tagLabelVerticalPadding: CGFloat {
    get { self[TagLabelVerticalPaddingKey.self] }
    set { self[TagLabelVerticalPaddingKey.self] = newValue }
  }
  var tagLabelBackgroundColor: Color {
    get { self[TagLabelBackgroundColorKey.self] }
    set { self[TagLabelBackgroundColorKey.self] = newValue }
  }
  var tagLabelTextColor: Color {
    get { self[TagLabelTextColorKey.self] }
    set { self[TagLabelTextColorKey.self] = newValue }
  }
}

/// A view that displays a text tag or badge with customizable styling and accessibility support.
struct TagLabelView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TagLabelView")
  /// The text content of the tag.
  let text: String

  let font: Font?
  let backgroundColor: Color?
  let textColor: Color?
  let cornerRadius: CGFloat?

  /// Initialize a TagLabelView with optional styling.
  init(
    text: String,
    font: Font? = nil,
    backgroundColor: Color? = nil,
    textColor: Color? = nil,
    cornerRadius: CGFloat? = nil
  ) {
    self.text = text
    self.font = font
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.cornerRadius = cornerRadius
  }

  @Environment(\.tagLabelFont) private var defaultFont
  @Environment(\.tagLabelCornerRadius) private var defaultCornerRadius
  @Environment(\.tagLabelHorizontalPadding) private var defaultHorizontalPadding
  @Environment(\.tagLabelVerticalPadding) private var defaultVerticalPadding
  @Environment(\.tagLabelBackgroundColor) private var defaultBackgroundColor
  @Environment(\.tagLabelTextColor) private var defaultTextColor

  var body: some View {
    // Resolve styling here
    let fontToUse = font ?? defaultFont
    let cornerRadiusToUse = cornerRadius ?? defaultCornerRadius
    let hPadding = defaultHorizontalPadding
    let vPadding = defaultVerticalPadding
    let bgColor = backgroundColor ?? defaultBackgroundColor
    let fgColor = textColor ?? defaultTextColor

    Text(text)
      .font(fontToUse)
      .padding(.horizontal, hPadding)
      .padding(.vertical, vPadding)
      .background(bgColor)
      .foregroundColor(fgColor)
      .cornerRadius(cornerRadiusToUse)
      .accessibilityLabel(Text(text))
      .accessibilityAddTraits(.isStaticText)
      .onAppear {
          logger.log("TagLabelView presented: \(text)")
      }
  }
}

#if DEBUG
struct TagLabelView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            TagLabelView(text: "Aggressive", backgroundColor: .error)
            TagLabelView(text: "Calm", backgroundColor: .success, textColor: .black)
            TagLabelView(text: "Special Shampoo")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif


//
//  TagLabelView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
// TODO: Allow customization of font, corner radius, and support dynamic type; consider theming via environment.

@MainActor
/// A view that displays a text tag or badge with customizable styling and accessibility support.
struct TagLabelView: View {
  /// The text content of the tag.
  let text: String

  /// The font used for the tag text.
  var font: Font = .caption

  /// The background color of the tag.
  var backgroundColor: Color = .appSecondary

  /// The text color of the tag.
  var textColor: Color = .white

  /// The corner radius of the tag’s background.
  var cornerRadius: CGFloat = 8

  var body: some View {
    Text(text)
      .font(font)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(backgroundColor)
      .foregroundColor(textColor)
      .cornerRadius(cornerRadius)
      .accessibilityLabel(Text(text))
      .accessibilityAddTraits(.isStaticText)
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


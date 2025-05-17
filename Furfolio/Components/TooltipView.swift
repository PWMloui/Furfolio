//
//  TooltipView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI

// TODO: Allow configuration of display duration, styling, and support dynamic type sizing.

@MainActor
/// A view that overlays a transient tooltip message when the content is tapped.
struct TooltipView<Content: View>: View {
  /// The tooltip text to display.
  let message: String
  /// Duration (in seconds) the tooltip remains visible.
  let displayDuration: TimeInterval
  /// Font for the tooltip text.
  let font: Font
  /// Padding inside the tooltip.
  let padding: CGFloat
  /// Background color of the tooltip.
  let backgroundColor: Color
  /// Foreground (text) color of the tooltip.
  let textColor: Color
  /// Corner radius for the tooltip background.
  let cornerRadius: CGFloat
  let content: () -> Content
  @State private var isPresented: Bool = false

  init(
    message: String,
    displayDuration: TimeInterval = 2.0,
    font: Font = .caption,
    padding: CGFloat = 8,
    backgroundColor: Color = .info,
    textColor: Color = .white,
    cornerRadius: CGFloat = 6,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.message = message
    self.displayDuration = displayDuration
    self.font = font
    self.padding = padding
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.cornerRadius = cornerRadius
    self.content = content
  }

  var body: some View {
    ZStack {
      content()
        .onTapGesture {
          withAnimation {
            isPresented.toggle()
          }
          DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration) {
            withAnimation {
              isPresented = false
            }
          }
        }
      /// Renders the tooltip overlay when `isPresented` is true.
      if isPresented {
        Text(message)
          .font(font)
          .padding(padding)
          .background(backgroundColor)
          .foregroundColor(textColor)
          .cornerRadius(cornerRadius)
          .transition(.opacity.combined(with: .scale))
          .zIndex(1)
          .accessibilityLabel(Text(message))
          .accessibilityAddTraits(.isStaticText)
      }
    }
  }
}

#if DEBUG
struct TooltipView_Previews: PreviewProvider {
  static var previews: some View {
    TooltipView(message: "This is a tooltip") {
      Image(systemName: "info.circle")
        .font(.largeTitle)
    }
    .padding()
    .previewLayout(.sizeThatFits)
  }
}
#endif

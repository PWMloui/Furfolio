//
//  TooltipView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
import os


private struct TooltipDisplayDurationKey: EnvironmentKey {
  static let defaultValue: TimeInterval = 2.0
}
private struct TooltipFontKey: EnvironmentKey {
  static let defaultValue: Font = AppTheme.caption
}
private struct TooltipPaddingKey: EnvironmentKey {
  static let defaultValue: CGFloat = AppTheme.Spacing.small
}
private struct TooltipBackgroundColorKey: EnvironmentKey {
  static let defaultValue: Color = AppTheme.info
}
private struct TooltipTextColorKey: EnvironmentKey {
  static let defaultValue: Color = .white
}
private struct TooltipCornerRadiusKey: EnvironmentKey {
  static let defaultValue: CGFloat = AppTheme.cornerRadius
}

extension EnvironmentValues {
  var tooltipDisplayDuration: TimeInterval {
    get { self[TooltipDisplayDurationKey.self] }
    set { self[TooltipDisplayDurationKey.self] = newValue }
  }
  var tooltipFont: Font {
    get { self[TooltipFontKey.self] }
    set { self[TooltipFontKey.self] = newValue }
  }
  var tooltipPadding: CGFloat {
    get { self[TooltipPaddingKey.self] }
    set { self[TooltipPaddingKey.self] = newValue }
  }
  var tooltipBackgroundColor: Color {
    get { self[TooltipBackgroundColorKey.self] }
    set { self[TooltipBackgroundColorKey.self] = newValue }
  }
  var tooltipTextColor: Color {
    get { self[TooltipTextColorKey.self] }
    set { self[TooltipTextColorKey.self] = newValue }
  }
  var tooltipCornerRadius: CGFloat {
    get { self[TooltipCornerRadiusKey.self] }
    set { self[TooltipCornerRadiusKey.self] = newValue }
  }
}

/// A view that overlays a transient tooltip message when the content is tapped.
struct TooltipView<Content: View>: View {
  /// The tooltip text to display.
  let message: String
  /// Duration (in seconds) the tooltip remains visible (optional, defaults to environment).
  let displayDuration: TimeInterval?
  /// Font for the tooltip text (optional, defaults to environment).
  let font: Font?
  /// Padding inside the tooltip (optional, defaults to environment).
  let padding: CGFloat?
  /// Background color of the tooltip (optional, defaults to environment).
  let backgroundColor: Color?
  /// Foreground (text) color of the tooltip (optional, defaults to environment).
  let textColor: Color?
  /// Corner radius for the tooltip background (optional, defaults to environment).
  let cornerRadius: CGFloat?
  /// Optional callback when the tooltip is dismissed.
  let onDismiss: (() -> Void)?
  /// Animation to use for showing and hiding; defaults to .easeInOut.
  let animation: Animation
  let content: () -> Content
  @State private var isPresented: Bool = false
  @State private var hideTask: Task<Void, Never>? = nil
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "TooltipView")

  @Environment(\.tooltipDisplayDuration) private var defaultDisplayDuration
  @Environment(\.tooltipFont) private var defaultFont
  @Environment(\.tooltipPadding) private var defaultPadding
  @Environment(\.tooltipBackgroundColor) private var defaultBackgroundColor
  @Environment(\.tooltipTextColor) private var defaultTextColor
  @Environment(\.tooltipCornerRadius) private var defaultCornerRadius

  private var resolvedDisplayDuration: TimeInterval { displayDuration ?? defaultDisplayDuration }
  private var resolvedFont: Font { font ?? defaultFont }
  private var resolvedPadding: CGFloat { padding ?? defaultPadding }
  private var resolvedBackgroundColor: Color { backgroundColor ?? defaultBackgroundColor }
  private var resolvedTextColor: Color { textColor ?? defaultTextColor }
  private var resolvedCornerRadius: CGFloat { cornerRadius ?? defaultCornerRadius }

  init(
    message: String,
    displayDuration: TimeInterval? = nil,
    font: Font? = nil,
    padding: CGFloat? = nil,
    backgroundColor: Color? = nil,
    textColor: Color? = nil,
    cornerRadius: CGFloat? = nil,
    animation: Animation = .easeInOut,
    onDismiss: (() -> Void)? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.message = message
    self.displayDuration = displayDuration
    self.font = font
    self.padding = padding
    self.backgroundColor = backgroundColor
    self.textColor = textColor
    self.cornerRadius = cornerRadius
    self.animation = animation
    self.onDismiss = onDismiss
    logger.log("TooltipView initialized: message='\(message)', displayDuration=\(resolvedDisplayDuration), font=\(String(describing: font)), padding=\(resolvedPadding), backgroundColor=\(resolvedBackgroundColor), textColor=\(resolvedTextColor), cornerRadius=\(resolvedCornerRadius)")
    self.content = content
  }

  var body: some View {
    ZStack {
      content()
        .onTapGesture {
          logger.log("TooltipView tapped, presenting tooltip: \(message)")
          // Cancel any pending hide
          hideTask?.cancel()
          logger.log("Cancelled existing hideTask for tooltip: \(message)")
          
          // Show tooltip
          withAnimation(animation) {
            isPresented = true
          }
          
          // Schedule hide via Task
          hideTask = Task {
              logger.log("Scheduled hideTask to dismiss tooltip after \(resolvedDisplayDuration)s")
            try await Task.sleep(nanoseconds: UInt64(resolvedDisplayDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
              logger.log("TooltipView dismissed: \(message)")
              withAnimation(animation) {
                isPresented = false
              }
              onDismiss?()
            }
          }
        }
      /// Renders the tooltip overlay when `isPresented` is true.
      if isPresented {
        Text(message)
          .font(resolvedFont)
          .dynamicTypeSize(.xSmall ... .accessibility5)
          .padding(resolvedPadding)
          .background(resolvedBackgroundColor)
          .foregroundColor(resolvedTextColor)
          .cornerRadius(resolvedCornerRadius)
          .transition(.opacity.combined(with: .scale))
          .zIndex(1)
          .accessibilityLabel(Text(message))
          .accessibilityAddTraits(.isStaticText)
          .onAppear {
            logger.log("TooltipView overlay appeared: \(message)")
          }
          .onDisappear {
            logger.log("TooltipView overlay onDisappear: \(message)")
          }
          .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
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

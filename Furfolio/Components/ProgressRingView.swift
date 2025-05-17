//
//  ProgressRingView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-06-27 — added configurable SwiftUI progress ring view.
//

import SwiftUI

// TODO: Make animation and styling configurable via environment or initializer; consider extracting to ProgressRingViewModel.

@MainActor
/// A circular progress indicator that visually represents a value between 0.0 and 1.0.
/// Optionally displays custom content in the center.
struct ProgressRingView<CenterContent: View>: View {
  /// The current progress value (0.0 to 1.0).
  let progress: Double

  /// The thickness of the progress ring stroke.
  var lineWidth: CGFloat = 12

  /// Color used for the filled portion of the ring.
  var tint: Color = .accentColor

  /// Color used for the unfilled track portion of the ring.
  var trackColor: Color = Color(.systemGray5)

  /// Optional closure producing the view displayed in the ring’s center.
  private let centerContent: (() -> CenterContent)?

  /// Default animation for progress changes.
  nonisolated static var defaultAnimation: Animation {
    .easeInOut(duration: 0.5)
  }

  /// Animation used when the progress value changes.
  private var progressAnimation: Animation = defaultAnimation

  var body: some View {
    ZStack {
      // Track circle
      Circle()
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .foregroundColor(trackColor)

      // Progress circle
      Circle()
        .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
        .rotation(Angle(degrees: -90))
        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        .foregroundColor(tint)
        .animation(progressAnimation, value: progress)

      // Center content (if provided)
      if let content = centerContent {
        content()
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

extension ProgressRingView {
  /// Creates a ProgressRingView with optional center content and customizable animation.
  @MainActor
  init(
    progress: Double,
    lineWidth: CGFloat = 12,
    tint: Color = .accentColor,
    trackColor: Color = Color(.systemGray5),
    animation: Animation = defaultAnimation,
    centerContent: (() -> CenterContent)? = nil
  ) {
    self.progress = progress
    self.lineWidth = lineWidth
    self.tint = tint
    self.trackColor = trackColor
    self.progressAnimation = animation
    self.centerContent = centerContent
  }
}

extension ProgressRingView where CenterContent == AnyView {
  /// Creates a ProgressRingView displaying a percentage label with customizable animation.
  @MainActor
  init(
    progress: Double,
    lineWidth: CGFloat = 12,
    tint: Color = .accentColor,
    trackColor: Color = Color(.systemGray5),
    animation: Animation = defaultAnimation,
    showsPercentage: Bool
  ) {
    self.progress = progress
    self.lineWidth = lineWidth
    self.tint = tint
    self.trackColor = trackColor
    self.progressAnimation = animation

    if showsPercentage {
      self.centerContent = {
        AnyView(
          Text("\(Int((progress * 100).rounded()))%")
            .font(.system(size: lineWidth * 0.8, weight: .semibold))
            .foregroundColor(tint)
        )
      }
    } else {
      self.centerContent = nil
    }
  }
}

#if DEBUG
struct ProgressRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Simple percentage ring
            ProgressRingView(progress: 0.25, showsPercentage: true)
                .frame(width: 100, height: 100)

            // Thicker green ring, percentage
            ProgressRingView(progress: 0.75, lineWidth: 20, tint: .green, showsPercentage: true)
                .frame(width: 120, height: 120)

            // Custom center content (paw icon)
            ProgressRingView(progress: 0.5, lineWidth: 8, tint: .orange, trackColor: .black.opacity(0.1)) {
                AnyView(
                    Image(systemName: "pawprint.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                )
            }
            .frame(width: 80, height: 80)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

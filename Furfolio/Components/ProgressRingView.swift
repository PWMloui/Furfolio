//
//  ProgressRingView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-06-27 — added configurable SwiftUI progress ring view.
//

import SwiftUI
import os

// TODO: Make animation and styling configurable via environment or initializer; consider extracting to ProgressRingViewModel.

private struct ProgressRingLineWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 12 }
private struct ProgressRingAnimationKey: EnvironmentKey { static let defaultValue: Animation = .easeInOut(duration: 0.5) }
private struct ProgressRingGradientKey: EnvironmentKey { static let defaultValue: Gradient? = nil }

extension EnvironmentValues {
  var progressRingLineWidth: CGFloat { self[ProgressRingLineWidthKey.self] }
  var progressRingAnimation: Animation { self[ProgressRingAnimationKey.self] }
  var progressRingGradient: Gradient? { self[ProgressRingGradientKey.self] }
}

/// A circular progress indicator that visually represents a value between 0.0 and 1.0,
/// with optional custom content in the center.
/// - Parameters:
///   - progress: Binding to a Double (0…1) representing current progress.
///   - strokeGradient: Optional gradient for the progress stroke; defaults to accent.
///   - lineCap: Line cap style for the ring stroke.
///   - lineJoin: Line join style for the ring stroke.
///   - dash: Dash pattern for the stroke.
///   - lineWidthParam: Optional custom width; falls back to environment default.
///   - animationStyle: Style of animation applied when progress changes.
///   - onComplete: Closure called once when progress crosses completion.
///   - isIndeterminate: If true, rotates indefinitely rather than showing trim.
struct ProgressRingView<CenterContent: View>: View {
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ProgressRingView")
  @Environment(\.progressRingLineWidth) private var envLineWidth
  @Environment(\.progressRingAnimation) private var envAnimation
  @Environment(\.progressRingGradient) private var envGradient

  enum AnimationStyle {
    case ease, spring(response: Double, dampingFraction: Double)
    case custom(Animation)
    var animation: Animation {
      switch self {
      case .ease: return .easeInOut(duration: 0.5)
      case .spring(let response, let damping): return .spring(response: response, dampingFraction: damping)
      case .custom(let anim): return anim
      }
    }
  }

  @Binding var progress: Double

  var strokeGradient: Gradient?
  var lineCap: CGLineCap
  var lineJoin: CGLineJoin
  var dash: [CGFloat]
  var lineWidthParam: CGFloat?
  var animationStyle: AnimationStyle
  var onComplete: (() -> Void)?
  var isIndeterminate: Bool

  private let centerContent: (() -> CenterContent)?

  @State private var animateIndeterminate = false
  @State private var previousProgress: Double = 0

  var lineWidth: CGFloat { lineWidthParam ?? envLineWidth }

  var body: some View {
    GeometryReader { geo in
      ZStack {
        // Track circle
        Circle()
          .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap, lineJoin: lineJoin, dash: dash))
          .foregroundColor(AppTheme.disabled)

        // Progress circle
        Circle()
          .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
          .stroke(
            AngularGradient(gradient: strokeGradient ?? envGradient ?? Gradient(colors: [AppTheme.accent]), center: .center),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap, lineJoin: lineJoin, dash: dash)
          )
          .rotationEffect(Angle(degrees: isIndeterminate ? (animateIndeterminate ? 360 : 0) : -90))
          .animation(isIndeterminate ? nil : animationStyle.animation, value: progress)
          .onChange(of: progress) { newValue in
            logger.log("Progress updated to \(newValue)")
            if newValue >= 1.0, previousProgress < 1.0 {
              logger.log("Progress completed")
              onComplete?()
            }
            previousProgress = newValue
          }
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { value in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                let angle = atan2(vector.dy, vector.dx) + .pi / 2
                let fixedAngle = angle < 0 ? angle + 2 * .pi : angle
                let newProgress = Double(fixedAngle / (2 * .pi))
                progress = min(max(newProgress, 0), 1)
              }
              .onEnded { _ in }
          )

        // Center content (if provided)
        if let content = centerContent {
          content()
        }
      }
      .accessibilityValue("\(Int(progress * 100)) percent")
      .accessibilityLabel(Text("Progress: \(Int(progress * 100)) percent"))
      .onAppear {
        logger.log("ProgressRingView appeared with progress: \(progress)")
        if isIndeterminate {
          withAnimation(envAnimation.repeatForever(autoreverses: false)) {
            animateIndeterminate = true
          }
          logger.log("Indeterminate animation started")
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}


extension ProgressRingView where CenterContent == AnyView {
  init(
    progress: Binding<Double>,
    showsPercentage: Bool,
    strokeGradient: Gradient? = nil,
    lineCap: CGLineCap = .round,
    lineJoin: CGLineJoin = .round,
    dash: [CGFloat] = [],
    lineWidthParam: CGFloat? = nil,
    animationStyle: AnimationStyle = .ease,
    onComplete: (() -> Void)? = nil,
    isIndeterminate: Bool = false
  ) {
    self._progress = progress
    self.strokeGradient = strokeGradient
    self.lineCap = lineCap
    self.lineJoin = lineJoin
    self.dash = dash
    self.lineWidthParam = lineWidthParam
    self.animationStyle = animationStyle
    self.onComplete = onComplete
    self.isIndeterminate = isIndeterminate

    if showsPercentage {
      self.centerContent = {
        AnyView(
          Text("\(Int((progress.wrappedValue * 100).rounded()))%")
            .font(AppTheme.subtitle)
            .foregroundColor(AppTheme.accent)
        )
      }
    } else {
      self.centerContent = nil
    }
  }

  /// Allows custom centerContent for AnyView variant.
  init(
    progress: Binding<Double>,
    showsPercentage: Bool = false,
    strokeGradient: Gradient? = nil,
    lineCap: CGLineCap = .round,
    lineJoin: CGLineJoin = .round,
    dash: [CGFloat] = [],
    lineWidthParam: CGFloat? = nil,
    animationStyle: AnimationStyle = .ease,
    onComplete: (() -> Void)? = nil,
    isIndeterminate: Bool = false,
    centerContent: @escaping () -> AnyView
  ) {
    self._progress = progress
    self.strokeGradient = strokeGradient
    self.lineCap = lineCap
    self.lineJoin = lineJoin
    self.dash = dash
    self.lineWidthParam = lineWidthParam
    self.animationStyle = animationStyle
    self.onComplete = onComplete
    self.isIndeterminate = isIndeterminate
    self.centerContent = centerContent
  }
}

#if DEBUG
struct ProgressRingView_Previews: PreviewProvider {
  @State static var progress1 = 0.25
  @State static var progress2 = 0.75
  @State static var progress3 = 0.5

  static var previews: some View {
    VStack(spacing: 20) {
      // Simple percentage ring
      ProgressRingView(progress: $progress1, showsPercentage: true)
        .frame(width: 100, height: 100)

      // Thicker green ring, percentage
      ProgressRingView(progress: $progress2, showsPercentage: true, strokeGradient: Gradient(colors: [.green, .blue]), lineCap: .round, lineJoin: .round, dash: [], animationStyle: .ease)
        .frame(width: 120, height: 120)

      // Custom center content (paw icon)
      ProgressRingView<AnyView>(
        progress: $progress3,
        showsPercentage: false,
        strokeGradient: nil,
        lineCap: .round,
        lineJoin: .round,
        dash: [],
        animationStyle: .ease,
        onComplete: nil,
        isIndeterminate: false,
        centerContent: {
          AnyView(
            Image(systemName: "pawprint.fill")
              .font(.title)
              .foregroundColor(.orange)
          )
        }
      )
      .frame(width: 80, height: 80)
    }
    .padding()
    .previewLayout(.sizeThatFits)
  }
}
#endif

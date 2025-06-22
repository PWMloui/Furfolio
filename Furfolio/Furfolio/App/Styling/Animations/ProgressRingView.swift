//
//  ProgressRingView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//


import SwiftUI

/// A view that displays progress in a circular ring shape.
/// It is data-driven and animates changes to its progress value.
struct ProgressRingView: View {
    /// The progress value to display, from 0.0 to 1.0.
    var progress: Double
    
    /// The color of the progress ring. Defaults to the app's primary theme color.
    var color: Color = AppTheme.Colors.primary
    
    /// The color of the background track.
    var backgroundColor: Color = AppTheme.Colors.background.opacity(0.2)
    
    /// The thickness of the ring.
    var lineWidth: CGFloat = 12.0

    var body: some View {
        ZStack {
            // 1. The background track of the ring
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // 2. The foreground progress ring
            Circle()
                // The .trim modifier is what creates the progress effect
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                // Start the ring from the top (12 o'clock) instead of the default right (3 o'clock)
                .rotationEffect(.degrees(-90))
                // Animate any changes to the progress value smoothly
                .animation(.easeOut(duration: 0.8), value: progress)
        }
        // Add padding to prevent the stroke from being clipped at the edges
        .padding(lineWidth / 2)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}


// MARK: - Preview

#if DEBUG
struct ProgressRingView_Previews: PreviewProvider {
    // A wrapper view to make the preview interactive
    struct PreviewWrapper: View {
        @State private var progressValue: Double = 0.75

        var body: some View {
            VStack(spacing: 40) {
                ProgressRingView(
                    progress: progressValue,
                    color: AppTheme.Colors.success,
                    lineWidth: 20
                )
                .frame(width: 200, height: 200)

                VStack {
                    Text("Progress: \(Int(progressValue * 100))%")
                        .font(AppTheme.Fonts.headline)
                    
                    // Slider to demonstrate the animation live
                    Slider(value: $progressValue, in: 0...1)
                }
                .padding()
            }
            .padding(AppTheme.Spacing.large)
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.CornerRadius.large)
            .padding()
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

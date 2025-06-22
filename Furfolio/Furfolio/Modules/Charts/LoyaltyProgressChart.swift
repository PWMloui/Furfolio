//
//  ProgressRingView.swift
//  Furfolio
//
//  Created by ChatGPT on 6/22/25.
//

import SwiftUI

/// A reusable circular progress ring component.
struct ProgressRingView: View {
    /// Progress value between 0.0 and 1.0
    var progress: Double

    /// The color of the progress arc
    var color: Color

    /// The color of the background ring
    var backgroundColor: Color

    /// Thickness of the ring
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    backgroundColor.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth)
                )

            // Foreground progress ring
            Circle()
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress ring")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}

#if DEBUG
struct ProgressRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            ProgressRingView(
                progress: 0.9,
                color: .green,
                backgroundColor: .gray.opacity(0.3),
                lineWidth: 16
            )
            .frame(width: 120, height: 120)

            ProgressRingView(
                progress: 0.4,
                color: .orange,
                backgroundColor: .gray.opacity(0.3),
                lineWidth: 16
            )
            .frame(width: 120, height: 120)
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .previewLayout(.sizeThatFits)
    }
}
#endif

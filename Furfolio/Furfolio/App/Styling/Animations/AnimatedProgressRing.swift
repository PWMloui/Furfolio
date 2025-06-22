//
//  AnimatedProgressRing.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A configurable animated circular progress ring used for KPIs, dashboards, or loyalty programs.
struct AnimatedProgressRing: View {
    /// Progress as a percentage (0.0 to 1.0).
    var percent: Double

    /// Optional label shown below the ring.
    var label: String? = nil

    /// Optional SF Symbol shown inside the ring.
    var icon: String? = nil

    /// Color of the progress ring and text/icon.
    var color: Color = .accentColor

    /// Size of the ring view (width/height). Default is 86.
    var size: CGFloat = 86

    /// Width of the circular stroke line.
    var ringWidth: CGFloat = 14

    /// Background ring color.
    var backgroundColor: Color = Color(.systemGray5)

    /// Whether the ring should animate from 0 to the target percent.
    var animate: Bool = true

    /// Whether to display the percentage value in the center.
    var showPercentText: Bool = true

    @State private var animatedPercent: Double = 0.0

    private enum Constants {
        static let animationDuration: Double = 1.1
        static let iconOffset: CGFloat = 22
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                // Base circle
                Circle()
                    .stroke(backgroundColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

                // Progress arc
                Circle()
                    .trim(from: 0, to: animate ? animatedPercent : percent)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: Constants.animationDuration), value: animatedPercent)

                // Center: % and/or icon
                VStack(spacing: 2) {
                    if showPercentText {
                        Text("\(Int((animate ? animatedPercent : percent) * 100))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                            .minimumScaleFactor(0.8)
                    }
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(color.opacity(0.75))
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: size, height: size)
            .onAppear(perform: startAnimation)
            .onChange(of: percent) { _, _ in startAnimation() }

            if let label = label {
                Text(label)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.97))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label ?? "Progress Ring")
        .accessibilityValue("\(Int(percent * 100)) percent complete")
    }

    private func startAnimation() {
        if animate {
            withAnimation(.easeOut(duration: Constants.animationDuration)) {
                animatedPercent = percent
            }
        }
    }
}

#if DEBUG
struct AnimatedProgressRing_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 28) {
            AnimatedProgressRing(percent: 0.83, label: "Loyalty", icon: "star.fill", color: .yellow)
            AnimatedProgressRing(percent: 0.51, label: "Revenue Goal", icon: "dollarsign.circle.fill", color: .green, showPercentText: true)
            AnimatedProgressRing(percent: 0.34, label: "Retention", icon: "heart.fill", color: .pink, showPercentText: false)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif

//
//  ShimmerView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced for accessibility, maintainability, and customization.
//

import SwiftUI

/// A reusable shimmer animation for loading placeholders and skeleton states.
/// Usage: `ShimmerView().frame(height: 40)`
/// Can be masked over any shape for visual polish.
struct ShimmerView: View {
    @State private var phase: CGFloat = -0.7

    private enum Constants {
        static let animationSpeed: Double = 1.0
        static let blurRadius: CGFloat = 2
        static let rotationAngle: Double = 7
        static let baseOpacity: Double = 0.16
        static let shimmerOpacity: [Double] = [0.07, 0.35, 0.07]
    }

    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(Constants.baseOpacity),
                            Color.gray.opacity(Constants.baseOpacity * 2),
                            Color.gray.opacity(Constants.baseOpacity)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    Rectangle()
                        .fill(Color.white)
                        .blur(radius: Constants.blurRadius)
                )
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: Constants.shimmerOpacity.map { Color.white.opacity($0) }),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(Constants.rotationAngle))
                    .offset(x: phase * geo.size.width)
                    .accessibilityHidden(true) // Decorative shimmer
                )
                .animation(.linear(duration: Constants.animationSpeed).repeatForever(autoreverses: false), value: phase)
                .onAppear {
                    phase = 0.9
                }
        }
        .clipped()
    }
}

// MARK: - Preview

#if DEBUG
struct ShimmerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 18) {
            ShimmerView()
                .frame(height: 22)
                .cornerRadius(8)

            ShimmerView()
                .frame(width: 120, height: 36)
                .cornerRadius(9)

            RoundedRectangle(cornerRadius: 11)
                .fill(Color.gray.opacity(0.16))
                .overlay(ShimmerView().cornerRadius(11))
                .frame(width: 220, height: 44)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif

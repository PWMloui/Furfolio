//
//  LoadingSpinnerView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A reusable, theme-aware loading spinner for asynchronous operations.
//

import SwiftUI

/// A reusable loading spinner view that indicates a background activity is in progress.
/// It is theme-aware and customizable for different sizes and contexts.
struct LoadingSpinnerView: View {
    /// The diameter of the spinner.
    var size: CGFloat = 48
    
    /// The color of the spinner's stroke. Defaults to the app's primary theme color.
    var color: Color = AppTheme.Colors.primary
    
    /// The thickness of the spinner's stroke.
    var lineWidth: CGFloat = 5

    @State private var isAnimating = false

    var body: some View {
        Circle()
            // Using trim to create a partial circle, which makes the rotation more apparent.
            .trim(from: 0.1, to: 1.0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .onAppear {
                // Using a repeating linear animation creates a smooth, continuous spin.
                withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .accessibilityLabel("Loading")
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingSpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            Text("Standard Spinner")
            LoadingSpinnerView()
            
            Text("Large Green Spinner")
                .font(AppTheme.Fonts.headline)
            
            LoadingSpinnerView(
                size: 80,
                color: AppTheme.Colors.success,
                lineWidth: 8
            )
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif

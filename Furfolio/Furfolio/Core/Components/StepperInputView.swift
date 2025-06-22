//
//  StepperInputView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A reusable, theme-aware stepper control for numerical input.
//  All styling uses ONLY modular tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows),
//  with full accessibility and haptic feedback.
//

import SwiftUI

// MARK: - StepperInputView (Tokenized, Accessible, Haptic, Modular)

/// A custom stepper control for inputting numerical values with plus/minus buttons.
/// It is fully customizable and integrates with the app's haptics and design system.
/// All styling uses modular tokens to ensure consistency and accessibility.
struct StepperInputView: View {
    /// An optional label to display next to the stepper.
    var label: LocalizedStringKey?
    
    /// The binding to the integer value this stepper controls.
    @Binding var value: Int
    
    /// The allowed range for the value.
    var range: ClosedRange<Int> = 0...100
    
    /// The amount to increment or decrement with each tap.
    var step: Int = 1

    var body: some View {
        HStack {
            if let label = label {
                Text(label)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
            }

            Spacer()

            HStack(spacing: AppSpacing.medium) {
                // MARK: - Decrement Button
                Button {
                    decrement()
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .disabled(value <= range.lowerBound)
                .accessibilityLabel("Decrement")

                // MARK: - Value Display
                Text("\(value)")
                    .font(AppFonts.headline.monospacedDigit()) // Monospaced for layout stability
                    .frame(minWidth: 50)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                // MARK: - Increment Button
                Button {
                    increment()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(value >= range.upperBound)
                .accessibilityLabel("Increment")
            }
            .font(AppFonts.title2)
            .foregroundColor(AppColors.primary)
        }
        .padding(AppSpacing.medium)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(value)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                increment()
            case .decrement:
                decrement()
            @unknown default:
                break
            }
        }
    }

    private func increment() {
        guard value < range.upperBound else { return }
        value += step
        HapticManager.selection()
    }

    private func decrement() {
        guard value > range.lowerBound else { return }
        value -= step
        HapticManager.selection()
    }
}

// MARK: - Preview

#if DEBUG
struct StepperInputView_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var groomingDuration = 60
        @State private var quantity = 1

        var body: some View {
            Form {
                Section("Appointment Settings") {
                    StepperInputView(
                        label: "Duration (min)",
                        value: $groomingDuration,
                        range: 15...180,
                        step: 5
                    )
                }

                Section("Inventory") {
                    StepperInputView(
                        label: "Shampoo Bottles",
                        value: $quantity,
                        range: 0...10
                    )
                }
            }
            .font(AppFonts.body)
            .foregroundColor(AppColors.textPrimary)
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
        }
    }

    static var previews: some View {
        PreviewWrapper()
    }
}
#endif

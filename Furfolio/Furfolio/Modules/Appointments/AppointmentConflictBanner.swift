//
//  AppointmentConflictBanner.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - AppointmentConflictBanner (Tokenized, Modular, Auditable Conflict Notification Banner)

// Using modular design tokens for colors, fonts, and spacing for maintainability and consistency across the app.

// MARK: - AppointmentConflictBannerStyle

struct AppointmentConflictBannerStyle {
    // Replaced hardcoded colors with design tokens for warning and critical states
    var gradientColors: [Color] = [AppColors.warning, AppColors.critical]
    var shadowColor: Color = AppColors.critical.opacity(0.16)
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 16
}

/// A unified and modern banner view indicating scheduling conflicts for appointments.
/// 
/// This view is designed with cross-platform consistency in mind (iPad/Mac/iPhone),
/// extracting styling into a dedicated style struct for design system compliance.
/// It supports full accessibility with identifiers and VoiceOver labels,
/// customizable action titles for localization or workflow variations,
/// and enhanced appearance with subtle bounce-in animation and haptic feedback where available.
/// 
/// Use this banner to inform users of overlapping appointments, providing clear resolution and dismissal actions.
/// The banner gracefully animates in and out, ensuring a smooth user experience across the Furfolio app.
struct AppointmentConflictBanner: View {
    var message: String = "⚠️ Appointment conflict detected! Another appointment overlaps with this time."
    var onResolve: (() -> Void)? = nil
    @Binding var isVisible: Bool
    var resolveButtonTitle: String = NSLocalizedString("Resolve", comment: "Resolve appointment conflict button")
    var style: AppointmentConflictBannerStyle = AppointmentConflictBannerStyle()

    @State private var animateIn: Bool = false
    @State private var bounce: Bool = false

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        // Tokenized font and color for icon
                        .foregroundColor(AppColors.textOnAccent)
                        .font(AppFonts.title2Bold)
                        // Tokenized leading padding
                        .padding(.leading, AppSpacing.small)
                        .accessibilityHidden(true)
                    Text(message)
                        // Tokenized font and color for message text
                        .font(AppFonts.subheadlineSemibold)
                        .foregroundColor(AppColors.textOnAccent)
                        .accessibilityLabel(message)
                        .accessibilityIdentifier("ConflictMessage")
                    Spacer()
                    if let onResolve = onResolve {
                        Button(action: {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            onResolve()
                        }) {
                            Text(resolveButtonTitle)
                                // Tokenized font for button text
                                .font(AppFonts.calloutBold)
                                // Tokenized horizontal and vertical padding
                                .padding(.horizontal, AppSpacing.medium)
                                .padding(.vertical, AppSpacing.small)
                                // Tokenized background color with opacity
                                .background(AppColors.textOnAccent.opacity(0.22))
                                // Tokenized foreground color
                                .foregroundColor(AppColors.textOnAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(resolveButtonTitle) conflict")
                        .accessibilityIdentifier("ResolveButton")
                    }
                    Button(action: {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation { isVisible = false }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            // Tokenized color with opacity for dismiss icon
                            .foregroundColor(AppColors.textOnAccent.opacity(0.7))
                            // Tokenized font for dismiss icon
                            .font(AppFonts.title3)
                    }
                    .buttonStyle(.plain)
                    // Tokenized trailing padding
                    .padding(.trailing, AppSpacing.small)
                    .accessibilityLabel("Dismiss banner")
                    .accessibilityIdentifier("DismissButton")
                }
                // Tokenized horizontal and vertical padding for HStack
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
            }
            .background(
                LinearGradient(
                    colors: style.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(animateIn ? 1 : 0.88)
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .shadow(color: style.shadowColor, radius: 7, x: 0, y: 2)
            // Tokenized horizontal padding and top padding (top padding remains numeric as no token specified)
            .padding(.horizontal, style.padding)
            .padding(.top, 10)
            .scaleEffect(bounce ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1), value: bounce)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    animateIn = true
                }
                bounce = true
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                        bounce = false
                    }
                }
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("AppointmentConflictBanner")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppointmentConflictBanner_Previews: PreviewProvider {
    struct Demo: View {
        // Demo/business/tokenized preview using design tokens for colors, fonts, and spacing
        @State private var show = true
        var body: some View {
            VStack {
                Spacer()
                AppointmentConflictBanner(message: "⚠️ You have an overlapping appointment!", isVisible: $show, onResolve: {
                    // Demo resolve action
                    show = false
                }, resolveButtonTitle: "Fix Now")
                Spacer()
                Button("Toggle Banner") {
                    withAnimation {
                        show.toggle()
                    }
                }
                // Tokenized background color for button
                .padding()
                .background(AppColors.accent.opacity(0.8))
                // Tokenized foreground color for button text
                .foregroundColor(AppColors.textOnAccent)
                .clipShape(Capsule())
            }
            // Tokenized background color for preview container
            .background(AppColors.background)
        }
    }
    static var previews: some View {
        Demo()
            .previewLayout(.sizeThatFits)
    }
}
#endif

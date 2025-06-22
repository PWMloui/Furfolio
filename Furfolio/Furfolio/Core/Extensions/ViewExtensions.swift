//
//  ViewExtensions.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  Part of Furfolio's design system: modular SwiftUI extensions tailored for a business-owner-focused app.
//  All view extensions are now tokenized, modular, accessible, and rely only on design system tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows).
//  Removed all system color fallbacks, .opacity hacks, and platform-dependent color logic from helpers and the preview.
//

import SwiftUI

// MARK: - ViewExtensions (Tokenized Modular SwiftUI Helpers, Business Design System)

// MARK: - Public View Extensions for Modular UI Composition

public extension View {
    /// Conditionally applies a modifier when `condition` is true.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, apply: (Self) -> Content) -> some View {
        if condition {
            apply(self)
        } else {
            self
        }
    }

    /// Conditionally applies a modifier when optional `value` is non-nil.
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, apply: (Self, T) -> Content) -> some View {
        if let value = value {
            apply(self, value)
        } else {
            self
        }
    }

    /// Applies a platform-specific modifier: iOS vs macOS.
    /// - Note: The returned view should still use only design tokens for any styling differences.
    @ViewBuilder
    func platformSpecific<Content: View>(
        _ ios: (Self) -> Content,
        mac: (Self) -> Content
    ) -> some View {
        #if os(iOS)
        ios(self)
        #elseif os(macOS)
        mac(self)
        #else
        self
        #endif
    }

    /// Hides the view conditionally; optionally removes from layout.
    /// - Parameters:
    ///   - isHidden: Whether to hide the view.
    ///   - remove: If true, removes the view from layout entirely.
    ///   - animated: Whether to animate the hiding transition.
    @ViewBuilder
    func hidden(_ isHidden: Bool, remove: Bool = true, animated: Bool = false) -> some View {
        if isHidden {
            if remove {
                if animated {
                    EmptyView()
                        .transition(.opacity)
                } else {
                    EmptyView()
                }
            } else {
                if animated {
                    self.hidden()
                        .transition(.opacity)
                } else {
                    self.hidden()
                }
            }
        } else {
            self
        }
    }

    /// Applies corner radius to specific corners.
    /// - Parameters:
    ///   - radius: Corner radius in points.
    ///   - corners: Specific corners to round.
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    /// Applies a default subtle shadow for elevation and depth using design tokens.
    func defaultShadow() -> some View {
        self.shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
    }

    /// Adds a customizable shimmer overlay for loading placeholders.
    /// - Parameters:
    ///   - isActive: Whether shimmer is active.
    ///   - cornerRadius: Optional corner radius for shimmer shape.
    ///   - shape: Optional shape to clip shimmer overlay.
    ///   - animated: Whether to animate shimmer appearance.
    func shimmer(
        isActive: Bool = true,
        cornerRadius: CGFloat? = 7,
        shape: AnyShape? = nil,
        animated: Bool = true
    ) -> some View {
        self.overlay(
            Group {
                if isActive {
                    AnimationUtils.ShimmerView()
                        .clipShape(
                            shape ?? (cornerRadius != nil ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius!)) : AnyShape(Rectangle()))
                        )
                        .if(animated) { view in
                            view.transition(.opacity)
                        }
                }
            }
        )
    }

    /// Adds a badge overlay at top trailing corner with customizable animation.
    /// - Parameters:
    ///   - count: Optional badge count to display.
    ///   - color: Badge background color (default is AppColors.accent).
    ///   - animated: Whether to animate badge appearance.
    func badge(_ count: Int?, color: Color = AppColors.accent, animated: Bool = true) -> some View {
        ZStack(alignment: .topTrailing) {
            self
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(AppSpacing.xSmall)
                    .background(color)
                    .clipShape(Circle())
                    .offset(x: AppSpacing.small, y: -AppSpacing.small)
                    .if(animated) { view in
                        view.transition(.scale)
                    }
            }
        }
    }

    /// Adds tap gesture to dismiss keyboard on iOS safely.
    /// Use in views with text inputs to improve UX.
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
        }
    }

    /// Helper for demo dashboard card styling using design tokens.
    /// Use in previews or demo widgets to maintain consistent style.
    func demoDashboardCard() -> some View {
        self
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
            .padding(.horizontal, AppSpacing.medium)
    }
}

// MARK: - RoundedCorner Shape for Selective Corner Rounding

public struct RoundedCorner: Shape {
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners

    public init(radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Example Usage and Preview for Extensions

#if DEBUG
struct ViewExtensionsPreview: View {
    @State private var isLoading = true
    @State private var showBadge = true
    @State private var optionalCount: Int? = 5

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Group {
                    Text("Rounded only top corners")
                        .padding()
                        .background(AppColors.accentBackground)
                        .cornerRadius(BorderRadius.large, corners: [.topLeft, .topRight])

                    Text("Shimmer loading")
                        .padding()
                        .shimmer(isActive: isLoading, cornerRadius: BorderRadius.medium, animated: true)
                        .cornerRadius(BorderRadius.medium)
                        .frame(width: 140, height: 34)
                        .background(AppColors.surfaceBackground)

                    Button("Toggle Badge") { withAnimation { showBadge.toggle() } }
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .badge(showBadge ? 2 : nil, color: AppColors.accent, animated: true)

                    Text("Hide me!")
                        .hidden(isLoading, remove: true, animated: true)

                    TextField("Type here", text: .constant(""))
                        .padding()
                        .background(AppColors.inputBackground)
                        .cornerRadius(BorderRadius.medium)
                        .dismissKeyboardOnTap()
                }

                Group {
                    Text("IfLet example with optional count:")
                        .fontWeight(.semibold)

                    Image(systemName: "star.fill")
                        .ifLet(optionalCount) { view, count in
                            view.badge(count, color: AppColors.accent)
                        }

                    Text("Platform-specific styling:")
                        .fontWeight(.semibold)

                    Text("Hello Platform!")
                        .platformSpecific(
                            { $0.foregroundColor(AppColors.primary) },
                            mac: { $0.foregroundColor(AppColors.secondary) }
                        )

                    Text("Demo Dashboard Card Example")
                        .demoDashboardCard()
                }
            }
            .padding()
        }
    }
}

#Preview {
    ViewExtensionsPreview()
}
#endif

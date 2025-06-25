//
//  SpringSlideTransition.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, modular, preview/testable, and robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol SpringSlideTransitionAnalyticsLogger {
    func log(event: String, edge: Edge)
}
public struct NullSpringSlideTransitionAnalyticsLogger: SpringSlideTransitionAnalyticsLogger {
    public init() {}
    public func log(event: String, edge: Edge) {}
}

/// A view modifier applying a directional spring slide transition,
/// now with design token compliance, analytics, and accessibility.
private struct SpringSlideModifier: ViewModifier {
    let edge: Edge
    var analyticsLogger: SpringSlideTransitionAnalyticsLogger = NullSpringSlideTransitionAnalyticsLogger()

    // Tokenized constants, robust fallback.
    private enum Tokens {
        static let insertionStiffness: Double = AppTheme.Animation.springSlideInsertionStiffness ?? 260
        static let insertionDamping: Double = AppTheme.Animation.springSlideInsertionDamping ?? 26
        static let removalStiffness: Double = AppTheme.Animation.springSlideRemovalStiffness ?? 220
        static let removalDamping: Double = AppTheme.Animation.springSlideRemovalDamping ?? 19
    }

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Tokens.insertionStiffness,
                            damping: Tokens.insertionDamping
                        )),
                    removal: .move(edge: edge.opposite)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Tokens.removalStiffness,
                            damping: Tokens.removalDamping
                        ))
                )
            )
            .onAppear {
                analyticsLogger.log(event: "springSlide_insertion", edge: edge)
            }
            .onDisappear {
                analyticsLogger.log(event: "springSlide_removal", edge: edge)
            }
            .accessibilityAddTraits(.isModal) // For major transitions (optional, non-breaking)
    }
}

extension AnyTransition {
    /// A custom slide transition with a spring effect from a given edge.
    /// - Parameter edge: The edge from which the view enters.
    /// - Parameter analyticsLogger: DI for audit/BI/QA.
    /// - Returns: A transition that slides in/out with spring animation.
    static func springSlide(
        edge: Edge = .trailing,
        analyticsLogger: SpringSlideTransitionAnalyticsLogger = NullSpringSlideTransitionAnalyticsLogger()
    ) -> AnyTransition {
        AnyTransition.modifier(
            active: SpringSlideModifier(edge: edge, analyticsLogger: analyticsLogger),
            identity: SpringSlideModifier(edge: edge, analyticsLogger: analyticsLogger)
        )
    }
}

private extension Edge {
    /// Returns the opposite edge (used for exit direction).
    var opposite: Edge {
        switch self {
        case .leading:  return .trailing
        case .trailing: return .leading
        case .top:      return .bottom
        case .bottom:   return .top
        @unknown default: return .trailing
        }
    }
}

#if DEBUG
struct SpringSlideTransition_Previews: PreviewProvider {
    @State static var show = false

    struct SpyLogger: SpringSlideTransitionAnalyticsLogger {
        func log(event: String, edge: Edge) {
            print("[SpringSlideAnalytics] \(event) from \(edge)")
        }
    }

    static var previews: some View {
        VStack(spacing: 24) {
            Button("Toggle Slide") {
                withAnimation {
                    show.toggle()
                }
            }

            Spacer()

            if show {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.accentColor)
                    .frame(height: 120)
                    .overlay(
                        Text("Spring Slide!")
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                    .padding()
                    .transition(.springSlide(edge: .bottom, analyticsLogger: SpyLogger()))
            }

            Spacer()
        }
        .frame(height: 300)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif

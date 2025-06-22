//
//  SpringSlideTransition.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced for readability, reusability, and future customization.
//

import SwiftUI

/// A view modifier applying a directional spring slide transition.
/// Used internally by `.springSlide(edge:)` custom transition.
private struct SpringSlideModifier: ViewModifier {
    let edge: Edge

    private enum Constants {
        static let insertionStiffness: Double = 260
        static let insertionDamping: Double = 26
        static let removalStiffness: Double = 220
        static let removalDamping: Double = 19
    }

    func body(content: Content) -> some View {
        content
            .transition(
                .asymmetric(
                    insertion: .move(edge: edge)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Constants.insertionStiffness,
                            damping: Constants.insertionDamping
                        )),
                    removal: .move(edge: edge.opposite)
                        .combined(with: .opacity)
                        .animation(.interpolatingSpring(
                            stiffness: Constants.removalStiffness,
                            damping: Constants.removalDamping
                        ))
                )
            )
    }
}

extension AnyTransition {
    /// A custom slide transition with a spring effect from a given edge.
    ///
    /// - Parameter edge: The edge from which the view enters.
    /// - Returns: A transition that slides in/out with spring animation.
    static func springSlide(edge: Edge = .trailing) -> AnyTransition {
        AnyTransition.modifier(
            active: SpringSlideModifier(edge: edge),
            identity: SpringSlideModifier(edge: edge)
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
                    .transition(.springSlide(edge: .bottom))
            }

            Spacer()
        }
        .frame(height: 300)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
#endif

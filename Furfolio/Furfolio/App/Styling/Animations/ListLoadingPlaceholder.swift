import SwiftUI

/// A shimmering skeleton placeholder used in lists while data is loading.
struct ListLoadingPlaceholder: View {
    /// Number of placeholder rows to display.
    var rows: Int = 6

    /// Whether to show a leading avatar shape.
    var avatar: Bool = true

    /// Number of text lines per placeholder row.
    var lineCount: Int = 2

    /// Size of the avatar placeholder.
    var avatarSize: CGFloat = 42

    /// Corner radius for each text line placeholder.
    var cornerRadius: CGFloat = 11

    /// Minimum width for the secondary (short) text line.
    private let secondaryWidthMin: CGFloat = 90

    /// Maximum extra width added to the secondary line (randomized).
    private let secondaryWidthVariance: CGFloat = 30

    var body: some View {
        VStack(spacing: 18) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 15) {
                    if avatar {
                        RoundedRectangle(cornerRadius: avatarSize / 2)
                            .fill(Color.gray.opacity(0.18))
                            .frame(width: avatarSize, height: avatarSize)
                            .shimmer()
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(0..<lineCount, id: \.self) { i in
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(Color.gray.opacity(i == 0 ? 0.32 : 0.18))
                                .frame(
                                    width: i == 0
                                        ? 140
                                        : secondaryWidthMin + CGFloat(Int.random(in: 0...Int(secondaryWidthVariance))),
                                    height: i == 0 ? 15 : 11
                                )
                                .shimmer()
                                .accessibilityHidden(true)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

// MARK: - Shimmer Modifier

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.19),
                        Color.white.opacity(0.75),
                        Color.white.opacity(0.19)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(8))
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                withAnimation(Animation.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 220
                }
            }
    }
}

extension View {
    /// Applies shimmer animation for loading state placeholders.
    func shimmer() -> some View {
        self.modifier(Shimmer())
    }
}

// MARK: - Preview

#if DEBUG
struct ListLoadingPlaceholder_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                ListLoadingPlaceholder(rows: 5, avatar: true, lineCount: 2)
                ListLoadingPlaceholder(rows: 3, avatar: false, lineCount: 1)
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
        .background(Color(.systemGroupedBackground))
    }
}
#endif

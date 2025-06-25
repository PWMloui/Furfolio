import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol ListLoadingAnalyticsLogger {
    func log(event: String, rows: Int, avatar: Bool, lineCount: Int)
}
public struct NullListLoadingAnalyticsLogger: ListLoadingAnalyticsLogger {
    public init() {}
    public func log(event: String, rows: Int, avatar: Bool, lineCount: Int) {}
}

/// A shimmering skeleton placeholder used in lists while data is loading.
/// Now: token-compliant, analytics/audit–ready, fully accessible, preview/test-injectable, and business/QA robust.
struct ListLoadingPlaceholder: View {
    /// Number of placeholder rows to display.
    var rows: Int = 6

    /// Whether to show a leading avatar shape.
    var avatar: Bool = true

    /// Number of text lines per placeholder row.
    var lineCount: Int = 2

    /// Analytics logger for business/QA/preview.
    var analyticsLogger: ListLoadingAnalyticsLogger = NullListLoadingAnalyticsLogger()

    /// Design tokens (with robust fallback)
    private enum Tokens {
        static let avatarSize: CGFloat = AppSpacing.avatar ?? 42
        static let cornerRadius: CGFloat = AppRadius.medium ?? 11
        static let spacingRow: CGFloat = AppSpacing.large ?? 18
        static let spacingLine: CGFloat = AppSpacing.small ?? 7
        static let spacingH: CGFloat = AppSpacing.medium ?? 15
        static let spacingV: CGFloat = AppSpacing.small ?? 6
        static let paddingV: CGFloat = AppSpacing.medium ?? 14
        static let shimmerStart: Double = 0
        static let shimmerEnd: Double = 220
        static let shimmerDuration: Double = 1.05
        static let primaryWidth: CGFloat = AppSpacing.skeletonPrimary ?? 140
        static let secondaryWidthMin: CGFloat = AppSpacing.skeletonSecondaryMin ?? 90
        static let secondaryWidthVariance: CGFloat = AppSpacing.skeletonSecondaryVar ?? 30
        static let primaryHeight: CGFloat = AppSpacing.skeletonPrimaryHeight ?? 15
        static let secondaryHeight: CGFloat = AppSpacing.skeletonSecondaryHeight ?? 11
        static let skeletonPrimary: Color = AppColors.skeletonPrimary ?? .gray.opacity(0.32)
        static let skeletonSecondary: Color = AppColors.skeletonSecondary ?? .gray.opacity(0.18)
        static let avatarBg: Color = AppColors.skeletonAvatarBg ?? .gray.opacity(0.18)
        static let bg: Color = AppColors.skeletonBackground ?? Color(.systemGroupedBackground)
        static let accessibilityLoading: String = NSLocalizedString("Loading...", comment: "Accessibility label for list loading placeholder")
    }

    var body: some View {
        VStack(spacing: Tokens.spacingRow) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: Tokens.spacingH) {
                    if avatar {
                        RoundedRectangle(cornerRadius: Tokens.avatarSize / 2)
                            .fill(Tokens.avatarBg)
                            .frame(width: Tokens.avatarSize, height: Tokens.avatarSize)
                            .shimmer()
                            .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: Tokens.spacingLine) {
                        ForEach(0..<lineCount, id: \.self) { i in
                            RoundedRectangle(cornerRadius: Tokens.cornerRadius)
                                .fill(i == 0 ? Tokens.skeletonPrimary : Tokens.skeletonSecondary)
                                .frame(
                                    width: i == 0
                                        ? Tokens.primaryWidth
                                        : Tokens.secondaryWidthMin + CGFloat(Int.random(in: 0...Int(Tokens.secondaryWidthVariance))),
                                    height: i == 0 ? Tokens.primaryHeight : Tokens.secondaryHeight
                                )
                                .shimmer()
                                .accessibilityHidden(true)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, Tokens.spacingV)
            }
        }
        .padding(.vertical, Tokens.paddingV)
        .padding(.horizontal)
        .redacted(reason: .placeholder)
        .background(Tokens.bg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Tokens.accessibilityLoading))
        .accessibilityAddTraits(.isStaticText)
        .onAppear {
            analyticsLogger.log(event: "loading_placeholder_appear", rows: rows, avatar: avatar, lineCount: lineCount)
        }
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
                withAnimation(Animation.linear(duration: ListLoadingPlaceholder.Tokens.shimmerDuration).repeatForever(autoreverses: false)) {
                    phase = ListLoadingPlaceholder.Tokens.shimmerEnd
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
    struct SpyLogger: ListLoadingAnalyticsLogger {
        func log(event: String, rows: Int, avatar: Bool, lineCount: Int) {
            print("ListLoadingAnalytics: \(event) rows:\(rows) avatar:\(avatar) lines:\(lineCount)")
        }
    }
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                ListLoadingPlaceholder(rows: 5, avatar: true, lineCount: 2, analyticsLogger: SpyLogger())
                ListLoadingPlaceholder(rows: 3, avatar: false, lineCount: 1, analyticsLogger: SpyLogger())
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
        .background(ListLoadingPlaceholder.Tokens.bg)
    }
}
#endif

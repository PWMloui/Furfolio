import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ListLoadingAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ListLoadingPlaceholder"
}

/**
 `ListLoadingPlaceholder` is a highly extensible and robust SwiftUI view designed to serve as a shimmering skeleton placeholder in lists while data is loading.  
 
 ### Architecture
 - Modular design with clear separation of concerns.
 - Uses design tokens with fallback for consistent styling.
 - Incorporates a custom shimmer animation via a view modifier.
 
 ### Extensibility
 - Configurable number of rows, avatar display, and line counts.
 - Analytics logging is injectable via a protocol, supporting custom implementations.
 - Designed for easy preview and testing with injectable analytics loggers.
 
 ### Analytics / Audit / Trust Center Hooks
 - Async/await-ready analytics logger protocol for concurrency and future-proofing.
 - Built-in `testMode` flag for console-only logging during QA, tests, and previews.
 - Public API to fetch the last 20 logged audit events for diagnostics or admin UI.
 
 ### Diagnostics
 - Logs key lifecycle events asynchronously with audit context.
 - Stores recent audit events in-memory for inspection.
 
 ### Localization & Compliance
 - All user-facing strings and log event identifiers are localized via `NSLocalizedString` with explicit keys and comments.
 - Accessibility labels and traits fully localized and compliant.
 
 ### Accessibility
 - Accessibility elements are clearly labeled and hidden where appropriate.
 - Uses `.accessibilityElement(children: .ignore)` with descriptive labels for screen readers.
 
 ### Preview / Testability
 - Provides a `NullListLoadingAnalyticsLogger` for silent logging.
 - Includes a preview logger that prints to console in test mode.
 - Supports easy injection of analytics loggers for testing or preview purposes.
 */
 
// MARK: - Analytics/Audit Logger Protocol

/// Protocol defining an async analytics logger for the `ListLoadingPlaceholder` with audit context.
public protocol ListLoadingAnalyticsLogger {
    /// Indicates whether the logger is in test mode, where logging is console-only.
    var testMode: Bool { get }

    /**
     Logs an analytics event asynchronously with details about the loading placeholder state and audit context.
     
     - Parameters:
       - event: The event identifier string.
       - rows: Number of placeholder rows displayed.
       - avatar: Whether avatar placeholders are shown.
       - lineCount: Number of text lines per row.
       - role: Optional user role from audit context.
       - staffID: Optional staff identifier from audit context.
       - context: Optional context string from audit context.
       - escalate: Flag indicating if event should be escalated for audit purposes.
     */
    func log(event: String, rows: Int, avatar: Bool, lineCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async

    /// Public API to fetch the last 20 audit events for diagnostics or admin UI.
    func fetchRecentEvents() -> [ListLoadingAuditEvent]
}

/// Represents a logged audit event with full context for diagnostics and compliance.
public struct ListLoadingAuditEvent: Identifiable {
    public let id = UUID()
    public let event: String
    public let rows: Int
    public let avatar: Bool
    public let lineCount: Int
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let timestamp: Date
}

/// A no-op analytics logger that performs no logging.
public struct NullListLoadingAnalyticsLogger: ListLoadingAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, rows: Int, avatar: Bool, lineCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents() -> [ListLoadingAuditEvent] { [] }
}

/// A simple analytics logger for QA/tests/previews that logs to console when in test mode, with audit context.
public class ConsoleListLoadingAnalyticsLogger: ListLoadingAnalyticsLogger {
    public let testMode: Bool
    private(set) var recentEvents: [ListLoadingAuditEvent] = []
    private let maxStoredEvents = 20
    
    public init(testMode: Bool = true) {
        self.testMode = testMode
    }
    
    /**
     Logs an analytics event asynchronously with audit context.
     Stores the event internally and optionally prints to console if in test mode.
     */
    public func log(event: String, rows: Int, avatar: Bool, lineCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let newEvent = ListLoadingAuditEvent(event: event, rows: rows, avatar: avatar, lineCount: lineCount, role: role, staffID: staffID, context: context, escalate: escalate, timestamp: Date())
        DispatchQueue.main.async {
            self.recentEvents.append(newEvent)
            if self.recentEvents.count > self.maxStoredEvents {
                self.recentEvents.removeFirst(self.recentEvents.count - self.maxStoredEvents)
            }
            if self.testMode {
                let localizedEvent = NSLocalizedString(event, comment: "Analytics event identifier")
                print("ListLoadingAnalytics: \(localizedEvent) rows:\(rows) avatar:\(avatar) lines:\(lineCount) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
            }
        }
    }
    
    /// Public API to fetch the last 20 audit events for diagnostics or admin UI.
    public func fetchRecentEvents() -> [ListLoadingAuditEvent] {
        return recentEvents
    }
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
        static let eventAppear: String = NSLocalizedString("loading_placeholder_appear", comment: "Analytics event for list loading placeholder appearance")
    }

    /// The body view displaying the loading placeholder rows.
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
        .task {
            let escalateFlag = rows > 10 || (!avatar && lineCount > 2)
            await analyticsLogger.log(event: Tokens.eventAppear, rows: rows, avatar: avatar, lineCount: lineCount, role: ListLoadingAuditContext.role, staffID: ListLoadingAuditContext.staffID, context: ListLoadingAuditContext.context, escalate: escalateFlag)
        }
    }
}

// MARK: - Shimmer Modifier

/// A view modifier that applies a shimmering animation to indicate loading state.
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
    /// A spy logger that prints audit events to console for previews with full audit context.
    struct SpyLogger: ListLoadingAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, rows: Int, avatar: Bool, lineCount: Int, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            let localizedEvent = NSLocalizedString(event, comment: "Analytics event identifier")
            print("ListLoadingAnalytics: \(localizedEvent) rows:\(rows) avatar:\(avatar) lines:\(lineCount) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
        func fetchRecentEvents() -> [ListLoadingAuditEvent] { [] }
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

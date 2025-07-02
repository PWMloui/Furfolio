//
//  OnboardingWelcomeView.swift
//  Furfolio
//
//  Enhanced for accessibility, localization, analytics/audit logging, and testability.
//

/**
 OnboardingWelcomeView
 ---------------------
 The first screen in the Furfolio onboarding flow, introducing the app to users.

 - **Architecture**: SwiftUI `View` with dependency-injected `AnalyticsServiceProtocol` and `AuditLoggerProtocol`.
 - **Concurrency & Async Logging**: All analytics and audit calls are wrapped in `Task` for non-blocking execution.
 - **Audit Management**: Uses `OnboardingWelcomeAuditManager` actor to record user interactions.
 - **Localization**: UI text and accessibility labels use `LocalizedStringKey` for internationalization.
 - **Accessibility**: Elements include accessibility labels, hints, and traits for VoiceOver.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries; preview injects mock async loggers.
 */

import SwiftUI

// MARK: - Centralized Analytics + Audit Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit message asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

/// A record of interactions on the welcome screen.
public struct OnboardingWelcomeAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

/// Actor for concurrency-safe audit logging on the welcome view.
public actor OnboardingWelcomeAuditManager {
    private var buffer: [OnboardingWelcomeAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingWelcomeAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: OnboardingWelcomeAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingWelcomeAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - OnboardingWelcomeView

/// The first onboarding screen introducing the Furfolio app.
struct OnboardingWelcomeView: View {
    /// Callback triggered when the user taps the primary continue button.
    var onContinue: (() -> Void)? = nil

    /// Injected logging services
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens
    let accentColor: Color
    let textSecondary: Color
    let background: Color
    let secondaryBackground: Color
    let titleFont: Font
    let bodyFont: Font
    let spacingLarge: CGFloat
    let spacingMedium: CGFloat
    let spacingMediumLarge: CGFloat
    let spacingExtraLarge: CGFloat
    let imageHeight: CGFloat

    init(
        onContinue: (() -> Void)? = nil,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accentColor: Color = AppColors.accent ?? .accentColor,
        textSecondary: Color = AppColors.textSecondary ?? .secondary,
        background: Color = AppColors.background ?? Color(.systemBackground),
        secondaryBackground: Color = AppColors.secondaryBackground ?? Color(.secondarySystemBackground),
        titleFont: Font = AppFonts.title.bold() ?? .title.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        spacingLarge: CGFloat = AppSpacing.large ?? 36,
        spacingMedium: CGFloat = AppSpacing.medium ?? 20,
        spacingMediumLarge: CGFloat = AppSpacing.mediumLarge ?? 24,
        spacingExtraLarge: CGFloat = AppSpacing.extraLarge ?? 32,
        imageHeight: CGFloat = 100
    ) {
        self.onContinue = onContinue
        self.analytics = analytics
        self.audit = audit
        self.accentColor = accentColor
        self.textSecondary = textSecondary
        self.background = background
        self.secondaryBackground = secondaryBackground
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.spacingLarge = spacingLarge
        self.spacingMedium = spacingMedium
        self.spacingMediumLarge = spacingMediumLarge
        self.spacingExtraLarge = spacingExtraLarge
        self.imageHeight = imageHeight
    }

    var body: some View {
        VStack(spacing: spacingLarge) {
            Spacer(minLength: spacingMedium)

            Image(systemName: "pawprint.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)
                .foregroundColor(accentColor)
                .padding(.top, spacingMedium)
                .accessibilityLabel(Text("Furfolio app icon"))

            Text(LocalizedStringKey("Welcome to Furfolio!"))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel(LocalizedStringKey("Welcome to Furfolio"))
                .accessibilityHint(LocalizedStringKey("Introduction to the Furfolio app"))

            Text(LocalizedStringKey("The modern business toolkit for dog grooming professionals.\n\nEasily manage appointments, clients, pets, and business growth—all in one place."))
                .font(bodyFont)
                .multilineTextAlignment(.center)
                .foregroundColor(textSecondary)
                .padding(.horizontal, spacingMediumLarge)

            Spacer()

            Button(action: {
                Task {
                    await analytics.log(event: "onboarding_welcome_continue", parameters: nil)
                    await audit.record("User continued from welcome screen", metadata: nil)
                    await OnboardingWelcomeAuditManager.shared.add(
                        OnboardingWelcomeAuditEntry(event: "welcome_continue")
                    )
                    onContinue?()
                }
            }) {
                Text(LocalizedStringKey("Get Started"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, spacingMediumLarge)
            .padding(.bottom, spacingExtraLarge)
            .accessibilityLabel(LocalizedStringKey("Continue to next step"))
            .accessibilityHint(LocalizedStringKey("Navigates to the next step in onboarding"))
        }
        .padding()
        .background(gradientBackground)
        .accessibilityElement(children: .contain)
        .onAppear {
            Task {
                await analytics.screenView("OnboardingWelcome")
                await audit.record("User landed on onboarding welcome screen", metadata: nil)
                await OnboardingWelcomeAuditManager.shared.add(
                    OnboardingWelcomeAuditEntry(event: "welcome_appear")
                )
            }
        }
    }

    private var gradientBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [background, secondaryBackground]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) async {
            print("[Analytics] \(event) \(parameters ?? [:])")
        }
        func screenView(_ name: String) async {
            print("[Analytics] screenView: \(name)")
        }
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) async {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }

    return Group {
        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .previewDisplayName("Light Mode")

        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingWelcomeView(
            onContinue: { print("Next step triggered") },
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Large Font")
    }
}

// MARK: - Diagnostics

public extension OnboardingWelcomeView {
    /// Fetches recent welcome view audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingWelcomeAuditEntry] {
        await OnboardingWelcomeAuditManager.shared.recent(limit: limit)
    }

    /// Export welcome view audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await OnboardingWelcomeAuditManager.shared.exportJSON()
    }
}

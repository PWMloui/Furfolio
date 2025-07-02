//
//  OnboardingSlideView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, preview/testable, and accessible.
//

/**
 OnboardingSlideView
 -------------------
 A SwiftUI view displaying a single slide in the onboarding flow of Furfolio.

 - **Purpose**: Presents an icon, title, and description for each onboarding step.
 - **Architecture**: Modular, MVVM-capable, with dependency-injected analytics and audit loggers.
 - **Concurrency & Async Logging**: Uses async/await wrapped in `Task` for non-blocking event recording.
 - **Audit/Analytics Ready**: Defines async protocols and integrates a centralized audit manager.
 - **Localization**: Titles and descriptions use `LocalizedStringKey` for i18n.
 - **Accessibility**: Images and text include accessibility labels, hints, and traits.
 - **Diagnostics**: Exposes async methods to fetch and export recent audit entries.
 - **Preview/Testability**: Includes multiple SwiftUI previews with mock async loggers.
 */

import SwiftUI

// MARK: - Centralized Analytics + Audit Logger Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

/// A record of an onboarding slide view event.
public struct OnboardingSlideAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let slideTitle: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), slideTitle: String) {
        self.id = id
        self.timestamp = timestamp
        self.slideTitle = slideTitle
    }
}

/// Manages concurrency-safe audit logging for onboarding slide views.
public actor OnboardingSlideAuditManager {
    private var buffer: [OnboardingSlideAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingSlideAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: OnboardingSlideAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingSlideAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export the audit log as a JSON string.
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

// MARK: - OnboardingSlideView

struct OnboardingSlideView: View {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    // Logging
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens
    let accent: Color
    let textSecondary: Color
    let spacingL: CGFloat
    let imageHeight: CGFloat
    let titleFont: Font
    let descFont: Font

    // MARK: - DI initializer for prod, preview, or test
    init(
        imageName: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accent: Color = AppColors.accent ?? .accentColor,
        textSecondary: Color = AppColors.textSecondary ?? .secondary,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        imageHeight: CGFloat = 100,
        titleFont: Font = AppFonts.title2Bold ?? .title2.bold(),
        descFont: Font = AppFonts.body ?? .body
    ) {
        self.imageName = imageName
        self.title = title
        self.description = description
        self.analytics = analytics
        self.audit = audit
        self.accent = accent
        self.textSecondary = textSecondary
        self.spacingL = spacingL
        self.imageHeight = imageHeight
        self.titleFont = titleFont
        self.descFont = descFont
    }

    var body: some View {
        VStack(spacing: spacingL) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(height: imageHeight)
                .foregroundColor(accent)
                .padding(.top, spacingL)
                .accessibilityLabel(title)
                .accessibilityHint(description)

            Text(title)
                .font(titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Text(description)
                .font(descFont)
                .foregroundColor(textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(.horizontal, spacingL)
        .accessibilityElement(children: .contain)
        .onAppear {
            Task {
                let titleString = String(localized: title)
                await analytics.log(event: "onboarding_slide_viewed", parameters: ["slide_title": titleString])
                await audit.record("Viewed onboarding slide titled '\(titleString)'", metadata: nil)
                await OnboardingSlideAuditManager.shared.add(
                    OnboardingSlideAuditEntry(slideTitle: titleString)
                )
            }
        }
    }
}

public extension OnboardingSlideView {
    /// Fetches recent onboarding slide audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingSlideAuditEntry] {
        await OnboardingSlideAuditManager.shared.recent(limit: limit)
    }

    /// Exports the onboarding slide audit log as a JSON string.
    static func exportAuditLogJSON() async -> String {
        await OnboardingSlideAuditManager.shared.exportJSON()
    }
}

// MARK: - Preview

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) async {
            print("[Analytics] \(event): \(parameters ?? [:])")
        }
        func screenView(_ name: String) async {}
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) async {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }

    let title: LocalizedStringKey = "Welcome to Furfolio!"
    let desc: LocalizedStringKey = "Easily manage your dog grooming business, schedule appointments, and track all client info in one secure place."

    return Group {
        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .previewDisplayName("Light Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingSlideView(
            imageName: "pawprint.fill",
            title: title,
            description: desc,
            analytics: MockAnalytics(),
            audit: MockAudit()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")
    }
}

//
//  OnboardingProgressIndicator.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, testable, business/enterprise-ready.
//

/**
 OnboardingProgressIndicator
 ----------------------------
 A SwiftUI view that visually represents and tracks a user’s progress through onboarding steps.

 - **Architecture**: SwiftUI `View` with customizable styling tokens and MVVM-compatible `onProgressChange` callback.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in async `Task` for non-blocking execution.
 - **Audit/Analytics Ready**: Defines async protocols and integrates a centralized audit manager for diagnostics.
 - **Localization**: Accessibility labels and hints are localized.
 - **Accessibility**: Provides detailed VoiceOver labels, values, and traits per step.
 - **Diagnostics**: Exposes async methods to retrieve and export recent audit entries.
 - **Preview/Testability**: Includes multiple SwiftUI preview configurations with mock async loggers.
 */

import SwiftUI

// MARK: - Centralized Analytics + Audit Logging

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

/// A record of a progress indicator audit event.
public struct ProgressIndicatorAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let step: Int
    public let totalSteps: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), step: Int, totalSteps: Int) {
        self.id = id
        self.timestamp = timestamp
        self.step = step
        self.totalSteps = totalSteps
    }
}

/// Manages concurrency-safe audit logging for progress indicator events.
public actor ProgressIndicatorAuditManager {
    private var buffer: [ProgressIndicatorAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ProgressIndicatorAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: ProgressIndicatorAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ProgressIndicatorAuditEntry] {
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

// MARK: - OnboardingProgressIndicator View

struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    var onProgressChange: ((Int) -> Void)? = nil
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens (with safe fallback)
    let accent: Color
    let inactive: Color
    let spacing: CGFloat
    let widthActive: CGFloat
    let widthInactive: CGFloat
    let capsuleHeight: CGFloat
    let paddingY: CGFloat

    // MARK: - Dependency Injection
    init(
        currentStep: Int,
        totalSteps: Int,
        onProgressChange: ((Int) -> Void)? = nil,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accent: Color = AppColors.accent ?? .accentColor,
        inactive: Color = AppColors.inactive ?? .gray.opacity(0.3),
        spacing: CGFloat = AppSpacing.medium ?? 8,
        widthActive: CGFloat = 28,
        widthInactive: CGFloat = 10,
        capsuleHeight: CGFloat = 10,
        paddingY: CGFloat = AppSpacing.medium ?? 8
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onProgressChange = onProgressChange
        self.analytics = analytics
        self.audit = audit
        self.accent = accent
        self.inactive = inactive
        self.spacing = spacing
        self.widthActive = widthActive
        self.widthInactive = widthInactive
        self.capsuleHeight = capsuleHeight
        self.paddingY = paddingY
    }

    // Defensive clamping for safe rendering
    private var safeCurrentStep: Int {
        guard totalSteps > 0 else { return 0 }
        return min(max(currentStep, 0), totalSteps - 1)
    }

    var body: some View {
        if totalSteps <= 0 {
            EmptyView()
        } else {
            HStack(spacing: spacing) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx == safeCurrentStep ? accent : inactive)
                        .frame(width: idx == safeCurrentStep ? widthActive : widthInactive, height: capsuleHeight)
                        .accessibilityElement()
                        .accessibilityLabel(Text("Step \(idx + 1) of \(totalSteps)"))
                        .accessibilityValue(
                            idx == safeCurrentStep
                            ? Text("Current step")
                            : Text("Not current step")
                        )
                        .accessibilityAddTraits(idx == safeCurrentStep ? .isSelected : [])
                }
            }
            .padding(.vertical, paddingY)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: safeCurrentStep)
            .accessibilityElement(children: .contain)
            .accessibilityHint(Text("Indicates your progress through the onboarding steps."))
            .onChange(of: safeCurrentStep) { newValue in
                onProgressChange?(newValue)
                Task {
                    await analytics.log(event: "onboarding_progress_changed", parameters: [
                        "step": newValue,
                        "total": totalSteps
                    ])
                    await audit.record("Progress indicator moved to step \(newValue + 1) of \(totalSteps)", metadata: nil)
                    await ProgressIndicatorAuditManager.shared.add(
                        ProgressIndicatorAuditEntry(step: newValue, totalSteps: totalSteps)
                    )
                }
            }
        }
    }
}

public extension OnboardingProgressIndicator {
    /// Fetches recent audit entries for diagnostics.
    func recentAuditEntries(limit: Int = 20) async -> [ProgressIndicatorAuditEntry] {
        await ProgressIndicatorAuditManager.shared.recent(limit: limit)
    }

    /// Export the audit log as a JSON string.
    func exportAuditLogJSON() async -> String {
        await ProgressIndicatorAuditManager.shared.exportJSON()
    }
}

// MARK: - Previews

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String: Any]?) async {
            print("[Analytics] \(event): \(parameters ?? [:])")
        }
        func screenView(_ name: String) async {}
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String: String]?) async {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }

    return Group {
        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Light Mode")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 0,
                totalSteps: 0,
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("No steps to display (totalSteps = 0).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Zero Steps")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 10,
                totalSteps: 5,
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("currentStep out of bounds (clamped to valid range).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Current Step Out of Bounds")
    }
}

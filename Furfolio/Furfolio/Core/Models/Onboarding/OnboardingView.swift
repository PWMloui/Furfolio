//
//  OnboardingView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit–ready, modular, token-compliant, accessible, and preview/testable.
//

/**
 OnboardingView
 --------------
 A SwiftUI view orchestrating the multi-step onboarding flow in Furfolio.

 - **Architecture**: MVVM-compatible, using `OnboardingFlowManager` for state and navigation.
 - **Dependency Injection**: Injects `AnalyticsServiceProtocol` and `AuditLoggerProtocol` for event tracking.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in async `Task` to avoid blocking the UI.
 - **Audit Management**: Uses `OnboardingViewAuditManager` actor to record all user interactions with a capped diagnostic buffer.
 - **Localization**: All user-facing strings should be localized via `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Provides accessibility labels, hints, and traits for dynamic content.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries for testing and diagnostics.
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

/// A record of OnboardingView user interaction.
public struct OnboardingViewAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let step: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, step: Int) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.step = step
    }
}

/// Concurrency-safe actor for auditing OnboardingView events.
public actor OnboardingViewAuditManager {
    private var buffer: [OnboardingViewAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingViewAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: OnboardingViewAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingViewAuditEntry] {
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

// MARK: - OnboardingView

struct OnboardingView: View {
    // MARK: - Injectables
    @StateObject private var flowManager: OnboardingFlowManager
    private let analytics: AnalyticsServiceProtocol
    private let audit: AuditLoggerProtocol

    // MARK: - Tokens
    private let spacingM: CGFloat
    private let spacingL: CGFloat
    private let spacingXL: CGFloat
    private let fontBody: Font
    private let colorBackground: Color
    private let colorSecondaryBackground: Color

    // MARK: - Initializer
    init(
        flowManager: @autoclosure @escaping () -> OnboardingFlowManager = OnboardingFlowManager(),
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        spacingM: CGFloat = AppSpacing.medium ?? 20,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        spacingXL: CGFloat = AppSpacing.extraLarge ?? 28,
        fontBody: Font = AppFonts.body ?? .body,
        colorBackground: Color = AppColors.background ?? Color(.systemBackground),
        colorSecondaryBackground: Color = AppColors.secondaryBackground ?? Color(.secondarySystemBackground)
    ) {
        _flowManager = StateObject(wrappedValue: flowManager())
        self.analytics = analytics
        self.audit = audit
        self.spacingM = spacingM
        self.spacingL = spacingL
        self.spacingXL = spacingXL
        self.fontBody = fontBody
        self.colorBackground = colorBackground
        self.colorSecondaryBackground = colorSecondaryBackground
    }

    var body: some View {
        VStack(spacing: spacingM) {
            // Progress Indicator
            OnboardingProgressIndicator(
                currentStep: flowManager.currentStep.rawValue,
                totalSteps: OnboardingStep.allCases.count,
                analytics: analytics,
                audit: audit
            )
            .accessibilityLabel(Text("Onboarding progress: step \(flowManager.currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)"))
            .accessibilityHint(Text(flowManager.currentStep.description))
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: spacingM)

            // Main Content
            Group {
                switch flowManager.currentStep {
                case .welcome:
                    OnboardingSlideView(
                        imageName: "pawprint.fill",
                        title: "Welcome to Furfolio!",
                        description: "All-in-one business management for dog groomers. Organize your appointments, clients, and business insights, all in one secure app.",
                        analytics: analytics,
                        audit: audit
                    )
                case .dataImport:
                    OnboardingDataImportView(analytics: analytics, audit: audit)
                case .tutorial:
                    InteractiveTutorialView(analytics: analytics, audit: audit)
                case .faq:
                    OnboardingFAQView(analytics: analytics, audit: audit)
                case .permissions:
                    OnboardingPermissionView(
                        onContinue: {
                            Task {
                                let step = flowManager.currentStep.rawValue
                                await analytics.log(event: "onboarding_permission_continue", parameters: ["step": step])
                                await audit.record("Permission continue tapped", metadata: ["step": "\(step)"])
                                await OnboardingViewAuditManager.shared.add(
                                    OnboardingViewAuditEntry(event: "permission_continue", step: step)
                                )
                                flowManager.goToNextStep()
                            }
                        },
                        analytics: analytics,
                        audit: audit
                    )
                case .completion:
                    OnboardingCompletionView {
                        Task {
                            let step = flowManager.currentStep.rawValue
                            await analytics.log(event: "onboarding_complete", parameters: ["step": step])
                            await audit.record("Onboarding complete tapped", metadata: ["step": "\(step)"])
                            await OnboardingViewAuditManager.shared.add(
                                OnboardingViewAuditEntry(event: "onboarding_complete", step: step)
                            )
                            flowManager.skipOnboarding()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: flowManager.currentStep)

            Spacer(minLength: spacingL)

            // Navigation
            if flowManager.currentStep != .completion {
                HStack {
                    if flowManager.currentStep != .welcome {
                        Button {
                            Task {
                                let step = flowManager.currentStep.rawValue
                                await analytics.log(event: "onboarding_back", parameters: ["step": step])
                                await audit.record("Back tapped", metadata: ["step": "\(step)"])
                                await OnboardingViewAuditManager.shared.add(
                                    OnboardingViewAuditEntry(event: "back_tap", step: step)
                                )
                                flowManager.goToPreviousStep()
                            }
                        } label: {
                            Text("Back").font(fontBody)
                        }
                        .padding(.horizontal, spacingL)
                        .accessibilityLabel(Text("Go back to previous step"))
                    }

                    Spacer()

                    Button {
                        Task {
                            let step = flowManager.currentStep.rawValue
                            await analytics.log(event: "onboarding_next", parameters: ["step": step])
                            await audit.record("Next tapped", metadata: ["step": "\(step)"])
                            await OnboardingViewAuditManager.shared.add(
                                OnboardingViewAuditEntry(event: "next_tap", step: step)
                            )
                            flowManager.goToNextStep()
                        }
                    } label: {
                        Text(flowManager.currentStep == .permissions ? "Finish" : "Next")
                            .font(fontBody)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, spacingL)
                    .accessibilityLabel(Text(flowManager.currentStep == .permissions ? "Finish onboarding" : "Go to next onboarding step"))
                }
                .padding(.bottom, spacingXL)
                .transition(.opacity)
                .animation(.easeInOut, value: flowManager.currentStep)
            }
        }
        .onAppear {
            flowManager.loadOnboardingState()
            Task {
                let step = flowManager.currentStep.rawValue
                await analytics.screenView("onboarding_appear")
                await analytics.log(event: "onboarding_appear", parameters: ["step": step])
                await audit.record("OnboardingView appeared", metadata: ["step": "\(step)"])
                await OnboardingViewAuditManager.shared.add(
                    OnboardingViewAuditEntry(event: "view_appear", step: step)
                )
            }
        }
        .fullScreenCover(isPresented: .constant(flowManager.isOnboardingComplete)) {
            // TODO: Handle onboarding completion
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [colorBackground, colorSecondaryBackground]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String: Any]?) async {
            print("[Analytics] \(event) \(parameters ?? [:])")
        }
        func screenView(_ name: String) async {}
    }

    struct PreviewAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) async {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }

    return Group {
        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .preferredColorScheme(.light)
        .previewDisplayName("Light Mode")

        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Large Text")
    }
}

// MARK: - Diagnostics

public extension OnboardingView {
    /// Fetch recent onboarding view audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingViewAuditEntry] {
        await OnboardingViewAuditManager.shared.recent(limit: limit)
    }

    /// Export onboarding view audit log as a JSON string.
    static func exportAuditLogJSON() async -> String {
        await OnboardingViewAuditManager.shared.exportJSON()
    }
}

//
//  CelebrationManager.swift
//  Furfolio
//
//  Enhanced for 2025+ Grooming Business App Architecture
//
// MARK: - CelebrationManager (Unified, Modular, Tokenized, Accessible Business Celebrations)

import Foundation
import SwiftUI
import AVFoundation
import SwiftData

/// Furfolio: Unified celebration/event overlay manager for all major business, staff, and pet milestones.
/// All overlays, icons, colors, and sounds use modular tokens (AppColors, AppFonts, AppSpacing, etc) and are fully accessible.
/// Audit logging, analytics, and business compliance hooks are included for every celebration to ensure traceability and privacy compliance.
@MainActor
final class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()

    @Published var isCelebrating: Bool = false
    @Published var celebrationType: CelebrationType? = nil

    private var audioPlayer: AVAudioPlayer?

    // Dependency injection possible for analytics, audit, etc.
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) private var auditLog: [CelebrationAuditEvent]

    // MARK: - Celebration Audit Log & Analytics

    /// Audit event for a celebration, including metadata and accessibility label.
    @Model public struct CelebrationAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var timestamp: Date
        var type: CelebrationType
        var tagTokens: [String]
        var overlayShown: Bool
        var soundPlayed: Bool
        var hapticTriggered: Bool
        var actor: String?          // User, staff, or system (for future)
        var context: String?        // e.g., "manual", "auto", "marketing", "reward"
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return String(
                format: NSLocalizedString(
                    "%@ celebration at %@. Overlay: %@, sound: %@, haptic: %@.",
                    comment: "Accessibility label for celebration audit event"
                ),
                type.displayName,
                dateStr,
                overlayShown ? NSLocalizedString("on", comment: "Overlay shown") : NSLocalizedString("off", comment: "Overlay not shown"),
                soundPlayed ? NSLocalizedString("yes", comment: "Sound played") : NSLocalizedString("no", comment: "Sound not played"),
                hapticTriggered ? NSLocalizedString("yes", comment: "Haptic triggered") : NSLocalizedString("no", comment: "Haptic not triggered")
            )
        }
    }

    /// Exports the last audit event as a pretty-printed JSON string asynchronously.
    /// - Returns: JSON string of the last audit event, or nil if none exists.
    static func exportLastAuditEventJSON(context: ModelContext) async -> String? {
        let entries = try? await context.fetch(CelebrationAuditEvent.self)
        guard let last = entries?.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Logs a celebration event to the audit log asynchronously in a concurrency-safe manner.
    /// - Parameters:
    ///   - type: Celebration type.
    ///   - overlay: Whether overlay was shown.
    ///   - sound: Whether sound was played.
    ///   - haptic: Whether haptic feedback was triggered.
    ///   - actor: Optional actor string (user, system, etc).
    ///   - context: Optional context string (reason for celebration).
    func logCelebration(
        type: CelebrationType,
        overlay: Bool,
        sound: Bool,
        haptic: Bool,
        actor: String? = nil,
        context: String? = nil
    ) async {
        let event = CelebrationAuditEvent(
            timestamp: Date(),
            type: type,
            tagTokens: type.tags,
            overlayShown: overlay,
            soundPlayed: sound,
            hapticTriggered: haptic,
            actor: actor,
            context: context
        )
        modelContext.insert(event)
    }

    /// Clears all audit logs asynchronously.
    public func clearAuditLog() async {
        let entries = try? await modelContext.fetch(CelebrationAuditEvent.self)
        entries?.forEach { modelContext.delete($0) }
    }

    /// Human-readable summary of last celebration for accessibility/dashboard.
    /// - Returns: Accessibility label string or default message if no celebrations recorded.
    var accessibilityCelebrationLabel: String {
        get async {
            let entries = try? await modelContext.fetch(CelebrationAuditEvent.self)
            if let last = entries?.last {
                return last.accessibilityLabel
            } else {
                return NSLocalizedString("No celebrations recorded.", comment: "")
            }
        }
    }

    /// Call to trigger a celebration overlay, sound, and haptics asynchronously.
    /// - Parameters:
    ///   - type: The type of celebration to trigger.
    ///   - actor: Optionally supply user or reason for audit.
    ///   - context: Optionally supply context/reason for audit.
    /// - Note: This method awaits the auto-dismiss delay before returning.
    @MainActor
    func celebrate(_ type: CelebrationType, actor: String? = nil, context: String? = nil) async {
        celebrationType = type
        isCelebrating = true
        var soundPlayed = false
        var hapticTriggered = false

        if playSound(for: type) { soundPlayed = true }
        if triggerHaptic(for: type) { hapticTriggered = true }

        // Unified audit/event logging for compliance and analytics.
        await logCelebration(type: type, overlay: true, sound: soundPlayed, haptic: hapticTriggered, actor: actor, context: context)

        // Business audit trail, analytics, or notification can be plugged here.

        // Auto-dismiss after 2.5s (tunable)
        try? await Task.sleep(nanoseconds: 2_500_000_000)
        self.isCelebrating = false
        self.celebrationType = nil
    }

    @discardableResult
    private func playSound(for type: CelebrationType) -> Bool {
        guard let url = Bundle.main.url(forResource: type.soundName, withExtension: "mp3") else { return false }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return true
        } catch {
            let errorMessage = NSLocalizedString("Sound playback error: \(error.localizedDescription)", comment: "Error message for sound playback failure")
            print("[CelebrationManager] \(errorMessage)")
            return false
        }
    }

    @discardableResult
    private func triggerHaptic(for type: CelebrationType) -> Bool {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type.hapticFeedbackType)
        return true
        #else
        return false
        #endif
    }
}

/// Types of celebrations tracked in Furfolio. Extend as new business cases arise.
/// All new celebration types must be documented, tokenized, and have clear business rationale.
/// Icons and colors must use design system tokens to ensure consistency and accessibility.
enum CelebrationType: String, CaseIterable, Identifiable, Codable {
    case loyaltyReward, businessMilestone, petBirthday, bigSale, onboardingComplete, staffAnniversary, retentionGoal, custom

    var id: String { rawValue }

    /// Localized display name for the celebration type.
    var displayName: String {
        switch self {
        case .loyaltyReward:
            return NSLocalizedString("Loyalty Reward", comment: "Display name for loyalty reward celebration")
        case .businessMilestone:
            return NSLocalizedString("Business Milestone", comment: "Display name for business milestone celebration")
        case .petBirthday:
            return NSLocalizedString("Pet Birthday", comment: "Display name for pet birthday celebration")
        case .bigSale:
            return NSLocalizedString("Big Sale", comment: "Display name for big sale celebration")
        case .onboardingComplete:
            return NSLocalizedString("Onboarding Complete", comment: "Display name for onboarding complete celebration")
        case .staffAnniversary:
            return NSLocalizedString("Staff Anniversary", comment: "Display name for staff anniversary celebration")
        case .retentionGoal:
            return NSLocalizedString("Retention Goal", comment: "Display name for retention goal celebration")
        case .custom:
            return NSLocalizedString("Special Celebration", comment: "Display name for custom celebration")
        }
    }

    /// Sound file name, no extension.
    var soundName: String {
        switch self {
        case .loyaltyReward: return "confetti"
        case .businessMilestone: return "tada"
        case .petBirthday: return "party"
        case .bigSale: return "cash"
        case .onboardingComplete: return "achievement"
        case .staffAnniversary: return "cheer"
        case .retentionGoal: return "goal"
        case .custom: return "celebrate"
        }
    }

    #if os(iOS)
    var hapticFeedbackType: UINotificationFeedbackGenerator.FeedbackType {
        .success // All set to success for now; adjust as needed
    }
    #endif

    /// Emoji or SF Symbol (cross-platform)
    var icon: String {
        switch self {
        case .loyaltyReward: return "🏆"
        case .businessMilestone: return "🎉"
        case .petBirthday: return "🎂"
        case .bigSale: return "💸"
        case .onboardingComplete: return "🚀"
        case .staffAnniversary: return "👑"
        case .retentionGoal: return "📈"
        case .custom: return "🥳"
        }
    }

    /// Tokenized and localized tags for analytics, dashboards, and compliance.
    var tags: [String] {
        switch self {
        case .loyaltyReward:
            return [NSLocalizedString("loyalty", comment: "Tag for loyalty"), NSLocalizedString("reward", comment: "Tag for reward"), NSLocalizedString("client", comment: "Tag for client")]
        case .businessMilestone:
            return [NSLocalizedString("business", comment: "Tag for business"), NSLocalizedString("milestone", comment: "Tag for milestone"), NSLocalizedString("growth", comment: "Tag for growth")]
        case .petBirthday:
            return [NSLocalizedString("pet", comment: "Tag for pet"), NSLocalizedString("birthday", comment: "Tag for birthday"), NSLocalizedString("fun", comment: "Tag for fun")]
        case .bigSale:
            return [NSLocalizedString("sale", comment: "Tag for sale"), NSLocalizedString("revenue", comment: "Tag for revenue"), NSLocalizedString("finance", comment: "Tag for finance")]
        case .onboardingComplete:
            return [NSLocalizedString("onboarding", comment: "Tag for onboarding"), NSLocalizedString("client", comment: "Tag for client"), NSLocalizedString("activation", comment: "Tag for activation")]
        case .staffAnniversary:
            return [NSLocalizedString("staff", comment: "Tag for staff"), NSLocalizedString("anniversary", comment: "Tag for anniversary"), NSLocalizedString("team", comment: "Tag for team")]
        case .retentionGoal:
            return [NSLocalizedString("retention", comment: "Tag for retention"), NSLocalizedString("goal", comment: "Tag for goal"), NSLocalizedString("kpi", comment: "Tag for KPI")]
        case .custom:
            return [NSLocalizedString("custom", comment: "Tag for custom"), NSLocalizedString("special", comment: "Tag for special")]
        }
    }
}

/// Overlay View for instant drop-in celebration UI.
/// For "pro" confetti, integrate with a package or a custom particle system.
/// No system or hardcoded styling is allowed; all color, font, spacing, and corner radius must use design tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows).
struct ConfettiOverlay: View {
    @Binding var isVisible: Bool
    var type: CelebrationType

    @State private var confettiPositions: [CGPoint] = []
    @State private var opacityValues: [Double] = []

    private let confettiCount = 36

    var body: some View {
        if isVisible {
            ZStack {
                ForEach(0..<confettiCount, id: \.self) { index in
                    Text(type.icon)
                        .font(AppFonts.confettiIcon)
                        .position(confettiPositions.indices.contains(index) ? confettiPositions[index] : randomPosition())
                        .opacity(opacityValues.indices.contains(index) ? opacityValues[index] : 1.0)
                        .accessibilityHidden(true)
                        .accessibilityAddTraits(.isDecorative)
                        .task(id: isVisible) {
                            await animateConfetti(index: index)
                        }
                }
                VStack {
                    Spacer()
                    Text(type.displayName)
                        .font(AppFonts.largeTitleHeavy)
                        .padding(AppSpacing.large)
                        .background(AppColors.ultraThinMaterial)
                        .cornerRadius(BorderRadius.extraLarge)
                        .padding(.bottom, AppSpacing.xxl)
                        .accessibilityLabel(Text(String(format: NSLocalizedString("%@ celebration", comment: "Accessibility label for celebration overlay"), type.displayName)))
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .transition(.opacity.combined(with: .scale))
            .zIndex(10)
        }
    }

    private func randomPosition() -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 20...UIScreen.main.bounds.width - 20),
            y: CGFloat.random(in: 0...UIScreen.main.bounds.height * 0.6)
        )
    }

    /// Animates confetti with concurrency-friendly SwiftUI animation APIs.
    /// - Parameter index: Index of the confetti piece to animate.
    private func animateConfetti(index: Int) async {
        // Initialize positions and opacity arrays if needed
        if confettiPositions.count <= index {
            confettiPositions.append(randomPosition())
        }
        if opacityValues.count <= index {
            opacityValues.append(Double.random(in: 0.7...1.0))
        }
        while isVisible {
            await withAnimation(.easeOut(duration: 2.5)) {
                confettiPositions[index] = randomPosition()
                opacityValues[index] = Double.random(in: 0.7...1.0)
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
    }
}

// MARK: - SwiftUI Preview
#if DEBUG
struct CelebrationManagerPreview: View {
    @State private var show = false
    @State private var type: CelebrationType = .loyaltyReward

    var body: some View {
        ZStack {
            VStack(spacing: AppSpacing.medium) {
                ForEach(CelebrationType.allCases) { celebration in
                    Button(celebration.displayName) {
                        type = celebration
                        Task {
                            show = true
                            await CelebrationManager.shared.celebrate(celebration)
                            show = false
                        }
                    }
                }
            }
            ConfettiOverlay(isVisible: $show, type: type)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

#Preview {
    CelebrationManagerPreview()
}
#endif

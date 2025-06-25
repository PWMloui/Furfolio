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

    // MARK: - Celebration Audit Log & Analytics

    struct CelebrationAuditEvent: Codable {
        let timestamp: Date
        let type: CelebrationType
        let tagTokens: [String]
        let overlayShown: Bool
        let soundPlayed: Bool
        let hapticTriggered: Bool
        let actor: String?          // User, staff, or system (for future)
        let context: String?        // e.g., "manual", "auto", "marketing", "reward"
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(type.displayName) celebration at \(dateStr). Overlay: \(overlayShown ? "on" : "off"), sound: \(soundPlayed ? "yes" : "no"), haptic: \(hapticTriggered ? "yes" : "no")."
        }
    }
    static private(set) var auditLog: [CelebrationAuditEvent] = []

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func logCelebration(
        type: CelebrationType,
        overlay: Bool,
        sound: Bool,
        haptic: Bool,
        actor: String? = nil,
        context: String? = nil
    ) {
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
        Self.auditLog.append(event)
        if Self.auditLog.count > 2000 { Self.auditLog.removeFirst() }
    }

    /// Human-readable summary of last celebration for accessibility/dashboard.
    var accessibilityCelebrationLabel: String {
        Self.auditLog.last?.accessibilityLabel ?? "No celebrations recorded."
    }

    /// Call to trigger a celebration overlay, sound, and haptics.
    /// - Parameters:
    ///   - type: The type of celebration to trigger.
    ///   - completion: Optional completion handler called after celebration ends.
    ///   - actor/context: Optionally supply user or reason for audit.
    func celebrate(_ type: CelebrationType, completion: (() -> Void)? = nil, actor: String? = nil, context: String? = nil) {
        celebrationType = type
        isCelebrating = true
        var soundPlayed = false
        var hapticTriggered = false

        if playSound(for: type) { soundPlayed = true }
        if triggerHaptic(for: type) { hapticTriggered = true }

        // Unified audit/event logging for compliance and analytics.
        logCelebration(type: type, overlay: true, sound: soundPlayed, haptic: hapticTriggered, actor: actor, context: context)

        // Business audit trail, analytics, or notification can be plugged here.

        // Auto-dismiss after 2.5s (tunable)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.isCelebrating = false
            self.celebrationType = nil
            completion?()
        }
    }

    @discardableResult
    private func playSound(for type: CelebrationType) -> Bool {
        guard let url = Bundle.main.url(forResource: type.soundName, withExtension: "mp3") else { return false }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            return true
        } catch {
            print("[CelebrationManager] Sound error: \(error)")
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

    var displayName: String {
        switch self {
        case .loyaltyReward: return "Loyalty Reward"
        case .businessMilestone: return "Business Milestone"
        case .petBirthday: return "Pet Birthday"
        case .bigSale: return "Big Sale"
        case .onboardingComplete: return "Onboarding Complete"
        case .staffAnniversary: return "Staff Anniversary"
        case .retentionGoal: return "Retention Goal"
        case .custom: return "Special Celebration"
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

    /// Tokenized tags for analytics, dashboards, and compliance.
    var tags: [String] {
        switch self {
        case .loyaltyReward: return ["loyalty", "reward", "client"]
        case .businessMilestone: return ["business", "milestone", "growth"]
        case .petBirthday: return ["pet", "birthday", "fun"]
        case .bigSale: return ["sale", "revenue", "finance"]
        case .onboardingComplete: return ["onboarding", "client", "activation"]
        case .staffAnniversary: return ["staff", "anniversary", "team"]
        case .retentionGoal: return ["retention", "goal", "kpi"]
        case .custom: return ["custom", "special"]
        }
    }
}

/// Overlay View for instant drop-in celebration UI.
/// For "pro" confetti, integrate with a package or a custom particle system.
/// No system or hardcoded styling is allowed; all color, font, spacing, and corner radius must use design tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows).
struct ConfettiOverlay: View {
    @Binding var isVisible: Bool
    var type: CelebrationType

    var body: some View {
        if isVisible {
            ZStack {
                ForEach(0..<36) { _ in
                    Text(type.icon)
                        .font(AppFonts.confettiIcon)
                        .position(
                            x: CGFloat.random(in: 20...UIScreen.main.bounds.width - 20),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height * 0.6)
                        )
                        .opacity(Double.random(in: 0.7...1.0))
                        .accessibilityHidden(true)
                        .animation(.easeOut(duration: 2.5), value: isVisible)
                }
                VStack {
                    Spacer()
                    Text(type.displayName)
                        .font(AppFonts.largeTitleHeavy)
                        .padding(AppSpacing.large)
                        .background(AppColors.ultraThinMaterial)
                        .cornerRadius(BorderRadius.extraLarge)
                        .padding(.bottom, AppSpacing.xxl)
                        .accessibilityLabel("\(type.displayName) celebration")
                }
            }
            .transition(.opacity.combined(with: .scale))
            .zIndex(10)
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
                        show = true
                        CelebrationManager.shared.celebrate(celebration)
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

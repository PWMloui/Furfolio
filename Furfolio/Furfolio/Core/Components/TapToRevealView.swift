//
//  TapToRevealView.swift
//  Furfolio
//
//  Architecture & Extensibility:
//  -----------------------------
//  TapToRevealView is a reusable SwiftUI component designed to securely reveal sensitive content upon user interaction.
//  It supports role-based access control, optional re-hiding of content, and customizable placeholder and content views.
//
//  Analytics, Audit & Trust Center Integration:
//  ---------------------------------------------
//  The view integrates with an async/await-ready analytics logging system via the TapToRevealAnalyticsLogger protocol.
//  It supports audit tagging and logs reveal/hide events with detailed contextual info.
//  The logger includes a testMode for QA, diagnostics, and console-only logging in previews/tests.
//
//  Diagnostics & Event Buffer:
//  ---------------------------
//  A capped in-memory buffer stores the last 20 analytics events for diagnostics and admin access.
//  Public API allows retrieval of recent events for inspection.
//
//  Localization & Accessibility:
//  -----------------------------
//  All user-facing strings and log event identifiers are localized using NSLocalizedString with appropriate keys and comments.
//  Accessibility traits, labels, and hints are carefully applied to ensure compliance and usability.
//
//  Compliance & Trust Center:
//  ---------------------------
//  Audit tags and role-based restrictions support business policy enforcement and compliance requirements.
//
//  Preview & Testability:
//  ----------------------
//  The preview provider demonstrates multiple configurations, including restricted access, re-hiding, audit tags,
//  and shows analytics logging in testMode.
//  Accessibility and diagnostics buffer usage are also showcased for maintainers and testers.
//
//  Maintainers should refer to the protocol and struct doc-comments for usage and extension guidance.

import SwiftUI
import UIKit

// MARK: - Audit Context (set at login/session)
public struct TapToRevealAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "TapToRevealView"
}

// MARK: - Analytics/Audit Protocol

public protocol TapToRevealAnalyticsLogger {
    var testMode: Bool { get set }
    func log(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullTapToRevealAnalyticsLogger: TapToRevealAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(
        event: String,
        info: [String : Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[NullTapToRevealAnalyticsLogger][TestMode] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
        // No-op otherwise
    }
}

// MARK: - TapToRevealView (Enterprise Enhanced)

/// A SwiftUI view that reveals sensitive content upon user tap, with optional access control,
/// re-hide capability, audit tagging, and integrated asynchronous analytics logging.
/// Supports localization, accessibility, and diagnostics for compliance and maintainability.
struct TapToRevealView<Content: View>: View {
    /// Placeholder or obscured text shown when content is hidden.
    var placeholder: String = NSLocalizedString("TapToRevealView.placeholder.default", value: "Tap to reveal", comment: "Default placeholder text for TapToRevealView")

    /// The content to reveal.
    @ViewBuilder var content: () -> Content

    /// Optional user role for access control (default allows all).
    var userRole: UserRole = .unrestricted

    /// Whether the content can be re-hidden (default false).
    var canRehide: Bool = false

    /// Callback executed when content is revealed (default nil).
    var onReveal: (() -> Void)? = nil

    /// Optional audit tag for BI/Trust Center/compliance.
    var auditTag: String? = nil

    @State private var isRevealed: Bool = false

    // MARK: Analytics Logger & Diagnostics Buffer

    /// Shared analytics logger instance for TapToRevealView.
    /// Swap this for QA, print, Trust Center, or other implementations.
    static var analyticsLogger: TapToRevealAnalyticsLogger = NullTapToRevealAnalyticsLogger()

    /// In-memory capped buffer storing last 20 analytics events for diagnostics.
    private static var eventBuffer: [AnalyticsEvent] = []
    private static let eventBufferQueue = DispatchQueue(label: "TapToRevealView.eventBufferQueue")
    struct AnalyticsEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let event: String
        let info: [String: Any]?
        let role: String?
        let staffID: String?
        let context: String?
        let escalate: Bool
    }
    private static func addEventToBuffer(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        eventBufferQueue.sync {
            let newEvent = AnalyticsEvent(
                timestamp: Date(),
                event: event,
                info: info,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            eventBuffer.append(newEvent)
            if eventBuffer.count > 20 {
                eventBuffer.removeFirst(eventBuffer.count - 20)
            }
        }
    }
    public static func fetchRecentEvents() -> [AnalyticsEvent] {
        eventBufferQueue.sync { eventBuffer }
    }

    var body: some View {
        Group {
            if isRevealed {
                content()
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(NSLocalizedString("TapToRevealView.accessibility.revealedLabel", value: "Revealed content", comment: "Accessibility label for revealed content"))
                    .accessibilityValue(Text(NSLocalizedString("TapToRevealView.accessibility.revealedValue", value: "Content revealed", comment: "Accessibility value indicating content is revealed")))
                    .transition(.opacity.combined(with: .scale))
                    .overlay(
                        canRehide ? Button(action: toggleReveal) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(AppColors.accent)
                                .accessibilityLabel(NSLocalizedString("TapToRevealView.accessibility.hideLabel", value: "Hide content", comment: "Accessibility label for hide content button"))
                                .accessibilityHint(NSLocalizedString("TapToRevealView.accessibility.hideHint", value: "Tap to re-hide sensitive content", comment: "Accessibility hint for hide content button"))
                                .font(AppFonts.body.weight(.semibold))
                                .padding(AppSpacing.small)
                                .background(RoundedRectangle(cornerRadius: BorderRadius.medium).fill(AppColors.card))
                        }
                        .buttonStyle(.plain)
                        .padding([.top, .trailing], AppSpacing.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        : nil
                    )
            } else {
                PlaceholderView(
                    placeholder: placeholder,
                    isEnabled: isUserAllowed,
                    action: toggleReveal
                )
                .accessibilityLabel(placeholder)
                .accessibilityValue(isUserAllowed ? Text(NSLocalizedString("TapToRevealView.accessibility.tapToRevealValue", value: "Tap to reveal hidden content", comment: "Accessibility value when tap to reveal is enabled")) : Text(NSLocalizedString("TapToRevealView.accessibility.accessRestrictedValue", value: "Access restricted", comment: "Accessibility value when access is restricted")))
                .accessibilityHint(isUserAllowed ? NSLocalizedString("TapToRevealView.accessibility.tapToRevealHint", value: "Tap to show sensitive info", comment: "Accessibility hint when tap to reveal is enabled") : NSLocalizedString("TapToRevealView.accessibility.accessRestrictedHint", value: "Restricted by business policy", comment: "Accessibility hint when access is restricted"))
            }
        }
        .animation(.easeInOut, value: isRevealed)
        .backgroundStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("TapToRevealView_\(placeholder.replacingOccurrences(of: " ", with: "_"))")
    }

    /// Determines if the current user role is allowed to reveal content.
    private var isUserAllowed: Bool {
        switch userRole {
        case .unrestricted: true
        case .restricted:   false
        }
    }

    /// Toggles the reveal state with animation and logs analytics asynchronously.
    private func toggleReveal() {
        Task {
            let role = TapToRevealAuditContext.role
            let staffID = TapToRevealAuditContext.staffID
            let context = TapToRevealAuditContext.context
            let lowerAuditTag = (auditTag ?? "").lowercased()
            func shouldEscalate(event: String, auditTag: String?) -> Bool {
                let lower = event.lowercased()
                let keywords = ["danger", "critical", "delete"]
                for word in keywords {
                    if lower.contains(word) { return true }
                    if (auditTag ?? "").lowercased().contains(word) { return true }
                }
                return false
            }
            guard isUserAllowed else {
                let blockedEvent = NSLocalizedString("TapToRevealView.analytics.event.revealBlocked", value: "reveal_blocked", comment: "Analytics event when reveal is blocked due to role")
                let info: [String: Any] = [
                    "placeholder": placeholder,
                    "role": "\(userRole)",
                    "auditTag": auditTag as Any
                ]
                let escalate = shouldEscalate(event: blockedEvent, auditTag: auditTag)
                await Self.analyticsLogger.log(
                    event: blockedEvent,
                    info: info,
                    role: role,
                    staffID: staffID,
                    context: context,
                    escalate: escalate
                )
                Self.addEventToBuffer(
                    event: blockedEvent,
                    info: info,
                    role: role,
                    staffID: staffID,
                    context: context,
                    escalate: escalate
                )
                return
            }
            withAnimation {
                isRevealed.toggle()
            }
            let eventKey = isRevealed ? "TapToRevealView.analytics.event.revealed" : "TapToRevealView.analytics.event.hidden"
            let eventName = NSLocalizedString(eventKey, value: isRevealed ? "revealed" : "hidden", comment: "Analytics event for reveal or hide action")
            let eventInfo: [String: Any] = [
                "placeholder": placeholder,
                "role": "\(userRole)",
                "canRehide": canRehide,
                "auditTag": auditTag as Any
            ]
            let escalate = shouldEscalate(event: eventName, auditTag: auditTag)
            await Self.analyticsLogger.log(
                event: eventName,
                info: eventInfo,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            Self.addEventToBuffer(
                event: eventName,
                info: eventInfo,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
            if isRevealed {
                onReveal?()
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif
            }
        }
    }

    /// Defines user roles for access control.
    enum UserRole: CustomStringConvertible {
        case unrestricted
        case restricted

        var description: String {
            switch self {
            case .unrestricted: return "unrestricted"
            case .restricted:   return "restricted"
            }
        }
    }

    /// Internal view representing the placeholder button shown when content is hidden.
    private struct PlaceholderView: View {
        let placeholder: String
        let isEnabled: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(AppColors.gray)
                        .font(AppFonts.body)
                    Text(placeholder)
                        .foregroundColor(AppColors.gray)
                        .italic()
                        .font(AppFonts.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.card)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(placeholder)
            .disabled(!isEnabled)
            .accessibilityHint(isEnabled ? NSLocalizedString("TapToRevealView.accessibility.tapToRevealHint", value: "Tap to reveal hidden content", comment: "Accessibility hint when tap to reveal is enabled") : NSLocalizedString("TapToRevealView.accessibility.accessRestrictedHint", value: "Access restricted", comment: "Accessibility hint when access is restricted"))
        }
    }
}

// MARK: - Preview with Analytics Logger, Accessibility, and Diagnostics Buffer

#Preview {
    /// Spy logger that prints analytics events to console and stores them in the diagnostics buffer.
    struct SpyLogger: TapToRevealAnalyticsLogger {
        var testMode: Bool = true
        func log(
            event: String,
            info: [String : Any]?,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            if testMode {
                print("[TapToRevealAnalytics][TestMode] event: \(event), info: \(info ?? [:]), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
            }
            TapToRevealView.addEventToBuffer(
                event: event,
                info: info,
                role: role,
                staffID: staffID,
                context: context,
                escalate: escalate
            )
        }
    }

    // Assign SpyLogger with testMode enabled to the analyticsLogger.
    TapToRevealView.analyticsLogger = SpyLogger(testMode: true)

    // Fetch recent events from diagnostics buffer for display.
    @State var recentEvents: [TapToRevealView.AnalyticsEvent] = TapToRevealView.fetchRecentEvents()

    return VStack(spacing: AppSpacing.large) {
        TapToRevealView(placeholder: NSLocalizedString("TapToRevealView.preview.phonePlaceholder", value: "Tap to reveal phone", comment: "Preview placeholder for phone number")) {
            Text("555-123-4567")
                .font(AppFonts.title3.bold())
                .foregroundColor(AppColors.accent)
        } onReveal: {
            print("Phone number revealed")
        }

        TapToRevealView(placeholder: NSLocalizedString("TapToRevealView.preview.secretNotePlaceholder", value: "Tap to see secret note", comment: "Preview placeholder for secret note"), canRehide: true, auditTag: "grooming_note") {
            Text("This dog dislikes loud dryers.")
                .padding(AppSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.yellow)
                )
                .font(AppFonts.body)
        }

        TapToRevealView(placeholder: NSLocalizedString("TapToRevealView.preview.restrictedInfoPlaceholder", value: "Restricted info", comment: "Preview placeholder for restricted info"), userRole: .restricted, auditTag: "confidential_data") {
            Text("Sensitive data")
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }

        TapToRevealView(placeholder: NSLocalizedString("TapToRevealView.preview.accentPlaceholder", value: "Tap to reveal with accent", comment: "Preview placeholder with accent color"), canRehide: true, auditTag: "confidential_business_info") {
            Text("Confidential business info")
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }
        .onReveal {
            print("Confidential info revealed")
        }

        // Diagnostics Buffer Display
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("TapToRevealView.preview.diagnosticsTitle", value: "Recent Analytics Events:", comment: "Title for diagnostics event buffer display"))
                .font(AppFonts.caption.bold())
                .foregroundColor(AppColors.gray)
            ScrollView {
                ForEach(TapToRevealView.fetchRecentEvents().reversed()) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.timestamp, formatter: DateFormatter.localizedShortTime)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.gray)
                        Text("event: \(event.event)")
                            .font(AppFonts.caption)
                        if let info = event.info {
                            Text("info: \(info)")
                                .font(AppFonts.caption)
                        }
                        Text("role: \(event.role ?? "nil")")
                            .font(AppFonts.caption)
                        Text("staffID: \(event.staffID ?? "nil")")
                            .font(AppFonts.caption)
                        Text("context: \(event.context ?? "nil")")
                            .font(AppFonts.caption)
                        Text("escalate: \(event.escalate ? "true" : "false")")
                            .font(AppFonts.caption)
                        Divider()
                    }
                    .foregroundColor(AppColors.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                }
            }
            .frame(height: 180)
            .background(RoundedRectangle(cornerRadius: BorderRadius.small).fill(AppColors.card))
        }
        .padding(.top, AppSpacing.medium)
    }
    .padding(AppSpacing.large)
    .background(AppColors.background)
}

/// DateFormatter extension for localized short time formatting in diagnostics display.
fileprivate extension DateFormatter {
    static var localizedShortTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.locale = Locale.current
        return formatter
    }
}

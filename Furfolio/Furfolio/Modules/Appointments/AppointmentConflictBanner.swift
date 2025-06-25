//
//  AppointmentConflictBanner.swift
//  Furfolio
//
//  ENHANCED: Tokenized, Modular, Auditable Conflict Notification Banner
//

import SwiftUI

// MARK: - Audit/Event Logging for AppointmentConflictBanner

fileprivate struct ConflictBannerAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "appear", "dismiss", "resolve"
    let message: String
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(message) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class ConflictBannerAudit {
    static private(set) var log: [ConflictBannerAuditEvent] = []

    static func record(
        operation: String,
        message: String,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentConflictBanner",
        detail: String? = nil
    ) {
        let event = ConflictBannerAuditEvent(
            timestamp: Date(),
            operation: operation,
            message: message,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 250 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No conflict banner actions recorded."
    }
}

// MARK: - AppointmentConflictBannerStyle

struct AppointmentConflictBannerStyle {
    var gradientColors: [Color] = [AppColors.warning, AppColors.critical]
    var shadowColor: Color = AppColors.critical.opacity(0.16)
    var cornerRadius: CGFloat = 14
    var padding: CGFloat = 16
}

/// A unified and modern banner view indicating scheduling conflicts for appointments.
/// Now with built-in audit/event logging for all key user interactions.
struct AppointmentConflictBanner: View {
    var message: String = "⚠️ Appointment conflict detected! Another appointment overlaps with this time."
    var onResolve: (() -> Void)? = nil
    @Binding var isVisible: Bool
    var resolveButtonTitle: String = NSLocalizedString("Resolve", comment: "Resolve appointment conflict button")
    var style: AppointmentConflictBannerStyle = AppointmentConflictBannerStyle()

    @State private var animateIn: Bool = false
    @State private var bounce: Bool = false

    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.textOnAccent)
                        .font(AppFonts.title2Bold)
                        .padding(.leading, AppSpacing.small)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(AppFonts.subheadlineSemibold)
                        .foregroundColor(AppColors.textOnAccent)
                        .accessibilityLabel(message)
                        .accessibilityIdentifier("ConflictMessage")
                    Spacer()
                    if let onResolve = onResolve {
                        Button(action: {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            ConflictBannerAudit.record(
                                operation: "resolve",
                                message: message,
                                tags: ["conflict", "resolve"],
                                detail: "User tapped resolve"
                            )
                            onResolve()
                        }) {
                            Text(resolveButtonTitle)
                                .font(AppFonts.calloutBold)
                                .padding(.horizontal, AppSpacing.medium)
                                .padding(.vertical, AppSpacing.small)
                                .background(AppColors.textOnAccent.opacity(0.22))
                                .foregroundColor(AppColors.textOnAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(resolveButtonTitle) conflict")
                        .accessibilityIdentifier("ResolveButton")
                    }
                    Button(action: {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation { isVisible = false }
                        ConflictBannerAudit.record(
                            operation: "dismiss",
                            message: message,
                            tags: ["conflict", "dismiss"],
                            detail: "User dismissed banner"
                        )
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textOnAccent.opacity(0.7))
                            .font(AppFonts.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, AppSpacing.small)
                    .accessibilityLabel("Dismiss banner")
                    .accessibilityIdentifier("DismissButton")
                }
                .padding(.horizontal, AppSpacing.medium)
                .padding(.vertical, AppSpacing.small)
            }
            .background(
                LinearGradient(
                    colors: style.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(animateIn ? 1 : 0.88)
            )
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .shadow(color: style.shadowColor, radius: 7, x: 0, y: 2)
            .padding(.horizontal, style.padding)
            .padding(.top, 10)
            .scaleEffect(bounce ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1), value: bounce)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(100)
            .onAppear {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                    animateIn = true
                }
                bounce = true
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                ConflictBannerAudit.record(
                    operation: "appear",
                    message: message,
                    tags: ["conflict", "appear"],
                    detail: "Banner shown"
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                        bounce = false
                    }
                }
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("AppointmentConflictBanner")
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ConflictBannerAuditAdmin {
    public static var lastSummary: String { ConflictBannerAudit.accessibilitySummary }
    public static var lastJSON: String? { ConflictBannerAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ConflictBannerAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct AppointmentConflictBanner_Previews: PreviewProvider {
    struct Demo: View {
        @State private var show = true
        var body: some View {
            VStack {
                Spacer()
                AppointmentConflictBanner(message: "⚠️ You have an overlapping appointment!", isVisible: $show, onResolve: {
                    show = false
                }, resolveButtonTitle: "Fix Now")
                Spacer()
                Button("Toggle Banner") {
                    withAnimation { show.toggle() }
                }
                .padding()
                .background(AppColors.accent.opacity(0.8))
                .foregroundColor(AppColors.textOnAccent)
                .clipShape(Capsule())
            }
            .background(AppColors.background)
        }
    }
    static var previews: some View {
        Demo()
            .previewLayout(.sizeThatFits)
    }
}
#endif

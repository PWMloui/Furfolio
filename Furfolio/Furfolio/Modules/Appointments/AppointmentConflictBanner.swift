//
//  AppointmentConflictBanner.swift
//  Furfolio
//
//  ENHANCED: Tokenized, Modular, Auditable Conflict Notification Banner
//

import SwiftUI
import Combine

// MARK: - ConflictingAppointment Model

/// Represents a conflicting appointment with relevant details and an optional action.
public struct ConflictingAppointment: Identifiable {
    public let id = UUID()
    public let time: String
    public let dog: String
    public let owner: String
    public let viewAction: (() -> Void)?

    public init(time: String, dog: String, owner: String, viewAction: (() -> Void)? = nil) {
        self.time = time
        self.dog = dog
        self.owner = owner
        self.viewAction = viewAction
    }
}

// MARK: - Audit/Event Logging for AppointmentConflictBanner

fileprivate struct ConflictBannerAuditEvent: Codable {
    let timestamp: Date
    let operation: String          // "appear", "dismiss", "resolve", "autoDismissed", "infoShown"
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
    var chipBackgroundColor: Color = AppColors.critical.opacity(0.3)
    var chipTextColor: Color = AppColors.textOnAccent
    var pulseBorderColor: Color = AppColors.critical.opacity(0.6)
}

/// A unified and modern banner view indicating scheduling conflicts for appointments.
/// Now with built-in audit/event logging and info popover, chip label, pulsing border, auto-dismiss, and accessibility enhancements.
public struct AppointmentConflictBanner: View {
    // MARK: - Public API
    
    public var message: String = "⚠️ Appointment conflict detected! Another appointment overlaps with this time."
    public var onResolve: (() -> Void)? = nil
    @Binding public var isVisible: Bool
    public var resolveButtonTitle: String = NSLocalizedString("Resolve", comment: "Resolve appointment conflict button")
    public var style: AppointmentConflictBannerStyle = AppointmentConflictBannerStyle()
    
    /// Optional chip label displayed at the start of the banner (e.g. "Overlap: 11:00–11:30 AM")
    public var chipLabel: String? = nil
    
    /// Conflict summary details shown in the info popover/sheet as bullet points.
    public var conflictDetails: [String] = []
    
    /// List of conflicting appointments displayed in the info popover/sheet.
    public var conflictingAppointments: [ConflictingAppointment] = []
    
    // MARK: - Private State
    
    @State private var animateIn: Bool = false
    @State private var bounce: Bool = false
    @State private var showInfoPopover: Bool = false
    @State private var pulseBorder: Bool = false
    @State private var showAuditEventsSheet: Bool = false
    @State private var autoDismissCancellable: AnyCancellable? = nil

    // MARK: - Body
    
    public var body: some View {
        if isVisible {
            content
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
                .overlay(
                    // Pulsing border after 7 seconds visible
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(style.pulseBorderColor, lineWidth: pulseBorder ? 2 : 0)
                        .opacity(pulseBorder ? 1 : 0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseBorder)
                )
                .padding(.horizontal, style.padding)
                .padding(.top, 10)
                .scaleEffect(bounce ? 1.05 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1), value: bounce)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(100)
                .onAppear(perform: onAppearActions)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("AppointmentConflictBanner")
                // Debug long press gesture to show audit events sheet
                #if DEBUG
                .onLongPressGesture {
                    showAuditEventsSheet = true
                }
                .sheet(isPresented: $showAuditEventsSheet) {
                    AuditEventsSheet()
                }
                #endif
                // Info popover or sheet depending on platform
                .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                    InfoPopoverContent()
                        .frame(minWidth: 300, minHeight: 300)
                }
                .sheet(isPresented: $showInfoPopover) {
                    InfoPopoverContent()
                }
        }
    }
    
    // MARK: - Banner Content View
    
    private var content: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                // Colored chip at start if provided
                if let chipLabel = chipLabel {
                    Text(chipLabel)
                        .font(AppFonts.footnoteBold)
                        .foregroundColor(style.chipTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(style.chipBackgroundColor)
                        .clipShape(Capsule())
                        .accessibilityLabel("Conflict time: \(chipLabel)")
                }
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColors.textOnAccent)
                    .font(AppFonts.title2Bold)
                    .padding(.leading, chipLabel == nil ? AppSpacing.small : 0)
                    .accessibilityHidden(true)
                
                Text(message)
                    .font(AppFonts.subheadlineSemibold)
                    .foregroundColor(AppColors.textOnAccent)
                    .accessibilityLabel(message)
                    .accessibilityIdentifier("ConflictMessage")
                
                // Info button to show conflict details popover/sheet
                Button(action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    ConflictBannerAudit.record(
                        operation: "infoShown",
                        message: message,
                        tags: ["conflict", "info"],
                        detail: "User tapped info button"
                    )
                    showInfoPopover = true
                }) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(AppColors.textOnAccent.opacity(0.8))
                        .font(AppFonts.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show conflict details")
                .accessibilityIdentifier("InfoButton")
                
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
    }
    
    // MARK: - On Appear Actions
    
    private func onAppearActions() {
        withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
            animateIn = true
        }
        bounce = true
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        // Announce conflict message via VoiceOver
        UIAccessibility.post(notification: .announcement, argument: message)
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
        // Start pulsing border after 7 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            withAnimation {
                pulseBorder = true
            }
        }
        // Auto-dismiss banner after 30 seconds if still visible
        autoDismissCancellable = Just(())
            .delay(for: .seconds(30), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isVisible {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.isVisible = false
                    }
                    ConflictBannerAudit.record(
                        operation: "autoDismissed",
                        message: self.message,
                        tags: ["conflict", "autoDismiss"],
                        detail: "Banner auto-dismissed after 30 seconds"
                    )
                }
            }
    }
    
    // MARK: - Info Popover Content View
    
    @ViewBuilder
    private func InfoPopoverContent() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Conflict Summary")
                    .font(AppFonts.headlineBold)
                    .padding(.bottom, 4)
                if conflictDetails.isEmpty {
                    Text("No details available.")
                        .font(AppFonts.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(conflictDetails, id: \.self) { detail in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .font(AppFonts.subheadlineBold)
                                    .foregroundColor(AppColors.critical)
                                Text(detail)
                                    .font(AppFonts.subheadline)
                                    .foregroundColor(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Text("Conflicting Appointments")
                    .font(AppFonts.headlineBold)
                    .padding(.bottom, 4)
                
                if conflictingAppointments.isEmpty {
                    Text("No conflicting appointments listed.")
                        .font(AppFonts.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(conflictingAppointments) { appointment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(appointment.time)
                                            .font(AppFonts.subheadlineSemibold)
                                            .foregroundColor(AppColors.textPrimary)
                                        Text("\(appointment.dog) — \(appointment.owner)")
                                            .font(AppFonts.subheadline)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    Spacer()
                                    if let action = appointment.viewAction {
                                        Button("View") {
                                            #if canImport(UIKit)
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            #endif
                                            action()
                                        }
                                        .font(AppFonts.calloutBold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(AppColors.accent.opacity(0.2))
                                        .foregroundColor(AppColors.accent)
                                        .clipShape(Capsule())
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("View appointment at \(appointment.time)")
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ConflictInfoPopover")
    }
    
    // MARK: - Audit Events Sheet (Debug Only)
    
    #if DEBUG
    private struct AuditEventsSheet: View {
        @Environment(\.presentationMode) var presentationMode
        var body: some View {
            NavigationView {
                List {
                    ForEach(ConflictBannerAudit.log.suffix(5).reversed(), id: \.timestamp) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.operation.capitalized)
                                .font(.headline)
                            Text(event.accessibilityLabel)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Recent Audit Events")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
            }
        }
    }
    #endif
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
                AppointmentConflictBanner(
                    message: "⚠️ You have an overlapping appointment!",
                    isVisible: $show,
                    onResolve: {
                        show = false
                    },
                    resolveButtonTitle: "Fix Now",
                    chipLabel: "Overlap: 11:00–11:30 AM",
                    conflictDetails: [
                        "Appointment overlaps with another booking.",
                        "Please resolve to avoid double booking."
                    ],
                    conflictingAppointments: [
                        ConflictingAppointment(time: "11:00–11:30 AM", dog: "Buddy", owner: "Alice Smith", viewAction: {
                            print("View Buddy's appointment tapped")
                        }),
                        ConflictingAppointment(time: "11:15–11:45 AM", dog: "Max", owner: "John Doe")
                    ]
                )
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

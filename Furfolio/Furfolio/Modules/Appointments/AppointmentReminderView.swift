//
//  AppointmentReminderView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - AppointmentReminderView (Tokenized, Modular, Auditable Reminder UI)

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct AppointmentReminderAuditEvent: Codable {
    let timestamp: Date
    let operation: String           // "appear", "snooze", "markDone"
    let appointmentID: UUID
    let dogName: String?
    let ownerName: String?
    let serviceType: String
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(appointmentID) (\(dogName ?? "?") / \(ownerName ?? "?")) [\(serviceType)] [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class AppointmentReminderAudit {
    static private(set) var log: [AppointmentReminderAuditEvent] = []

    static func record(
        operation: String,
        appointment: Appointment,
        tags: [String] = [],
        actor: String? = "user",
        context: String? = "AppointmentReminderView",
        detail: String? = nil
    ) {
        let event = AppointmentReminderAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointment.id,
            dogName: appointment.dog?.name,
            ownerName: appointment.owner?.ownerName,
            serviceType: appointment.serviceType,
            tags: tags.isEmpty ? appointment.tags : tags,
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
        log.last?.accessibilityLabel ?? "No reminder actions recorded."
    }
}


/// A modular, tokenized, and auditable appointment reminder view supporting business workflows, accessibility, localization, and UI design system integration.
/// This view leverages design tokens for fonts, colors, spacing, borders, and shadows to ensure consistency and maintainability across the app.

struct AppointmentReminderView: View {
    @Binding var appointment: Appointment
    var onSnooze: (() -> Void)?
    var onMarkDone: (() -> Void)?

    // Enhancement: Track if actions are disabled (after done/no-show)
    @State private var actionsDisabled: Bool = false
    // Enhancement: Show snooze menu
    @State private var showSnoozeMenu: Bool = false
    // Enhancement: Show toast and its message
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""

    // Enhancement: For VoiceOver
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled

    // Snooze durations in minutes
    private let snoozeDurations: [Int] = [5, 10, 15, 30]

    // Enhancement: Timer for progress bar
    @State private var now: Date = Date()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack {
                Text("Upcoming Appointment")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.accent)
                Spacer()
                // Enhancement: Mark as Done button
                Button {
                    AppointmentReminderAudit.record(
                        operation: "markDone",
                        appointment: appointment,
                        tags: ["markDone"],
                        detail: "User marked appointment as done"
                    )
                    actionsDisabled = true
                    toastMessage = "Marked as done"
                    showToast = true
                    onMarkDone?()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.success)
                }
                .buttonStyle(.plain)
                .disabled(actionsDisabled)

                // Enhancement: Mark as No-Show button
                Button {
                    AppointmentReminderAudit.record(
                        operation: "markNoShow",
                        appointment: appointment,
                        tags: ["noShow"],
                        detail: "User marked appointment as no-show"
                    )
                    actionsDisabled = true
                    toastMessage = "No-show marked"
                    showToast = true
                } label: {
                    Image(systemName: "circle.slash")
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.error)
                        .accessibilityLabel("Mark as No-Show")
                }
                .buttonStyle(.plain)
                .disabled(actionsDisabled)

                // Enhancement: Snooze menu button
                ZStack {
                    Button {
                        // Show snooze duration menu
                        showSnoozeMenu = true
                    } label: {
                        Image(systemName: "bell.slash.fill")
                            .font(AppFonts.title2)
                            .foregroundColor(AppColors.warning)
                    }
                    .buttonStyle(.plain)
                    .disabled(actionsDisabled)
                    // Enhancement: Snooze duration menu
                    if showSnoozeMenu {
                        Menu {
                            ForEach(snoozeDurations, id: \.self) { min in
                                Button {
                                    AppointmentReminderAudit.record(
                                        operation: "snooze",
                                        appointment: appointment,
                                        tags: ["snooze"],
                                        detail: "User snoozed for \(min) minutes"
                                    )
                                    showSnoozeMenu = false
                                    toastMessage = "Snoozed for \(min) min"
                                    showToast = true
                                    onSnooze?()
                                } label: {
                                    Text("Snooze \(min) min")
                                }
                            }
                            Button("Cancel", role: .cancel) {
                                showSnoozeMenu = false
                            }
                        } label: {
                            EmptyView()
                        }
                        // Position menu above the bell
                        .frame(width: 0, height: 0)
                    }
                }
            }

            Group {
                Text("Dog: \(appointment.dog?.name ?? "Unknown")")
                Text("Owner: \(appointment.owner?.ownerName ?? "Unknown")")
                Text("Date: \(formattedDate(appointment.date))")
            }
            .font(AppFonts.subheadline)
            .foregroundColor(AppColors.textPrimary)

            if let notes = appointment.notes, !notes.isEmpty {
                Text("Notes: \(notes)")
                    .font(AppFonts.footnote)
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(3)
            }

            // Enhancement: Progress bar for time left until appointment
            progressBarView
        }
        .padding(AppSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: BorderRadius.medium)
                .fill(AppColors.background)
                .shadow(
                    color: AppShadows.medium.color,
                    radius: AppShadows.medium.radius,
                    x: AppShadows.medium.x,
                    y: AppShadows.medium.y
                )
        )
        .padding(.horizontal, AppSpacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Upcoming appointment reminder"))
        .onAppear {
            AppointmentReminderAudit.record(
                operation: "appear",
                appointment: appointment,
                tags: ["appear"],
                detail: "Reminder appeared"
            )
            // Enhancement: VoiceOver announcement
            let dog = appointment.dog?.name ?? "Unknown dog"
            let owner = appointment.owner?.ownerName ?? "Unknown owner"
            let time = formattedDate(appointment.date)
            let announcement = "\(dog), owner \(owner), appointment at \(time)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if voiceOverEnabled {
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
            }
        }
        // Enhancement: Dim/fade view when actions disabled (done/no-show)
        .opacity(actionsDisabled ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: actionsDisabled)
        // Enhancement: Timer for progress bar
        .onReceive(timer) { t in
            self.now = Date()
        }
        // Enhancement: Toast for done/no-show/snooze
        .overlay(alignment: .top) {
            if showToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
    }

    // Enhancement: Progress bar view
    private var progressBarView: some View {
        let total = max(appointment.date.timeIntervalSince(now), 0)
        let fullInterval = max(appointment.date.timeIntervalSince(appointment.createdAt ?? (now - 3600)), 60)
        // Show as percent of time left, but clamp at 0...1
        let percent: Double = {
            let until = appointment.date.timeIntervalSince(now)
            let totalAvailable = appointment.date.timeIntervalSince(appointment.createdAt ?? (now - 3600))
            if totalAvailable <= 0 { return 0 }
            return min(max(until / totalAvailable, 0), 1)
        }()
        // If <10 min left, warning color
        let minLeft = appointment.date.timeIntervalSince(now) / 60
        let barColor = minLeft < 10 ? AppColors.warning : AppColors.success
        return VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColors.secondaryBackground)
                        .frame(height: 7)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * CGFloat(percent), height: 7)
                }
            }
            .frame(height: 7)
            .accessibilityLabel(Text("Time left until appointment"))
            .accessibilityValue(Text("\(max(Int(minLeft),0)) minutes left"))
        }
        .padding(.top, AppSpacing.small)
    }

    // Enhancement: Toast view
    private var toastView: some View {
        Text(toastMessage)
            .font(AppFonts.subheadline.bold())
            .foregroundColor(.white)
            .padding(.vertical, 8)
            .padding(.horizontal, 24)
            .background(
                Capsule()
                    .fill(AppColors.accent)
                    .shadow(radius: 4)
            )
            .padding(.top, 4)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .zIndex(2)
            .accessibilityAddTraits(.isStaticText)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Audit/Admin Accessors

public enum AppointmentReminderAuditAdmin {
    public static var lastSummary: String { AppointmentReminderAudit.accessibilitySummary }
    public static var lastJSON: String? { AppointmentReminderAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AppointmentReminderAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    /// Enhancement: Export all audit events as CSV (headers: timestamp,operation,appointmentID,dogName,ownerName,serviceType,tags,actor,context,detail)
    public static func exportCSV() -> String {
        let header = "timestamp,operation,appointmentID,dogName,ownerName,serviceType,tags,actor,context,detail"
        let formatter = ISO8601DateFormatter()
        let rows = AppointmentReminderAudit.log.map { event in
            [
                formatter.string(from: event.timestamp),
                event.operation,
                event.appointmentID.uuidString,
                event.dogName ?? "",
                event.ownerName ?? "",
                event.serviceType,
                event.tags.joined(separator: "|"),
                event.actor ?? "",
                event.context ?? "",
                event.detail?.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: ";") ?? ""
            ]
            .map { "\"\($0)\"" }
            .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}
// MARK: - Preview


#if DEBUG
struct AppointmentReminderView_Previews: PreviewProvider {
    @State static var sampleAppointment = Appointment(
        id: UUID(),
        date: Date().addingTimeInterval(3600),
        dog: Dog(id: UUID(), name: "Bella", birthDate: Date()),
        owner: DogOwner(id: UUID(), ownerName: "Jane Doe"),
        serviceType: "Full Groom",
        duration: 90,
        tags: ["VIP"],
        notes: "Prefers gentle shampoo.",
        behaviorLog: [],
        hasConflict: false,
        conflictMessage: nil
    )

    static var previews: some View {
        AppointmentReminderView(
            appointment: $sampleAppointment,
            onSnooze: { print("Snooze tapped") },
            onMarkDone: { print("Mark done tapped") }
        )
        .previewLayout(.sizeThatFits)
        .padding(AppSpacing.medium)
    }
}
#endif

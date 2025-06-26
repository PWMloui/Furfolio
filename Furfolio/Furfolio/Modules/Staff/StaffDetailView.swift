//  StaffDetailView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Staff Detail View
//

import SwiftUI
import SwiftData

@available(iOS 18.0, *)
struct StaffDetailView: View {
    @State var staffMember: StaffMember
    @State private var showDeactivateAlert = false
    @State private var showUndoDeactivation = false
    @State private var lastActiveStatus: Bool = true
    @State private var animateProfileBadge = false
    @State private var appearedOnce = false
    @State private var showAuditLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                // MARK: - Header Section
                profileHeader

                // MARK: - Quick Actions
                quickActions

                // MARK: - Performance Stats
                performanceStats

                // MARK: - Employment Details
                employmentDetails

                // MARK: - Danger Zone
                dangerZone
            }
            .padding(.vertical, AppTheme.Spacing.medium)
        }
        .navigationTitle(staffMember.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.background.ignoresSafeArea())
        .alert("Deactivate Staff Member?", isPresented: $showDeactivateAlert) {
            Button("Deactivate", role: .destructive, action: deactivateStaffMember)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to deactivate \(staffMember.name)? They will lose access to the app.")
                .accessibilityIdentifier("StaffDetailView-DeactivateAlertMessage")
        }
        .overlay(
            // Undo deactivation banner
            Group {
                if showUndoDeactivation {
                    HStack {
                        Label("Staff deactivated", systemImage: "exclamationmark.triangle.fill")
                        Spacer()
                        Button("Undo") { undoDeactivate() }
                            .buttonStyle(.borderedProminent)
                    }
                    .font(.callout)
                    .padding()
                    .background(Color.yellow.opacity(0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(radius: 3)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("StaffDetailView-UndoBanner")
                }
            }, alignment: .top
        )
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAuditLog = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .accessibilityLabel("View Audit Log")
                .accessibilityIdentifier("StaffDetailView-AuditLogButton")
            }
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(StaffDetailAuditAdmin.recentEvents(limit: 20), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Staff Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = StaffDetailAuditAdmin.recentEvents(limit: 20).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("StaffDetailView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                StaffDetailAudit.record(action: "Appear", staff: staffMember)
                lastActiveStatus = staffMember.isActive
                appearedOnce = true
            }
        }
        .onChange(of: staffMember.isActive) { isActive in
            if lastActiveStatus != isActive {
                animateProfileBadge = true
                StaffDetailAudit.record(action: isActive ? "Reactivated" : "Deactivated", staff: staffMember)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                lastActiveStatus = isActive
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { animateProfileBadge = false }
            }
        }
    }

    // MARK: - Private Subviews

    private var profileHeader: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            ZStack {
                Circle()
                    .fill(staffMember.isActive ? AppTheme.Colors.primary.opacity(0.19) : AppColors.danger.opacity(0.15))
                    .frame(width: 96, height: 96)
                    .scaleEffect(animateProfileBadge ? 1.12 : 1.0)
                    .animation(.spring(response: 0.36, dampingFraction: 0.53), value: animateProfileBadge)
                Image(systemName: staffMember.role.icon)
                    .font(.system(size: 60, weight: .medium))
                    .foregroundColor(staffMember.isActive ? AppTheme.Colors.primary : AppColors.danger)
                    .padding()
            }
            Text(staffMember.name)
                .font(AppTheme.Fonts.largeTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)
                .accessibilityIdentifier("StaffDetailView-Name")
            Text(staffMember.role.displayName)
                .font(AppTheme.Fonts.title)
                .foregroundColor(AppTheme.Colors.textSecondary)
                .accessibilityIdentifier("StaffDetailView-Role")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Staff Profile for \(staffMember.name), role: \(staffMember.role.displayName)")
    }

    private var quickActions: some View {
        HStack(spacing: AppTheme.Spacing.large) {
            if let phone = staffMember.phone, let url = URL(string: "tel:\(phone.onlyDigits)") {
                Link(destination: url) {
                    Label("Call", systemImage: "phone.fill")
                }
                .buttonStyle(FurfolioActionButtonStyle())
                .accessibilityIdentifier("StaffDetailView-CallButton")
                .onTapGesture {
                    StaffDetailAudit.record(action: "Call", staff: staffMember)
                }
            }
            if let email = staffMember.email, let url = URL(string: "mailto:\(email)") {
                Link(destination: url) {
                    Label("Email", systemImage: "envelope.fill")
                }
                .buttonStyle(FurfolioActionButtonStyle())
                .accessibilityIdentifier("StaffDetailView-EmailButton")
                .onTapGesture {
                    StaffDetailAudit.record(action: "Email", staff: staffMember)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var performanceStats: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(title: "Performance Stats")
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.medium) {
                    KPIStatCard(
                        title: "Appointments This Month",
                        value: "32",
                        subtitle: "June 2025",
                        systemIconName: "calendar",
                        iconBackgroundColor: AppColors.info
                    )
                    KPIStatCard(
                        title: "Avg. Rating",
                        value: "4.8",
                        subtitle: "Out of 5 stars",
                        systemIconName: "star.fill",
                        iconBackgroundColor: AppColors.warning
                    )
                    KPIStatCard(
                        title: "Total Revenue",
                        value: "$2,150",
                        subtitle: "This month",
                        systemIconName: "dollarsign.circle.fill",
                        iconBackgroundColor: AppColors.success
                    )
                }
                .padding(.horizontal)
            }
        }
    }

    private var employmentDetails: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(title: "Employment Details")
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.medium) {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(staffMember.isActive ? "Active" : "Inactive")
                        .foregroundColor(staffMember.isActive ? AppColors.success : AppColors.danger)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("StaffDetailView-Status")
                }
                HStack {
                    Text("Date Joined")
                    Spacer()
                    Text(staffMember.dateJoined, style: .date)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .accessibilityIdentifier("StaffDetailView-DateJoined")
                }
                if let lastActive = staffMember.lastActiveAt {
                    HStack {
                        Text("Last Active")
                        Spacer()
                        Text(lastActive, style: .date)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .accessibilityIdentifier("StaffDetailView-LastActive")
                    }
                }
            }
            .padding()
            .background(AppColors.card)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal)
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading) {
            SectionHeaderView(title: "Danger Zone")
                .padding(.horizontal)
            Button(role: .destructive) {
                showDeactivateAlert = true
            } label: {
                Label("Deactivate Staff Member", systemImage: "person.crop.circle.badge.xmark")
            }
            .buttonStyle(FurfolioActionButtonStyle(isDestructive: true))
            .padding(.horizontal)
            .accessibilityIdentifier("StaffDetailView-DeactivateButton")
        }
    }

    // MARK: - Deactivation Logic (with Undo)
    private func deactivateStaffMember() {
        if staffMember.isActive {
            staffMember.isActive = false
            showUndoDeactivation = true
            StaffDetailAudit.record(action: "Deactivated", staff: staffMember)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                withAnimation {
                    showUndoDeactivation = false
                }
            }
        }
    }

    private func undoDeactivate() {
        staffMember.isActive = true
        showUndoDeactivation = false
        StaffDetailAudit.record(action: "UndoDeactivate", staff: staffMember)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct StaffDetailAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let staffName: String
    let staffRole: String
    let wasActive: Bool
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .short
        return "[StaffDetail] \(action): \(staffName) (\(staffRole)) was \(wasActive ? "Active" : "Inactive") at \(df.string(from: timestamp))"
    }
}
fileprivate final class StaffDetailAudit {
    static private(set) var log: [StaffDetailAuditEvent] = []
    static func record(action: String, staff: StaffMember) {
        let event = StaffDetailAuditEvent(
            timestamp: Date(),
            action: action,
            staffName: staff.name,
            staffRole: staff.role.displayName,
            wasActive: staff.isActive
        )
        log.append(event)
        if log.count > 36 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum StaffDetailAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { StaffDetailAudit.recentSummaries(limit: limit) }
}

// --- (The rest of your file, e.g. preview and helpers, remains unchanged) ---

// A reusable button style for the action buttons in this view.
private struct FurfolioActionButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Fonts.button)
            .foregroundColor(isDestructive ? AppTheme.Colors.danger : .white)
            .padding(AppTheme.Spacing.medium)
            .frame(maxWidth: .infinity)
            .background(isDestructive ? AppTheme.Colors.danger.opacity(0.15) : AppTheme.Colors.primary)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Helper Extension

fileprivate extension String {
    var onlyDigits: String {
        filter("0123456789".contains)
    }
}

@available(iOS 18.0, *)
#Preview {
    NavigationStack {
        StaffDetailView(staffMember: .sample)
    }
}

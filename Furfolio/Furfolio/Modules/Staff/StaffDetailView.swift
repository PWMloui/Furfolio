//  StaffDetailView.swift
//  Furfolio
//
//  Created by Your Name on 6/22/25.
//
//  This view is fully modular, tokenized, and auditable, aligning with the
//  Furfolio application's architecture. It displays detailed information
//  for a staff member, integrating with the design system and data models.
//

import SwiftUI
import SwiftData

@available(iOS 18.0, *)
struct StaffDetailView: View {
    // The StaffMember model is passed into this view.
    // Using @State to allow for potential modifications within this view's lifecycle,
    // though in a real app, changes would be saved via a ViewModel or manager.
    @State var staffMember: StaffMember

    // State for showing a confirmation alert before a destructive action.
    @State private var showDeactivateAlert = false

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
        }
    }

    // MARK: - Private Subviews

    /// The main profile header with the staff member's icon, name, and role.
    private var profileHeader: some View {
        VStack(spacing: AppTheme.Spacing.small) {
            Image(systemName: staffMember.role.icon)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(AppTheme.Colors.primary)
                .padding()
                .background(AppColors.secondary.opacity(0.1))
                .clipShape(Circle())

            Text(staffMember.name)
                .font(AppTheme.Fonts.largeTitle)
                .foregroundColor(AppTheme.Colors.textPrimary)

            Text(staffMember.role.displayName)
                .font(AppTheme.Fonts.title)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Staff Profile for \(staffMember.name), role: \(staffMember.role.displayName)")
    }

    /// Interactive buttons for contacting the staff member.
    private var quickActions: some View {
        HStack(spacing: AppTheme.Spacing.large) {
            if let phone = staffMember.phone, let url = URL(string: "tel:\(phone.onlyDigits)") {
                Link(destination: url) {
                    Label("Call", systemImage: "phone.fill")
                }
                .buttonStyle(FurfolioActionButtonStyle())
            }
            if let email = staffMember.email, let url = URL(string: "mailto:\(email)") {
                Link(destination: url) {
                    Label("Email", systemImage: "envelope.fill")
                }
                .buttonStyle(FurfolioActionButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
    
    /// A grid displaying key performance indicators for the staff member.
    private var performanceStats: some View {
        // NOTE: The values here are placeholders. In a real app, this data would
        // be calculated by an analytics engine and passed into the view.
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
    
    /// A section displaying detailed employment information.
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
                }
                
                HStack {
                    Text("Date Joined")
                    Spacer()
                    Text(staffMember.dateJoined, style: .date)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }

                if let lastActive = staffMember.lastActiveAt {
                    HStack {
                        Text("Last Active")
                        Spacer()
                        Text(lastActive, style: .date)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding()
            .background(AppColors.card)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .padding(.horizontal)
        }
    }
    
    /// A section for potentially destructive actions, like deactivating the staff member.
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
        }
    }

    /// Logic to handle the deactivation of a staff member.
    private func deactivateStaffMember() {
        // In a real app, this would call a method in a ViewModel or Manager
        // that handles the business logic and saves the change.
        // For example: `StaffManager.shared.deactivate(staffMember)`
        staffMember.isActive = false
        // TODO: Log this action to the audit trail.
    }
}

/// A reusable button style for the action buttons in this view.
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

/// A helper extension from your provided files to extract digits for the "tel" URL scheme.
fileprivate extension String {
    var onlyDigits: String {
        filter("0123456789".contains)
    }
}


// MARK: - SwiftUI Preview

@available(iOS 18.0, *)
#Preview {
    // This preview uses the sample StaffMember you provided,
    // demonstrating how the view renders with realistic data.
    NavigationStack {
        StaffDetailView(staffMember: .sample)
    }
}

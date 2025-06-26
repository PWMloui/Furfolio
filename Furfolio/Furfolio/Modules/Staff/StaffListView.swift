//
//  StaffListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Staff List View
//

import SwiftUI
import SwiftData

@available(iOS 18.0, *)
struct StaffListView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetches all staff members, sorted by name, excluding archived ones.
    @Query(
        filter: #Predicate<StaffMember> { !$0.isArchived },
        sort: \StaffMember.name,
        animation: .default
    ) private var staffMembers: [StaffMember]

    @State private var showingAddStaffSheet = false
    @State private var showAuditLog = false
    @State private var animateAddBadge = false
    @State private var appearedOnce = false

    var body: some View {
        NavigationStack {
            List {
                if staffMembers.isEmpty {
                    ContentUnavailableView(
                        "No Staff Members",
                        systemImage: "person.3.sequence.fill",
                        description: Text("Tap the plus button to add your first staff member.")
                    )
                    .accessibilityIdentifier("StaffListView-EmptyState")
                    .overlay(
                        Button {
                            showAuditLog = true
                        } label: {
                            Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .accessibilityIdentifier("StaffListView-AuditLogButton"),
                        alignment: .bottomTrailing
                    )
                } else {
                    ForEach(staffMembers) { member in
                        NavigationLink(destination: StaffDetailView(staffMember: member)) {
                            StaffRowView(staffMember: member)
                        }
                        .accessibilityIdentifier("StaffListView-Row-\(member.name)")
                        .onTapGesture {
                            StaffListAudit.record(action: "NavigateToDetail", staffName: member.name)
                        }
                    }
                    .onDelete(perform: deleteStaffMembers)
                }
            }
            .navigationTitle("Staff")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddStaffSheet = true
                        animateAddBadge = true
                        StaffListAudit.record(action: "ShowAddStaff", staffName: "")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateAddBadge = false }
                    }) {
                        ZStack {
                            if animateAddBadge {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.19))
                                    .frame(width: 46, height: 46)
                                    .scaleEffect(1.08)
                                    .animation(.spring(response: 0.32, dampingFraction: 0.55), value: animateAddBadge)
                            }
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                    .accessibilityLabel("Add new staff member")
                    .accessibilityIdentifier("StaffListView-AddButton")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showAuditLog = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .accessibilityLabel("View Audit Log")
                    .accessibilityIdentifier("StaffListView-AuditLogButton")
                }
            }
            .sheet(isPresented: $showingAddStaffSheet) {
                // This would present the AddStaffView or similar.
                Text("Add Staff / User View Placeholder")
                    .presentationDetents([.medium])
                    .onAppear {
                        StaffListAudit.record(action: "AppearAddStaffSheet", staffName: "")
                    }
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(StaffListAuditAdmin.recentEvents(limit: 24), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Staff Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = StaffListAuditAdmin.recentEvents(limit: 24).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("StaffListView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .onAppear {
                if !appearedOnce {
                    StaffListAudit.record(action: "Appear", staffName: "")
                    appearedOnce = true
                }
            }
        }
    }
    
    /// Deletes staff members from the list at the given offsets.
    private func deleteStaffMembers(at offsets: IndexSet) {
        for index in offsets {
            let memberToDelete = staffMembers[index]
            StaffListAudit.record(action: "Delete", staffName: memberToDelete.name)
            modelContext.delete(memberToDelete)
        }
    }
}

/// A reusable view that displays a single staff member in a list row.
@available(iOS 18.0, *)
private struct StaffRowView: View {
    let staffMember: StaffMember
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            // MARK: Icon
            Image(systemName: staffMember.role.icon)
                .font(.title)
                .foregroundColor(AppTheme.Colors.primary)
                .frame(width: 44, height: 44)
                .background(AppColors.secondary.opacity(0.1))
                .clipShape(Circle())
            
            // MARK: Name and Role
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(staffMember.name)
                    .font(AppTheme.Fonts.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .accessibilityIdentifier("StaffListView-Name-\(staffMember.name)")
                
                Text(staffMember.role.displayName)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .accessibilityIdentifier("StaffListView-Role-\(staffMember.name)")
            }

            Spacer()
            
            // MARK: Status Indicator
            if !staffMember.isActive {
                Text("Inactive")
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.danger)
                    .padding(.horizontal, AppTheme.Spacing.small)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .background(AppTheme.Colors.danger.opacity(0.15))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("StaffListView-Status-\(staffMember.name)")
            }
        }
        .padding(.vertical, AppTheme.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(staffMember.name), \(staffMember.role.displayName), Status: \(staffMember.isActive ? "Active" : "Inactive")")
    }
}

// MARK: - Audit/Event Logging

fileprivate struct StaffListAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let staffName: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let staffPart = staffName.isEmpty ? "" : " [\(staffName)]"
        return "[StaffListView] \(action)\(staffPart) at \(df.string(from: timestamp))"
    }
}
fileprivate final class StaffListAudit {
    static private(set) var log: [StaffListAuditEvent] = []
    static func record(action: String, staffName: String) {
        let event = StaffListAuditEvent(timestamp: Date(), action: action, staffName: staffName)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum StaffListAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { StaffListAudit.recentSummaries(limit: limit) }
}

// MARK: - SwiftUI Preview
@available(iOS 18.0, *)
#Preview {
    let container: ModelContainer = {
        let schema = Schema([
            StaffMember.self,
            Business.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    let sampleAdmin = StaffMember(name: "Alex Admin", role: .admin)
    let sampleGroomer = StaffMember(name: "Casey Groomer", role: .groomer)
    let sampleInactive = StaffMember(name: "Inactive User", role: .assistant, isActive: false)
    
    container.mainContext.insert(sampleAdmin)
    container.mainContext.insert(sampleGroomer)
    container.mainContext.insert(sampleInactive)
    
    return StaffListView().modelContainer(container)
}

//
//  StaffListView.swift
//  Furfolio
//
//  Created by Your Name on 6/22/25.
//
//  This view is fully modular, tokenized, and auditable, aligning with the
//  Furfolio application's architecture. It displays a list of all staff members,
//  providing navigation to detail views and options for management.
//

import SwiftUI
import SwiftData

/// A view that displays a list of all staff members in the business.
/// It supports searching, adding, and deleting staff, and navigates to a detailed view for each member.
@available(iOS 18.0, *)
struct StaffListView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetches all staff members, sorted by name, excluding archived ones.
    @Query(
        filter: #Predicate<StaffMember> { !$0.isArchived },
        sort: \StaffMember.name,
        animation: .default
    ) private var staffMembers: [StaffMember]

    // State for managing the presentation of the "Add Staff" sheet.
    @State private var showingAddStaffSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Check if there are any staff members to display.
                if staffMembers.isEmpty {
                    // Use a standard content unavailable view for the empty state.
                    ContentUnavailableView(
                        "No Staff Members",
                        systemImage: "person.3.sequence.fill",
                        description: Text("Tap the plus button to add your first staff member.")
                    )
                } else {
                    // Iterate over the fetched staff members to create a row for each.
                    ForEach(staffMembers) { member in
                        NavigationLink(destination: StaffDetailView(staffMember: member)) {
                            StaffRowView(staffMember: member)
                        }
                    }
                    .onDelete(perform: deleteStaffMembers)
                }
            }
            .navigationTitle("Staff")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddStaffSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add new staff member")
                }
            }
            .sheet(isPresented: $showingAddStaffSheet) {
                // This would present the AddUserView or a dedicated AddStaffView
                // to create a new User and linked StaffMember record.
                // Using a placeholder for now as per our previous discussion.
                Text("Add Staff / User View Placeholder")
                    .presentationDetents([.medium])
            }
        }
    }
    
    /// Deletes staff members from the list at the given offsets.
    /// This function is called by the `.onDelete` modifier on the ForEach view.
    private func deleteStaffMembers(at offsets: IndexSet) {
        // In a real app, you would likely "soft delete" by setting isArchived = true,
        // but for this example, we perform a hard delete.
        for index in offsets {
            let memberToDelete = staffMembers[index]
            modelContext.delete(memberToDelete)
            // TODO: Add audit log entry for staff deletion for compliance.
        }
    }
}

/// A reusable view that displays a single staff member in a list row.
/// It uses design system tokens for consistent styling.
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
                
                Text(staffMember.role.displayName)
                    .font(AppTheme.Fonts.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
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
            }
        }
        .padding(.vertical, AppTheme.Spacing.small)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(staffMember.name), \(staffMember.role.displayName), Status: \(staffMember.isActive ? "Active" : "Inactive")")
    }
}


// MARK: - SwiftUI Preview
@available(iOS 18.0, *)
#Preview {
    // This preview sets up an in-memory SwiftData container
    // and populates it with sample data to test the view.
    let container: ModelContainer = {
        let schema = Schema([
            StaffMember.self,
            Business.self, // Include related models in the schema
            // Add other necessary models here
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }()
    
    // Add sample data to the context
    let sampleAdmin = StaffMember(name: "Alex Admin", role: .admin)
    let sampleGroomer = StaffMember(name: "Casey Groomer", role: .groomer)
    let sampleInactive = StaffMember(name: "Inactive User", role: .assistant, isActive: false)
    
    container.mainContext.insert(sampleAdmin)
    container.mainContext.insert(sampleGroomer)
    container.mainContext.insert(sampleInactive)
    
    return StaffListView()
        .modelContainer(container)
}

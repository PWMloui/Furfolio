import SwiftUI

/// RootNavigationView.swift
///
/// This file defines the canonical root navigation container for the Furfolio app.
/// All sidebar navigation and adaptive split view routing should be defined here,
/// ensuring a consistent and modular navigation experience across the app.

/// The `RootNavigationView` provides a unified sidebar navigation experience across the app,
/// leveraging SwiftUI's `NavigationSplitView` to display a sidebar with navigation options and a detail view.
/// This component uses modular design tokens for colors, fonts, spacing, and corner radius to ensure consistent styling.
/// It adapts intent by conditionally showing navigation items based on the user role, promoting a tailored user experience.
struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: NavigationItem? = .dashboard
    
    var body: some View {
        NavigationSplitView(selection: $selection) {
            SidebarView(selection: $selection)
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView()
            case .owners:
                OwnersView() // Placeholder for OwnersView
            case .appointments:
                AppointmentsView() // Placeholder for AppointmentsView
            case .charges:
                ChargesView() // Placeholder for ChargesView
            case .admin:
                AdminView() // Placeholder for AdminView
            case .none:
                Text("Select an item") // Placeholder when no selection
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .background(AppColors.background)
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: NavigationItem?
    
    var body: some View {
        List(selection: $selection) {
            Section(header: Text("Main")
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                NavigationLink(value: NavigationItem.dashboard) {
                    Text("Dashboard")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Dashboard")
                .accessibilityHint("Navigate to the dashboard overview")
            }
            
            Section(header: Text("Business")
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                NavigationLink(value: NavigationItem.owners) {
                    Text("Dog Owners")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Dog Owners")
                .accessibilityHint("Navigate to dog owners list")
                
                NavigationLink(value: NavigationItem.appointments) {
                    Text("Appointments")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Appointments")
                .accessibilityHint("Navigate to appointments schedule")
                
                NavigationLink(value: NavigationItem.charges) {
                    Text("Charges")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.accent)
                }
                .accessibilityLabel("Charges")
                .accessibilityHint("Navigate to charges and billing")
            }
            
            if appState.currentUserRole == .owner {
                Section(header: Text("Admin")
                            .font(AppFonts.body)
                            .accessibilityAddTraits(.isHeader)) {
                    NavigationLink(value: NavigationItem.admin) {
                        Text("Admin")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .accessibilityLabel("Admin")
                    .accessibilityHint("Navigate to administrative tools")
                }
            }
        }
        .listRowBackground(AppColors.card)
        .background(AppColors.background)
        .cornerRadius(BorderRadius.medium)
        .navigationTitle("Furfolio")
        .font(AppFonts.body)
        .accessibilityLabel("Furfolio Navigation")
        .accessibilityElement(children: .contain)
    }
}

enum NavigationItem: Hashable {
    case dashboard, owners, appointments, charges, admin
}

// MARK: - Placeholder Views for Detail

struct OwnersView: View {
    var body: some View {
        Text("Owners View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
    }
}

struct AppointmentsView: View {
    var body: some View {
        Text("Appointments View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
    }
}

struct ChargesView: View {
    var body: some View {
        Text("Charges View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
    }
}

struct AdminView: View {
    var body: some View {
        Text("Admin View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
    }
}

// MARK: - Previews

struct RootNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RootNavigationView()
                .environmentObject(AppState())
                .preferredColorScheme(.light)
            
            RootNavigationView()
                .environmentObject(AppState())
                .preferredColorScheme(.dark)
        }
    }
}

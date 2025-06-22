import SwiftUI

// MARK: - RootNavigationView (Unified Sidebar Navigation, Modular Token Styling)

/// The `RootNavigationView` provides a unified sidebar navigation experience across the app,
/// leveraging SwiftUI's `NavigationSplitView` to display a sidebar with navigation options and a detail view.
/// This component uses modular design tokens for colors, fonts, spacing, and corner radius to ensure consistent styling.
/// It adapts intent by conditionally showing navigation items based on the user role, promoting a tailored user experience.
struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DashboardView()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            NavigationLink("Dashboard", value: NavigationItem.dashboard)
                .font(AppFonts.body)
                .accessibilityLabel("Dashboard")
                .foregroundColor(AppColors.accent)
                .padding(.vertical, AppSpacing.medium)
            NavigationLink("Dog Owners", value: NavigationItem.owners)
                .font(AppFonts.body)
                .accessibilityLabel("Dog Owners")
                .foregroundColor(AppColors.accent)
                .padding(.vertical, AppSpacing.medium)
            NavigationLink("Appointments", value: NavigationItem.appointments)
                .font(AppFonts.body)
                .accessibilityLabel("Appointments")
                .foregroundColor(AppColors.accent)
                .padding(.vertical, AppSpacing.medium)
            NavigationLink("Charges", value: NavigationItem.charges)
                .font(AppFonts.body)
                .accessibilityLabel("Charges")
                .foregroundColor(AppColors.accent)
                .padding(.vertical, AppSpacing.medium)
            if appState.currentUserRole == .owner {
                NavigationLink("Admin", value: NavigationItem.admin)
                    .font(AppFonts.body)
                    .accessibilityLabel("Admin")
                    .foregroundColor(AppColors.accent)
                    .padding(.vertical, AppSpacing.medium)
            }
        }
        .listRowBackground(AppColors.card)
        .background(AppColors.background)
        .cornerRadius(BorderRadius.medium)
        .navigationTitle("Furfolio")
        .font(AppFonts.headline)
        .accessibilityLabel("Furfolio Navigation")
    }
}

enum NavigationItem: Hashable {
    case dashboard, owners, appointments, charges, admin
}

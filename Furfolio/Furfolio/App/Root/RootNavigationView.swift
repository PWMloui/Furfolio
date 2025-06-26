import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol RootNavigationAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullRootNavigationAnalyticsLogger: RootNavigationAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - RootNavigationView (Audit, Token, Accessible, Trust Center–Ready)

struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: NavigationItem? = .dashboard

    // Analytics logger (swap for QA/Trust Center/print as needed)
    static var analyticsLogger: RootNavigationAnalyticsLogger = NullRootNavigationAnalyticsLogger()

    var body: some View {
        NavigationSplitView(selection: $selection) {
            SidebarView(selection: $selection)
                .onAppear {
                    Self.analyticsLogger.log(event: "sidebar_appear", info: appState.currentUserRole.description)
                }
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView()
                    .onAppear { Self.analyticsLogger.log(event: "dashboard_view_appear", info: nil) }
            case .owners:
                OwnersView()
                    .onAppear { Self.analyticsLogger.log(event: "owners_view_appear", info: nil) }
            case .appointments:
                AppointmentsView()
                    .onAppear { Self.analyticsLogger.log(event: "appointments_view_appear", info: nil) }
            case .charges:
                ChargesView()
                    .onAppear { Self.analyticsLogger.log(event: "charges_view_appear", info: nil) }
            case .admin:
                AdminView()
                    .onAppear { Self.analyticsLogger.log(event: "admin_view_appear", info: nil) }
            case .none:
                Text("Select an item")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .background(AppColors.background)
                    .accessibilityLabel("No item selected")
                    .onAppear { Self.analyticsLogger.log(event: "no_selection", info: nil) }
            }
        }
        .accessibilityElement(children: .contain)
        .navigationTitle("Furfolio Navigation Root")
    }
}

// MARK: - SidebarView (Audit, Accessible, Trust Center–Ready)

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: NavigationItem?

    var body: some View {
        List(selection: $selection) {
            Section(header: Text("Main")
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                navLink(.dashboard, label: "Dashboard", hint: "Navigate to the dashboard overview")
            }

            Section(header: Text("Business")
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                navLink(.owners, label: "Dog Owners", hint: "Navigate to dog owners list")
                navLink(.appointments, label: "Appointments", hint: "Navigate to appointments schedule")
                navLink(.charges, label: "Charges", hint: "Navigate to charges and billing")
            }

            if appState.currentUserRole == .owner {
                Section(header: Text("Admin")
                            .font(AppFonts.body)
                            .accessibilityAddTraits(.isHeader)) {
                    navLink(.admin, label: "Admin", hint: "Navigate to administrative tools", isSensitive: true)
                }
            }
        }
        .listRowBackground(AppColors.card)
        .background(AppColors.background)
        .cornerRadius(BorderRadius.medium)
        .navigationTitle("Furfolio")
        .font(AppFonts.body)
        .accessibilityLabel("Furfolio Navigation Sidebar")
        .accessibilityElement(children: .contain)
    }

    /// Generates a standardized, audit-logged NavigationLink for a sidebar item.
    private func navLink(
        _ item: NavigationItem,
        label: String,
        hint: String,
        isSensitive: Bool = false
    ) -> some View {
        NavigationLink(value: item) {
            Text(label)
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint)
        .onTapGesture {
            RootNavigationView.analyticsLogger.log(
                event: isSensitive ? "admin_nav_tap" : "\(item)_nav_tap",
                info: appState.currentUserRole.description
            )
            // Trust Center/Audit: Here you can add more permission/audit checks as needed.
        }
    }
}

// MARK: - NavigationItem Enum (Audit, Role Expandable)

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
            .accessibilityLabel("Owners View Placeholder")
    }
}

struct AppointmentsView: View {
    var body: some View {
        Text("Appointments View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel("Appointments View Placeholder")
    }
}

struct ChargesView: View {
    var body: some View {
        Text("Charges View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel("Charges View Placeholder")
    }
}

struct AdminView: View {
    var body: some View {
        Text("Admin View - To be implemented")
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel("Admin View Placeholder")
    }
}

// MARK: - Previews (Analytics-Injected, Multi-Role)

struct RootNavigationView_Previews: PreviewProvider {
    struct SpyLogger: RootNavigationAnalyticsLogger {
        func log(event: String, info: String?) {
            print("[RootNavAnalytics] \(event): \(info ?? "")")
        }
    }
    static var previews: some View {
        RootNavigationView.analyticsLogger = SpyLogger()
        return Group {
            RootNavigationView()
                .environmentObject(AppState())
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            RootNavigationView()
                .environmentObject({
                    let s = AppState()
                    s.currentUserRole = .owner
                    return s
                }())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode (Owner)")
        }
    }
}

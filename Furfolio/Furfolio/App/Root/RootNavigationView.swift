import SwiftUI

// MARK: - Audit Context (Set on login/session)
public struct RootNavigationAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "RootNavigationView"
}

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Escalation)

public protocol RootNavigationAnalyticsLogger {
    var testMode: Bool { get }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func fetchRecentEvents(maxCount: Int) async -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)]
}

/// Default no-operation analytics logger.
public struct NullRootNavigationAnalyticsLogger: RootNavigationAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(maxCount: Int) async -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] { [] }
}

/// In-memory analytics logger for diagnostics/testMode, with full context and escalation.
public final class InMemoryRootNavigationAnalyticsLogger: RootNavigationAnalyticsLogger {
    public private(set) var testMode: Bool
    private let maxEventsStored = 20
    private var events: [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] = []
    private let queue = DispatchQueue(label: "InMemoryRootNavigationAnalyticsLogger.queue", attributes: .concurrent)

    public init(testMode: Bool = false) { self.testMode = testMode }

    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let logEntry = (event: event, info: info, role: role, staffID: staffID, context: context, escalate: escalate, date: Date())
        queue.async(flags: .barrier) {
            if self.events.count >= self.maxEventsStored {
                self.events.removeFirst()
            }
            self.events.append(logEntry)
        }
        if testMode {
            print("[RootNavAnalytics] \(event): \(info ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
    }
    public func fetchRecentEvents(maxCount: Int) async -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] {
        await withCheckedContinuation { continuation in
            queue.async {
                let slice = self.events.suffix(maxCount)
                continuation.resume(returning: Array(slice))
            }
        }
    }
}

// MARK: - RootNavigationView (Audit, Token, Accessible, Trust Center–Ready)

struct RootNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: NavigationItem? = .dashboard

    /// Shared analytics logger instance (DI for QA/Trust Center/admin as needed).
    static var analyticsLogger: RootNavigationAnalyticsLogger = NullRootNavigationAnalyticsLogger()

    // Helper to provide audit context
    private func logNavEvent(_ event: String, info: String?, escalate: Bool = false) {
        Task {
            await Self.analyticsLogger.log(
                event: event,
                info: info,
                role: RootNavigationAuditContext.role,
                staffID: RootNavigationAuditContext.staffID,
                context: RootNavigationAuditContext.context,
                escalate: escalate
            )
        }
    }

    var body: some View {
        NavigationSplitView(selection: $selection) {
            SidebarView(selection: $selection)
                .onAppear {
                    logNavEvent(
                        NSLocalizedString("sidebar_appear", comment: "Sidebar appeared event"),
                        info: appState.currentUserRole.description
                    )
                }
        } detail: {
            switch selection {
            case .dashboard:
                DashboardView()
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("dashboard_view_appear", comment: "Dashboard view appeared event"),
                            info: nil
                        )
                    }
            case .owners:
                OwnersView()
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("owners_view_appear", comment: "Owners view appeared event"),
                            info: nil
                        )
                    }
            case .appointments:
                AppointmentsView()
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("appointments_view_appear", comment: "Appointments view appeared event"),
                            info: nil
                        )
                    }
            case .charges:
                ChargesView()
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("charges_view_appear", comment: "Charges view appeared event"),
                            info: nil
                        )
                    }
            case .admin:
                AdminView()
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("admin_view_appear", comment: "Admin view appeared event"),
                            info: nil,
                            escalate: true // admin view access is always escalated for audit/trust center
                        )
                    }
            case .none:
                Text(NSLocalizedString("select_an_item", comment: "Prompt when no navigation item selected"))
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .background(AppColors.background)
                    .accessibilityLabel(NSLocalizedString("no_item_selected", comment: "Accessibility label for no selection"))
                    .onAppear {
                        logNavEvent(
                            NSLocalizedString("no_selection", comment: "No navigation selection event"),
                            info: nil
                        )
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .navigationTitle(NSLocalizedString("furfolio_navigation_root_title", comment: "Navigation root title"))
    }

    /// Public API to retrieve last N analytics events for diagnostics/admin/trust center UI.
    public static func fetchLastAnalyticsEvents(_ maxCount: Int = 20) async -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] {
        await analyticsLogger.fetchRecentEvents(maxCount: maxCount)
    }
}

// MARK: - SidebarView (Audit, Accessible, Trust Center–Ready)

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selection: NavigationItem?

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
            Task {
                await RootNavigationView.analyticsLogger.log(
                    event: isSensitive
                        ? NSLocalizedString("admin_nav_tap", comment: "Admin navigation tap event")
                        : NSLocalizedString("\(item)_nav_tap", comment: "Navigation tap event for item"),
                    info: appState.currentUserRole.description,
                    role: RootNavigationAuditContext.role,
                    staffID: RootNavigationAuditContext.staffID,
                    context: RootNavigationAuditContext.context,
                    escalate: isSensitive // escalate for admin nav
                )
            }
        }
    }

    var body: some View {
        List(selection: $selection) {
            Section(header: Text(NSLocalizedString("main_section_header", comment: "Main section header"))
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                navLink(.dashboard, label: NSLocalizedString("dashboard_label", comment: "Dashboard label"), hint: NSLocalizedString("dashboard_hint", comment: "Dashboard navigation hint"))
            }
            Section(header: Text(NSLocalizedString("business_section_header", comment: "Business section header"))
                        .font(AppFonts.body)
                        .accessibilityAddTraits(.isHeader)) {
                navLink(.owners, label: NSLocalizedString("dog_owners_label", comment: "Dog Owners label"), hint: NSLocalizedString("dog_owners_hint", comment: "Dog Owners navigation hint"))
                navLink(.appointments, label: NSLocalizedString("appointments_label", comment: "Appointments label"), hint: NSLocalizedString("appointments_hint", comment: "Appointments navigation hint"))
                navLink(.charges, label: NSLocalizedString("charges_label", comment: "Charges label"), hint: NSLocalizedString("charges_hint", comment: "Charges navigation hint"))
            }
            if appState.currentUserRole == .owner {
                Section(header: Text(NSLocalizedString("admin_section_header", comment: "Admin section header"))
                            .font(AppFonts.body)
                            .accessibilityAddTraits(.isHeader)) {
                    navLink(.admin, label: NSLocalizedString("admin_label", comment: "Admin label"), hint: NSLocalizedString("admin_hint", comment: "Admin navigation hint"), isSensitive: true)
                }
            }
        }
        .listRowBackground(AppColors.card)
        .background(AppColors.background)
        .cornerRadius(BorderRadius.medium)
        .navigationTitle(NSLocalizedString("furfolio_navigation_sidebar_title", comment: "Sidebar navigation title"))
        .font(AppFonts.body)
        .accessibilityLabel(NSLocalizedString("furfolio_navigation_sidebar_accessibility_label", comment: "Sidebar accessibility label"))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - NavigationItem Enum

enum NavigationItem: Hashable {
    case dashboard, owners, appointments, charges, admin
}

// MARK: - Placeholder Detail Views

struct OwnersView: View {
    var body: some View {
        Text(NSLocalizedString("owners_view_placeholder", comment: "Owners View placeholder text"))
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel(NSLocalizedString("owners_view_accessibility_label", comment: "Owners View accessibility label"))
    }
}

struct AppointmentsView: View {
    var body: some View {
        Text(NSLocalizedString("appointments_view_placeholder", comment: "Appointments View placeholder text"))
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel(NSLocalizedString("appointments_view_accessibility_label", comment: "Appointments View accessibility label"))
    }
}

struct ChargesView: View {
    var body: some View {
        Text(NSLocalizedString("charges_view_placeholder", comment: "Charges View placeholder text"))
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel(NSLocalizedString("charges_view_accessibility_label", comment: "Charges View accessibility label"))
    }
}

struct AdminView: View {
    var body: some View {
        Text(NSLocalizedString("admin_view_placeholder", comment: "Admin View placeholder text"))
            .font(AppFonts.body)
            .foregroundColor(AppColors.accent)
            .background(AppColors.background)
            .accessibilityLabel(NSLocalizedString("admin_view_accessibility_label", comment: "Admin View accessibility label"))
    }
}

// MARK: - Previews (Analytics-Injected, Multi-Role)

struct RootNavigationView_Previews: PreviewProvider {
    struct SpyLogger: RootNavigationAnalyticsLogger {
        let testMode: Bool = true
        func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[RootNavAnalytics] \(event): \(info ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
        func fetchRecentEvents(maxCount: Int) async -> [(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool, date: Date)] { [] }
    }
    static var previews: some View {
        RootNavigationView.analyticsLogger = SpyLogger()
        RootNavigationAuditContext.role = "Owner"
        RootNavigationAuditContext.staffID = "staff001"
        RootNavigationAuditContext.context = "RootNavigationPreview"
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

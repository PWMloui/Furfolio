//
//  AppCoordinator.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import SwiftUI
import Combine

@MainActor
class AppCoordinator: ObservableObject {
    enum Route: Equatable {
        case login
        case dashboard
        case groomingHistory(ownerID: UUID)
        case metricsDashboard
        case appointment(id: UUID)
    }
    
    @Published var currentRoute: Route = .login
    @Published var path: [Route] = []
    
    /// Returns the appropriate root view using a NavigationStack.
    func rootView() -> some View {
        NavigationStack(path: $path) {
            Group {
                if AppState.shared.isAuthenticated {
                    DashboardView()
                        .environmentObject(self)
                } else {
                    LoginView()
                        .environmentObject(self)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .login:
                    LoginView().environmentObject(self)
                case .dashboard:
                    DashboardView().environmentObject(self)
                case .metricsDashboard:
                    MetricsDashboardView().environmentObject(self)
                case .groomingHistory(let ownerID):
                    GroomingHistoryView(ownerID: ownerID).environmentObject(self)
                case .appointment(let id):
                    AppointmentDetailView(appointmentID: id)
                        .environmentObject(self)
                }
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: AppState.shared.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                resetNavigation()
                navigate(to: .dashboard)
            } else {
                path = [.login]
            }
        }
    }
    
    /// Handles deep-links of form furfolio://appointment/{UUID}
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "furfolio" else { return }
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count == 2, pathComponents[0] == "appointment" else { return }
        if let uuid = UUID(uuidString: pathComponents[1]) {
            navigate(to: .appointment(id: uuid))
        }
    }
    
    /// Programmatic navigation helper.
    func navigate(to route: Route) {
        path.append(route)
    }
    
    /// Resets the navigation path.
    func resetNavigation() {
        path = []
    }
}

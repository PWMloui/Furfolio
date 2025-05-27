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
        case appointment(id: UUID)
    }
    
    @Published var currentRoute: Route = .login
    
    /// Returns the appropriate root view based on authentication state.
    func rootView() -> some View {
        Group {
            if AppState.shared.isAuthenticated {
                DashboardView(owners: [])
            } else {
                LoginView()
            }
        }
        .environmentObject(self)
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
        currentRoute = route
    }
}

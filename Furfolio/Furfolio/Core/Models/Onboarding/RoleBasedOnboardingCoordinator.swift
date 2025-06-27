//
//  RoleBasedOnboardingCoordinator.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

struct RoleBasedOnboardingCoordinator: View {
    let role: OnboardingRole
    let userId: String
    @State private var completed: Bool = false

    var body: some View {
        if completed {
            MainAppView() // Replace with your real root view
        } else {
            switch role {
            case .manager:
                ManagerOnboardingFlow {
                    OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                    completed = true
                }
            case .staff:
                StaffOnboardingFlow {
                    OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                    completed = true
                }
            case .receptionist:
                ReceptionistOnboardingFlow {
                    OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                    completed = true
                }
            }
        }
    }
}

//
//  OnboardingStep.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI

/// Defines each step in the onboarding flow with associated metadata
enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case dataImport
    case tutorial
    case faq
    case permissions
    case completion

    var id: Int { self.rawValue }

    /// User-facing title
    var title: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome"
        case .dataImport: return "Import Data"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .permissions: return "Permissions"
        case .completion: return "All Set"
        }
    }

    /// Description used in step indicators, coordinator views, or tooltips
    var description: LocalizedStringKey {
        switch self {
        case .welcome: return "Let’s get started with Furfolio!"
        case .dataImport: return "Load sample data or import your own"
        case .tutorial: return "Learn how to navigate and use the app"
        case .faq: return "Answers to common questions"
        case .permissions: return "Grant required app permissions"
        case .completion: return "Start using Furfolio"
        }
    }

    /// SF Symbol icon for onboarding step indication
    var iconName: String {
        switch self {
        case .welcome: return "hand.wave"
        case .dataImport: return "tray.and.arrow.down.fill"
        case .tutorial: return "rectangle.stack.badge.play"
        case .faq: return "questionmark.circle"
        case .permissions: return "bell.badge"
        case .completion: return "checkmark.seal.fill"
        }
    }

    /// Optional route identifier if navigation is route-driven
    var routeKey: String {
        switch self {
        case .welcome: return "onboarding.welcome"
        case .dataImport: return "onboarding.import"
        case .tutorial: return "onboarding.tutorial"
        case .faq: return "onboarding.faq"
        case .permissions: return "onboarding.permissions"
        case .completion: return "onboarding.completion"
        }
    }
}

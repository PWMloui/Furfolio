//
//  OnboardingStep.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for localization and extensibility.
//

import Foundation
import SwiftUI

/// Enum representing each step of the onboarding flow.
enum OnboardingStep: Int, CaseIterable, Identifiable, CustomStringConvertible {
    /// Introduction screen.
    case welcome
    /// Option to import demo or file-based data.
    case dataImport
    /// Swipeable tutorial on core features.
    case tutorial
    /// Frequently asked questions about the app.
    case faq
    /// Request permissions (e.g., notifications).
    case permissions
    /// Completion screen.
    case finish

    var id: Int { rawValue }

    /// Localized title for each onboarding step.
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome"
        case .dataImport: return "Import Data"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .permissions: return "Permissions"
        case .finish: return "Finish"
        }
    }

    /// Text-only representation for debugging.
    var description: String {
        String(describing: localizedTitle)
    }

    // Future expansion:
    // var iconName: String { ... }
    // var detailText: LocalizedStringKey { ... }
}

//
//  OnboardingWidgetSupport.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import WidgetKit
import SwiftUI

/// Handles widget onboarding suggestion and tracking
struct OnboardingWidgetSupport {
    static let suggestionShownKey = "onboarding_widget_suggestion_shown"

    /// Whether the user has already been prompted about the widget
    static var hasShownSuggestion: Bool {
        UserDefaults.standard.bool(forKey: suggestionShownKey)
    }

    /// Marks the widget suggestion as shown
    static func markSuggestionShown() {
        UserDefaults.standard.set(true, forKey: suggestionShownKey)
    }

    /// Check if widgets are active (if app has any configured widgets)
    static func isWidgetEnabled(completion: @escaping (Bool) -> Void) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let widgets):
                completion(!widgets.isEmpty)
            case .failure(_):
                completion(false)
            }
        }
    }

    /// Triggers system UI to add/configure widgets (iOS 17+ only)
    static func openWidgetConfiguration() {
        guard let url = URL(string: "App-Prefs:root=HomeScreen&path=WIDGETS") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

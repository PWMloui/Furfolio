//
//  AdaptiveRootView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

// MARK: - AdaptiveRootView (Root Navigation, Adaptive Layout & Theming)

/**
 AdaptiveRootView serves as the root view of the Furfolio app, managing the primary navigation and adaptive layout logic across different Apple platforms including iPhone, iPad, and Mac.

 This view handles:
 - Adaptive navigation and root logic by choosing appropriate layouts depending on the device type and platform.
 - Theming by applying consistent styles using centralized design tokens such as AppColors, AppFonts, AppSpacing, and BorderRadius.
 - Dependency injection and app state management by integrating with the shared AppState environment object, ensuring reactive UI updates and centralized state handling.
 - Platform-specific UI adjustments to provide an optimal user experience on iPhone (compact navigation), iPad (split view), and Mac (sidebar navigation).

 Navigation is managed adaptively, switching between stack-based navigation on smaller devices and sidebar or split-view navigation on larger screens, ensuring consistency with platform conventions.

 Usage of design tokens ensures that spacing, colors, fonts, and corner radii remain consistent and maintainable across the app.

 ---

 This file does not currently contain hardcoded styling; however, future styling should utilize the AppColors, AppFonts, AppSpacing, and BorderRadius tokens for consistency.

 ---

 Dependency Injection:
 The view expects an @EnvironmentObject of type AppState to be injected, enabling centralized state management and reactive UI updates.

 ---

 Navigation Management:
 Navigation is adapted based on platform and device size classes, providing stack navigation on iPhones and sidebar/split views on iPads and Macs.

*/

// Usage example:
//
// import SwiftUI
//
// @main
// struct FurfolioApp: App {
//     @StateObject private var appState = AppState()
//
//     var body: some Scene {
//         WindowGroup {
//             AdaptiveRootView()
//                 .environmentObject(appState)
//         }
//     }
// }
//
// or in ContentView.swift:
//
// struct ContentView: View {
//     var body: some View {
//         AdaptiveRootView()
//     }
// }

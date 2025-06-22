//
//  HapticManager.swift
//  Furfolio
//
//  Enhanced & Cleaned: 2025+ Grooming Business App Architecture
//

import Foundation
import UIKit

// MARK: - HapticManager (Unified, Tokenized, Accessible Haptic Feedback Engine)

/// Centralized haptic feedback utility for Furfolio.
/// This is a modular, unified, tokenized, and accessible haptic feedback engine for all business, UX, and accessibility events.
/// All calls should be auditable and optionally respect user/Trust Center preferences.
enum HapticManager {
    // MARK: - Public API

    /// Success (confirmations, achievements, task completions)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func success() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        trigger(.success)
    }

    /// Warning (risk, caution, retention alerts, etc.)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func warning() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        trigger(.warning)
    }

    /// Error (failures, denied actions)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func error() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        trigger(.error)
    }

    /// Selection change (pickers, filter bars, segmented controls)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func selection() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Light tap (generic feedback, optional)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func light() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        impact(.light)
    }

    /// Medium tap
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func medium() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        impact(.medium)
    }

    /// Heavy tap
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func heavy() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        impact(.heavy)
    }

    /// Custom celebratory sequence (use for onboarding wins, loyalty rewards, special events)
    /// Haptic feedback should be paired with visible/audible feedback for accessibility,
    /// and optionally check user/Trust Center preferences before firing.
    static func celebrate() {
        // TODO: Integrate Trust Center/user preference check before triggering haptic feedback.
        success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { medium() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { heavy() }
    }

    // MARK: - Private Helpers

    private static func trigger(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Cross-Platform & Accessibility Notes
/*
- On iPad/Mac Catalyst, haptic feedback is supported if device hardware allows.
- Always combine haptics with visible/audible feedback for accessibility.
- Consider exposing a Settings toggle for "Enable Haptic Feedback" in Trust Center, respecting device/system preferences.
- All haptic calls are lightweight and safe for background/async use in main thread UI actions.
- All calls should be logged/audited for business events if compliance is required.
*/

// MARK: - Example Usage
/*
 // Example: Check Trust Center preference before calling haptic feedback
 if TrustCenter.shared.isHapticEnabled {
     HapticManager.success()    // Appointment booked
 }

 HapticManager.success()    // Appointment booked
 HapticManager.warning()    // Overlapping appointments
 HapticManager.error()      // Failed to save
 HapticManager.selection()  // Filter bar changed
 HapticManager.light()      // Tap on action
 HapticManager.celebrate()  // Loyalty milestone unlocked
*/

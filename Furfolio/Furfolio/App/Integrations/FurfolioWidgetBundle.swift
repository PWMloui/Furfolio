//
//  FurfolioWidgetBundle.swift
//  Furfolio
//
//  Enhanced for modularity, role-awareness, analytics, diagnostics, scalable widget architecture, and Trust Center compliance.
//  Updated: 2025-06-30
//

import WidgetKit
import SwiftUI

@main
struct FurfolioWidgetBundle: WidgetBundle {
    /// Optional analytics/audit logger (e.g., Trust Center or admin audit system)
    static var auditLogger: ((_ event: String, _ widget: String, _ role: String?, _ context: String?) -> Void)? = nil
    /// If true, disables real audit/analytics events (logs to console only).
    static var testMode: Bool = false
    /// Current user/staff role for role-based widget filtering.
    static var currentRole: String? = nil
    /// Optional context (business unit, environment, etc)
    static var context: String? = nil

    /// Holds dynamically registered widgets for extensibility.
    static private var customWidgets: [() -> Widget] = []

    /// API for maintainers/3rd party: Register a custom widget for future bundles.
    static func registerWidget(_ widget: @escaping () -> Widget) {
        customWidgets.append(widget)
        logEvent("register_dynamic_widget", "\(type(of: widget()))")
    }

    /// Logs widget registration and usage for analytics/audit compliance.
    static func logEvent(_ event: String, _ widget: String) {
        let localizedEvent = NSLocalizedString(event, comment: "Widget audit/analytics event")
        if testMode {
            print("[FurfolioWidgetBundle][TESTMODE] \(localizedEvent): \(widget) [role: \(currentRole ?? "n/a")] [ctx: \(context ?? "n/a")]")
        } else {
            auditLogger?(localizedEvent, widget, currentRole, context)
        }
    }

    var body: some Widget {
        // Role-aware registration (expand as needed for more granular control)
        let role = Self.currentRole

        // --- Core Operations Widgets (visible to all roles) ---
        Self.logEvent("register", "AppointmentLiveActivityWidget")
        AppointmentLiveActivityWidget()
        Self.logEvent("register", "GroomingHistoryWidget")
        GroomingHistoryWidget()
        Self.logEvent("register", "OwnerSummaryWidget")
        OwnerSummaryWidget()

        // --- Business Dashboard & Metrics Widgets (owner/admin only if desired) ---
        if role == nil || role == "owner" || role == "admin" {
            Self.logEvent("register", "FurfolioDashboardWidget")
            FurfolioDashboardWidget()
            Self.logEvent("register", "RevenueTrendsWidget")
            RevenueTrendsWidget()
        }
        // Loyalty always visible
        Self.logEvent("register", "LoyaltyBadgeWidget")
        LoyaltyBadgeWidget()

        // --- Productivity & Engagement Widgets (e.g., staff/admin/owner) ---
        Self.logEvent("register", "QuickNoteWidget")
        QuickNoteWidget()

        // --- Custom & Experimental Widgets ---
        Self.logEvent("register", "CustomBusinessWidget")
        CustomBusinessWidget()

        // --- Register any custom widgets added at runtime ---
        ForEach(Self.customWidgets.indices, id: \.self) { i in
            Self.logEvent("register_dynamic", "CustomWidget_\(i)")
            Self.customWidgets[i]()
        }

        // --- Diagnostics/Admin Widgets (visible in test/admin) ---
        if Self.testMode || role == "admin" {
            // Self.logEvent("register", "DiagnosticsWidget")
            // DiagnosticsWidget()
        }

        // All widget registration events are now auditable for Trust Center/business analytics
    }
}

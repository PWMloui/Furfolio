//
//  FurfolioWidgetBundle.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced for modularity, analytics, diagnostics, and scalable widget architecture.
//

import WidgetKit
import SwiftUI

/// The main WidgetBundle for Furfolio.
/// Registers all widgets related to business operations, dashboard, and owner insights.
/// Add new widgets to this bundle to keep everything organized and unified.
/// All registration is grouped by function for clarity and maintainability.
///
/// TODO:
/// - Add future widgets to their relevant section and document purpose.
/// - Implement widget analytics/audit logging via Trust Center for business compliance.
/// - Consider dynamic/automated widget registration for future scalability.
@main
struct FurfolioWidgetBundle: WidgetBundle {
    var body: some Widget {
        // MARK: - Core Operations Widgets
        AppointmentLiveActivityWidget()
        GroomingHistoryWidget()
        OwnerSummaryWidget()

        // MARK: - Business Dashboard & Metrics Widgets
        FurfolioDashboardWidget()
        RevenueTrendsWidget()
        LoyaltyBadgeWidget()

        // MARK: - Productivity & Engagement Widgets
        QuickNoteWidget()

        // MARK: - Custom & Experimental Widgets
        CustomBusinessWidget()

        // MARK: - Diagnostics/Admin Widgets (Stub; expand as needed)
        // DiagnosticsWidget() // Example: For admin/troubleshooting status, future drop-in

        // Widget registration is auditable for Trust Center/business analytics
        // TODO: Log widget registration events via Trust Center logger if required
    }
}

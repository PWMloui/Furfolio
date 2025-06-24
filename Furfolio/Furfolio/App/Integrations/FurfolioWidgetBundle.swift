//
//  FurfolioWidgetBundle.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for modular, scalable, and unified widget architecture.
//

import WidgetKit
import SwiftUI

/// The main WidgetBundle for Furfolio.
/// Registers all widgets related to business operations, dashboard, and owner insights.
/// Add new widgets to this bundle to keep everything organized and unified.
@main
struct FurfolioWidgetBundle: WidgetBundle {
    var body: some Widget {
        AppointmentLiveActivityWidget()
         FurfolioDashboardWidget()
         OwnerSummaryWidget()
         QuickNoteWidget()
         RevenueTrendsWidget()
         LoyaltyBadgeWidget()
         GroomingHistoryWidget()
         CustomBusinessWidget()
    }
}

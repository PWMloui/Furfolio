//
//  FurfolioWidgetBundle.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import WidgetKit
import SwiftUI

@main
struct FurfolioWidgetBundle: WidgetBundle {
    var body: some Widget {
        AppointmentLiveActivityWidget()
        // Add more widgets here as you build them, e.g.:
        // FurfolioDashboardWidget()
        // OwnerSummaryWidget()
        // QuickNoteWidget()
    }
}

//
//  UtilizationReportView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os

struct UtilizationReportView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "UtilizationReportView")
    @Query(sort: \SessionLog.startDate, order: .forward) private var sessionLogs: [SessionLog]
    
    // Compute total billable time in seconds
    private var totalBillableSeconds: TimeInterval {
        sessionLogs.reduce(0) { $0 + ($1.endDate?.timeIntervalSince($1.startDate) ?? 0) }
    }
    
    // 8 hours in seconds
    private let workdaySeconds: TimeInterval = 8 * 60 * 60
    
    private var utilizationPercentage: Double {
        guard workdaySeconds > 0 else { return 0 }
        return min(totalBillableSeconds / workdaySeconds, 1.0)
    }
    
    private var percentageLabel: String {
        let percent = Int(utilizationPercentage * 100)
        return "\(percent)%"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Utilization Report")
                .font(AppTheme.header)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.primaryText)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Billable Utilization")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                ProgressView(value: utilizationPercentage) {
                    Text(percentageLabel)
                        .font(AppTheme.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.primaryText)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accent))
                Text(String(format: "Total billable: %.2f hours", totalBillableSeconds / 3600))
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.secondaryText)
            }
            
            Text("Sessions")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
            
            List(sessionLogs) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.startDate, style: .time)
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                        if let end = session.endDate {
                            Text("to \(end, style: .time)")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                    }
                    Spacer()
                    if let end = session.endDate {
                        let duration = end.timeIntervalSince(session.startDate)
                        Text(String(format: "%.2f h", duration / 3600))
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.primaryText)
                    } else {
                        Text("-")
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                .onAppear {
                    logger.log("Displaying session \(session.startDate) – \(String(describing: session.endDate))")
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .navigationTitle("Utilization")
        .onAppear {
            logger.log("UtilizationReportView appeared; sessions count: \(sessionLogs.count), utilization: \(utilizationPercentage)")
        }
    }
}

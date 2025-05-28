//
//  UtilizationReportView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData

struct UtilizationReportView: View {
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
                .font(.largeTitle)
                .bold()
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Billable Utilization")
                    .font(.headline)
                ProgressView(value: utilizationPercentage) {
                    Text(percentageLabel)
                        .font(.subheadline)
                        .bold()
                }
                .progressViewStyle(LinearProgressViewStyle())
                Text(String(format: "Total billable: %.2f hours", totalBillableSeconds / 3600))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Sessions")
                .font(.headline)
            
            List(sessionLogs) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.startDate, style: .time)
                        if let end = session.endDate {
                            Text("to \(end, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if let end = session.endDate {
                        let duration = end.timeIntervalSince(session.startDate)
                        Text(String(format: "%.2f h", duration / 3600))
                            .font(.body)
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding()
        .navigationTitle("Utilization")
    }
}

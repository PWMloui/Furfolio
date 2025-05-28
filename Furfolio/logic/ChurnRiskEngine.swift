//
//  ChurnRiskEngine.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation

@MainActor
enum ChurnRiskEngine {
    /// Runs synchronous work off the main thread and returns its result.
    private static func runAsync<T>(
        _ work: @Sendable @escaping () -> T
    ) async -> T {
        await Task.detached { work() }.value
    }
    
    static func rfm(in appointments: [Appointment], charges: [Charge], referenceDate: Date = Date()) -> (recency: Double, frequency: Double, monetary: Double) {
        let largeRecencyDefault = 365.0 * 10 // 10 years in days
        
        let recency: Double
        if let mostRecent = appointments.map({ $0.date }).max() {
            recency = referenceDate.timeIntervalSince(mostRecent) / (60 * 60 * 24)
        } else {
            recency = largeRecencyDefault
        }
        
        let frequency = Double(appointments.count)
        let monetary = charges.reduce(0.0) { $0 + $1.amount }
        
        return (recency, frequency, monetary)
    }
    
    static func churnRiskScore(in appointments: [Appointment], charges: [Charge]) -> Double {
        let (recency, frequency, monetary) = rfm(in: appointments, charges: charges)
        
        // Normalize recency: cap at 90 days, then divide by 90 so range is 0..1
        let recencyNorm = min(recency, 90) / 90.0
        
        // Normalize frequency: invert so more visits means lower risk
        let frequencyNorm = 1.0 / (frequency + 1.0)
        
        // Normalize monetary: invert so more spending means lower risk
        let monetaryNorm = 1.0 / (monetary + 1.0)
        
        // Weighted risk score
        let riskScore = 0.5 * recencyNorm + 0.3 * frequencyNorm + 0.2 * monetaryNorm
        
        return riskScore
    }
    
    static func rfmAsync(
        in appointments: [Appointment],
        charges: [Charge],
        referenceDate: Date = Date()
    ) async -> (recency: Double, frequency: Double, monetary: Double) {
        await runAsync {
            rfm(in: appointments, charges: charges, referenceDate: referenceDate)
        }
    }

    static func churnRiskScoreAsync(
        in appointments: [Appointment],
        charges: [Charge]
    ) async -> Double {
        await runAsync {
            churnRiskScore(in: appointments, charges: charges)
        }
    }
}

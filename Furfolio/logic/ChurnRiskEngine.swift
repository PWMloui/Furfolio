//
//  ChurnRiskEngine.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import os
import FirebaseRemoteConfigService

@MainActor
enum ChurnRiskEngine {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ChurnRiskEngine")

    private static var recencyWindow: Double {
        FirebaseRemoteConfigService.shared.configValue(forKey: .churnRecencyWindowDays)
    }
    private static var recencyWeight: Double {
        FirebaseRemoteConfigService.shared.configValue(forKey: .churnWeightRecency)
    }
    private static var frequencyWeight: Double {
        FirebaseRemoteConfigService.shared.configValue(forKey: .churnWeightFrequency)
    }
    private static var monetaryWeight: Double {
        FirebaseRemoteConfigService.shared.configValue(forKey: .churnWeightMonetary)
    }
    /// Runs synchronous work off the main thread and returns its result.
    private static func runAsync<T>(
        _ work: @Sendable @escaping () -> T
    ) async -> T {
        await Task.detached { work() }.value
    }
    
    static func rfm(in appointments: [Appointment], charges: [Charge], referenceDate: Date = Date()) -> (recency: Double, frequency: Double, monetary: Double) {
        logger.log("Computing RFM with \(appointments.count) appts, \(charges.count) charges, referenceDate: \(referenceDate)")
        let largeRecencyDefault = 365.0 * 10 // 10 years in days

        let recency: Double
        if let mostRecent = appointments.map({ $0.date }).max() {
            recency = referenceDate.timeIntervalSince(mostRecent) / (60 * 60 * 24)
        } else {
            recency = largeRecencyDefault
        }

        let frequency = Double(appointments.count)
        let monetary = charges.reduce(0.0) { $0 + $1.amount }

        logger.log("RFM values - recency: \(recency), frequency: \(frequency), monetary: \(monetary)")
        return (recency, frequency, monetary)
    }
    
    static func churnRiskScore(in appointments: [Appointment], charges: [Charge]) -> Double {
        logger.log("Computing churnRiskScore")
        let (recency, frequency, monetary) = rfm(in: appointments, charges: charges)

        let recencyNorm = min(recency, recencyWindow) / recencyWindow
        logger.log("Normalized recency: \(recencyNorm)")

        let frequencyNorm = 1.0 / (frequency + 1.0)
        let monetaryNorm = 1.0 / (monetary + 1.0)
        logger.log("Normalized frequency: \(frequencyNorm), monetary: \(monetaryNorm)")

        let riskScore = recencyWeight * recencyNorm
                      + frequencyWeight * frequencyNorm
                      + monetaryWeight * monetaryNorm
        logger.log("Churn risk score: \(riskScore)")

        return riskScore
    }
    
    static func rfmAsync(
        in appointments: [Appointment],
        charges: [Charge],
        referenceDate: Date = Date()
    ) async -> (recency: Double, frequency: Double, monetary: Double) {
        logger.log("rfmAsync invoked")
        return await runAsync {
            rfm(in: appointments, charges: charges, referenceDate: referenceDate)
        }
    }

    static func churnRiskScoreAsync(
        in appointments: [Appointment],
        charges: [Charge]
    ) async -> Double {
        logger.log("churnRiskScoreAsync invoked")
        return await runAsync {
            churnRiskScore(in: appointments, charges: charges)
        }
    }
}

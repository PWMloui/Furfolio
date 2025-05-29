import Foundation
import SwiftData
import os
import FirebaseRemoteConfigService

private let scoringLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "BehaviorScoring")

struct BehaviorScoring {
    static let logger = scoringLogger

    static let tagWeights: [BehaviorTagType: Int] = [
        .calm: 5,
        .playful: 3,
        .aggressive: -5,
        .anxious: -3,
        .obedient: 4,
        .disobedient: -4
    ]

    /// Scoring thresholds
    static var excellentThreshold: Double { 
        FirebaseRemoteConfigService.shared.configValue(forKey: .behaviorExcellentThreshold) 
    }
    static var goodThreshold: Double { 
        FirebaseRemoteConfigService.shared.configValue(forKey: .behaviorGoodThreshold) 
    }

    static func scoreLogs(_ logs: [PetBehaviorLog]) -> Double {
        logger.log("Starting scoreLogs with \(logs.count) logs")
        guard !logs.isEmpty else {
            logger.log("No logs provided, returning score 0")
            return 0
        }

        var totalScore = 0
        for log in logs {
            let weight = tagWeights[log.tag] ?? 0
            totalScore += weight
            logger.log("Log tag: \(log.tag.rawValue), weight: \(weight), running total: \(totalScore)")
        }

        let average = Double(totalScore) / Double(logs.count)
        logger.log("Computed average score: \(average)")
        return average
    }

    /// Scores only logs within the recent number of days.
    static func scoreRecentLogs(_ logs: [PetBehaviorLog], recentDays: Int) -> Double {
        logger.log("Scoring recent logs within \(recentDays)-day window, total logs: \(logs.count)")
        let cutoff = Calendar.current.date(byAdding: .day, value: -recentDays, to: Date())!
        let recent = logs.filter { $0.timestamp >= cutoff }
        logger.log("Filtered to \(recent.count) recent logs")
        return scoreLogs(recent)
    }

    static func badge(for score: Double) -> String {
        let badge: String
        if score >= excellentThreshold {
            badge = "🟢 Excellent"
        } else if score >= goodThreshold {
            badge = "🟡 Good"
        } else {
            badge = "🔴 Needs Attention"
        }
        logger.log("Assigned badge '\(badge)' for score \(score)")
        return badge
    }

    static func averageScore(for owner: DogOwner, in context: ModelContext) async -> Double {
        do {
            let fetchDescriptor = FetchDescriptor<PetBehaviorLog>(
                predicate: #Predicate { $0.owner == owner }
            )
            let logs = try await context.fetch(fetchDescriptor)
            logger.log("Fetched \(logs.count) logs for owner \(owner.id)")
            let score = scoreLogs(logs)
            logger.log("Average score for owner \(owner.id): \(score)")
            return score
        } catch {
            logger.error("Failed to fetch logs for owner \(owner.id): \(error.localizedDescription)")
            return 0
        }
    }
}

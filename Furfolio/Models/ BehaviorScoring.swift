//
//  BehaviorScoring.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on 2025-07-07 — added Localization, Identifiable conformance, RiskCategory enum, and richer preview.
//

import Foundation
import SwiftUI
import os

/// Utility for converting behavior notes into severity scores and risk categories.
struct BehaviorScoring {
    
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "BehaviorScoring")
    
    // MARK: — Severity Levels
    
    /// Ordered severity levels from calm (0) to severe (3), supporting localization and emoji representation.
    enum SeverityLevel: Int, Comparable, Identifiable, CustomStringConvertible {
        case calm      = 0
        case mild      = 1
        case moderate  = 2
        case severe    = 3
        
        var id: Int { rawValue }
        
        /// A display name for this level.
        var description: String {
            switch self {
            case .calm:      return NSLocalizedString("Calm",      comment: "Behavior calm")
            case .mild:      return NSLocalizedString("Mild",      comment: "Behavior mild")
            case .moderate:  return NSLocalizedString("Moderate",  comment: "Behavior moderate")
            case .severe:    return NSLocalizedString("Severe",    comment: "Behavior severe")
            }
        }
        
        /// An emoji to represent this level.
        var emoji: String {
            switch self {
            case .calm:      return "🟢"
            case .mild:      return "🟡"
            case .moderate:  return "🟠"
            case .severe:    return "🔴"
            }
        }
        
        static func < (lhs: SeverityLevel, rhs: SeverityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Mapping of keywords to severity levels; notes containing multiple keywords pick the highest level.
    private static let defaultKeywordMap: [String: SeverityLevel] = [
        "calm":        .calm,
        "friendly":    .calm,
        "anxious":     .mild,
        "nervous":     .mild,
        "agitated":    .moderate,
        "aggressive":  .severe,
        "bite":        .severe,
        "bit":         .severe
    ]
    
    // MARK: — Single-Note Scoring
    
    /// Scores a single behavior note by returning the highest matching SeverityLevel.
    /// - Parameter note: The behavior description text.
    /// - Parameter keywordMap: A mapping from keywords to severity levels.
    /// - Returns: The highest SeverityLevel found; defaults to .calm.
    static func score(
        note: String,
        keywordMap: [String: SeverityLevel] = defaultKeywordMap
    ) -> SeverityLevel {
        logger.log("Scoring note: '\(note)'")
        let lower = note.lowercased()
        let result = keywordMap.reduce(.calm) { current, pair in
            let (keyword, level) = pair
            return lower.contains(keyword) && level > current
                ? level
                : current
        }
        logger.log("Resulting severity for note: '\(note)' -> \(result.rawValue)")
        return result
    }
    
    // MARK: — Aggregate Scoring
    
    /// Computes the average severity across multiple notes.
    /// - Parameter notes: Array of behavior note strings.
    /// - Parameter keywordMap: A mapping from keywords to severity levels.
    /// - Returns: A Double between 0.0 (all calm) and 3.0 (all severe).
    static func averageSeverity(
        for notes: [String],
        keywordMap: [String: SeverityLevel] = defaultKeywordMap
    ) -> Double {
        logger.log("Computing averageSeverity for notes count: \(notes.count)")
        guard !notes.isEmpty else { return 0 }
        let total = notes.map { score(note: $0, keywordMap: keywordMap).rawValue }.reduce(0, +)
        let average = Double(total) / Double(notes.count)
        logger.log("Computed averageSeverity: \(average)")
        return average
    }
    
    /// Convenience for extracting notes from `PetBehaviorLog` objects.
    static func averageSeverity(
        from logs: [PetBehaviorLog],
        keywordMap: [String: SeverityLevel] = defaultKeywordMap
    ) -> Double {
        logger.log("Computing averageSeverity from logs count: \(logs.count)")
        let result = averageSeverity(for: logs.map(\.note), keywordMap: keywordMap)
        logger.log("Computed averageSeverity from logs: \(result)")
        return result
    }
    
    // MARK: — Risk Categories
    
    /// Semantic risk categories based on average severity, providing color-coding for UI.
    enum RiskCategory: Int, Comparable, Identifiable, CustomStringConvertible {
        case low       = 0
        case moderate  = 1
        case high      = 2
        
        var id: Int { rawValue }
        
        var description: String {
            switch self {
            case .low:       return NSLocalizedString("Low Risk",      comment: "Behavior risk low")
            case .moderate:  return NSLocalizedString("Moderate Risk", comment: "Behavior risk moderate")
            case .high:      return NSLocalizedString("High Risk",     comment: "Behavior risk high")
            }
        }
        
        /// A semantic color for UI (e.g. badges, charts).
        var color: Color {
            switch self {
            case .low:       return .green
            case .moderate:  return .yellow
            case .high:      return .red
            }
        }
        
        static func < (lhs: RiskCategory, rhs: RiskCategory) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Categorizes a numeric average severity into a RiskCategory (.low, .moderate, .high).
    /// - Parameter average: The computed average severity.
    /// - Returns: The corresponding RiskCategory.
    static func riskCategory(for average: Double) -> RiskCategory {
        logger.log("Determining riskCategory for average: \(average)")
        let category: RiskCategory
        switch average {
        case 0..<1:    category = .low
        case 1..<2:    category = .moderate
        default:       category = .high
        }
        logger.log("Assigned riskCategory: \(category.rawValue)")
        return category
    }
    
    /// Convenience for computing a `RiskCategory` directly from logs.
    static func riskCategory(
        from logs: [PetBehaviorLog],
        keywordMap: [String: SeverityLevel] = defaultKeywordMap
    ) -> RiskCategory {
        logger.log("Determining riskCategory from logs count: \(logs.count)")
        let category = riskCategory(for: averageSeverity(from: logs, keywordMap: keywordMap))
        logger.log("Assigned riskCategory from logs: \(category.rawValue)")
        return category
    }
}


// MARK: — SwiftUI Preview

#if DEBUG
import SwiftUI

struct BehaviorScoring_Previews: PreviewProvider {
    static let sampleLogs: [PetBehaviorLog] = [
        .sample, // assumes PetBehaviorLog.sample exists
        PetBehaviorLog(note: "Pet was anxious about the clippers", owner: DogOwner.sample),
        PetBehaviorLog(note: "Showed aggressive behavior and bit", owner: DogOwner.sample)
    ]
    
    static var previews: some View {
        VStack(spacing: 16) {
            Text("Per-Note Scores").font(.headline)
            ForEach(sampleLogs, id: \.id) { log in
                let level = BehaviorScoring.score(note: log.note)
                HStack {
                    Text(level.emoji)
                    Text(level.description)
                    Spacer()
                    Text("“\(log.note)”")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            Text("Aggregate").font(.headline)
            let avg = BehaviorScoring.averageSeverity(from: sampleLogs)
            let risk = BehaviorScoring.riskCategory(from: sampleLogs)
            HStack {
                Text(String(format: NSLocalizedString("Avg: %.2f", comment: "Average severity"), avg))
                Spacer()
                Text(risk.description)
                    .foregroundColor(risk.color)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

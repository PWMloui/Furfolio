
//
//  ServiceType.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

/// Enum representing the type of grooming service offered.
enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case fullGroom
    case basicBath
    case nailTrim
    case teethCleaning
    case deShedding
    case earCleaning
    case fleaTreatment
    case custom

    var id: String { rawValue }

    /// User-friendly display name.
    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .teethCleaning: return "Teeth Cleaning"
        case .deShedding: return "De-Shedding"
        case .earCleaning: return "Ear Cleaning"
        case .fleaTreatment: return "Flea Treatment"
        case .custom: return "Custom"
        }
    }

    /// SF Symbol icon or emoji for each service.
    var icon: String {
        switch self {
        case .fullGroom: return "scissors"
        case .basicBath: return "drop"
        case .nailTrim: return "pawprint"
        case .teethCleaning: return "mouth"
        case .deShedding: return "wind"
        case .earCleaning: return "ear"
        case .fleaTreatment: return "ant"
        case .custom: return "star"
        }
    }

    /// Estimated average duration (minutes) for each service.
    var durationEstimate: Int {
        switch self {
        case .fullGroom: return 90
        case .basicBath: return 45
        case .nailTrim: return 20
        case .teethCleaning: return 15
        case .deShedding: return 30
        case .earCleaning: return 10
        case .fleaTreatment: return 25
        case .custom: return 60
        }
    }
}

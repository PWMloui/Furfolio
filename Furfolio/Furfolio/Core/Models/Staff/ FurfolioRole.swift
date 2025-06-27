//
//  Role.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation

enum FurfolioRole: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case assistant = "Assistant"
    case receptionist = "Receptionist"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .owner: return "Manager / Owner"
        case .assistant: return "Staff"
        case .receptionist: return "Front Desk"
        }
    }

    var systemIcon: String {
        switch self {
        case .owner: return "chart.bar.fill"
        case .assistant: return "scissors"
        case .receptionist: return "phone.fill"
        }
    }
}

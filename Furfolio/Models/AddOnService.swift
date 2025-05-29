//
//  AddOnService.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData
import os

@Model
final class AddOnService: Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AddOnService")
    
    /// Shared currency formatter for price display.
    private static let currencyFormatter: NumberFormatter = {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        return fmt
    }()
    enum ServiceType: String, Codable, CaseIterable, Hashable {
        case bath
        case haircut
        case deShedding
        case analGlandsExpression
        case nailClipping
        case earCleaning
        case faceGrooming
        case pawPadTrim
        case hygieneAreaTrim
        case teethBrushing
        case knotsMatting
        case fleaTickBath
        case hairDye

        var displayName: String {
            switch self {
            case .bath: return "Bath"
            case .haircut: return "Haircut"
            case .deShedding: return "De-shedding"
            case .analGlandsExpression: return "Anal Glands Expression"
            case .nailClipping: return "Nail Clipping"
            case .earCleaning: return "Ear Cleaning"
            case .faceGrooming: return "Face Grooming"
            case .pawPadTrim: return "Paw Pad Trim"
            case .hygieneAreaTrim: return "Hygiene Trim"
            case .teethBrushing: return "Teeth Brushing"
            case .knotsMatting: return "Knots & Matting"
            case .fleaTickBath: return "Flea & Tick Bath"
            case .hairDye: return "Hair Dye"
            }
        }
    }

    @Attribute var id: UUID
    @Attribute var type: ServiceType
    @Attribute var minPrice: Double
    @Attribute var maxPrice: Double
    @Relationship(deleteRule: .nullify) var requires: [AddOnService]

    init(
        id: UUID = UUID(),
        type: ServiceType,
        minPrice: Double,
        maxPrice: Double,
        requires: [AddOnService] = []
    ) {
        self.id = id
        self.type = type
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.requires = requires
    }

    /// Human-friendly price range text, e.g. "$40–85"
    var priceRangeText: String {
        logger.log("Generating priceRangeText for service \(type.rawValue), prices: \(minPrice)-\(maxPrice)")
        let min = Self.currencyFormatter.string(from: NSNumber(value: minPrice)) ?? ""
        let max = Self.currencyFormatter.string(from: NSNumber(value: maxPrice)) ?? ""
        let range = "\(min)–\(max)"
        logger.log("Generated priceRangeText: \(range)")
        return range
    }

    // MARK: - Hashable & Identifiable
    static func == (lhs: AddOnService, rhs: AddOnService) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


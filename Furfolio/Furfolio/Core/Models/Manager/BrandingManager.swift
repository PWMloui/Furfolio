//
//  BrandingManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftUI
import SwiftData

/// Stores branding configuration for the Furfolio app.
@Model public struct BrandingConfiguration: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    
    /// Hex string for the primary color (e.g., "#007AFF").
    public var primaryColorHex: String
    
    /// Hex string for the secondary color (e.g., "#FFFFFF").
    public var secondaryColorHex: String
    
    /// Hex string for the accent color (e.g., "#FF9500").
    public var accentColorHex: String
    
    /// Optional name of the logo asset in the asset catalog.
    public var logoAssetName: String?
    
    // MARK: - Transient computed colors
    
    @Attribute(.transient)
    public var primaryColor: Color {
        Color(hex: primaryColorHex)
    }
    
    @Attribute(.transient)
    public var secondaryColor: Color {
        Color(hex: secondaryColorHex)
    }
    
    @Attribute(.transient)
    public var accentColor: Color {
        Color(hex: accentColorHex)
    }
}

/// Manages retrieval and updates to the app’s branding settings.
public class BrandingManager: ObservableObject {
    @Environment(\.modelContext) private var modelContext
    @Query private var configurations: [BrandingConfiguration]
    
    /// The active branding configuration.
    @Published public private(set) var current: BrandingConfiguration

    /// Initializes the manager, loading existing config or creating defaults.
    public init(context: ModelContext) {
        self.modelContext = context
        if let existing = configurations.first {
            self.current = existing
        } else {
            let defaultConfig = BrandingConfiguration(
                primaryColorHex: "#007AFF",
                secondaryColorHex: "#FFFFFF",
                accentColorHex: "#FF9500",
                logoAssetName: "AppLogo"
            )
            modelContext.insert(defaultConfig)
            self.current = defaultConfig
        }
    }

    /// Updates the color scheme.
    public func updateColors(primary: String, secondary: String, accent: String) {
        let updated = BrandingConfiguration(
            primaryColorHex: primary,
            secondaryColorHex: secondary,
            accentColorHex: accent,
            logoAssetName: current.logoAssetName
        )
        modelContext.insert(updated)
        self.current = updated
    }

    /// Updates the logo by asset name.
    public func updateLogoAsset(name: String) {
        current.logoAssetName = name
    }
}

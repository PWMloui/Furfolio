//
//  Business.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Business (Unified, Modular, Tokenized, Auditable Business Entity)

/// Protocol stub for audit logging capabilities.
/// Provides an interface to capture audit trails, ensuring compliance with regulatory standards,
/// supporting business reporting, and enabling traceability of changes across multi-user environments.
protocol AuditLoggable {
    /// Logs a description of a change or event for audit trail purposes.
    /// - Parameter description: A textual description of the change or event.
    func logChange(description: String)
}

/// Represents a modular, auditable, and tokenized business entity within Furfolio.
/// Serves as the single source of truth for owner, staff, branding, compliance, analytics, 
/// and all business logic and settings. Supports audit trails, multi-user/role management, 
/// feature flagging, route optimization (TSP), and design system integration.
/// This class centralizes business state and workflows, ensuring data integrity and observability 
/// for both UI and backend processes.
@Model
final class Business: Identifiable, ObservableObject, AuditLoggable {
    // MARK: - Unique Identifier
    /// Globally unique identifier for the business entity.
    /// Used for audit correlation, data integrity, and multi-system referencing.
    @Attribute(.unique)
    var id: UUID

    // MARK: - Core Business Details
    /// The official name of the business.
    /// Used for branding, UI display, and audit/event logging.
    @Published @Attribute(.indexed)
    var name: String

    /// The name of the business owner.
    /// Important for compliance, ownership tracking, and business reporting.
    @Published @Attribute(.indexed)
    var ownerName: String

    /// Physical or mailing address of the business.
    /// Used for compliance, customer communications, and UI display.
    @Published
    var address: String?

    /// Contact phone number for the business.
    /// Supports customer contact workflows and compliance.
    @Published
    var phone: String?

    /// Contact email for the business.
    /// Used for notifications, compliance, and customer service.
    @Published
    var email: String?

    /// Website URL of the business.
    /// Supports branding, marketing, and UI display.
    @Published
    var website: String?

    // MARK: - Branding
    /// Binary data representing the business logo image.
    /// Used for UI branding and design system integration.
    @Published
    var logoImageData: Data?

    /// Hex or named color string representing the business color theme.
    /// Used for UI theming and consistent branding across the app.
    @Published
    var colorTheme: String?

    // MARK: - Staff and Multi-user/Role Support
    /// Staff members associated with this business.
    /// Enables role-based access control, audit trails on user actions, and multi-user workflows.
    /// Configured with cascade delete rule for data integrity on staff removal.
    @Published @Relationship(deleteRule: .cascade)
    var staff: [StaffMember]

    // MARK: - Settings
    /// Default duration (in minutes) for services offered by the business.
    /// Used in scheduling workflows and analytics.
    @Published
    var defaultServiceDuration: Int

    /// Currency code used for transactions and reporting.
    /// Important for compliance and financial analytics.
    @Published
    var currency: String

    /// Time zone identifier for the business location.
    /// Used for scheduling, audit timestamp normalization, and analytics.
    @Published
    var timeZone: String

    /// Locale identifier for regional formatting and language preferences.
    /// Supports UI localization and compliance with regional laws.
    @Published
    var locale: String

    // MARK: - Analytics and Status
    /// Timestamp when the business entity was created.
    /// Used for lifecycle analytics and audit trail baseline.
    @Published
    var dateCreated: Date

    /// Timestamp of the last modification to the business entity.
    /// Critical for audit logs, synchronization, and UI freshness indicators.
    @Published
    var lastModified: Date

    /// Indicates whether the business is currently active.
    /// Supports compliance, workflow gating, and analytics segmentation.
    @Published
    var isActive: Bool

    // MARK: - Feature Flags and TSP Integration Stubs
    /// Dictionary of feature flags controlling experimental or staged features.
    /// Enables modular rollout, A/B testing, and compliance with feature governance.
    @Published
    var featureFlags: [String: Bool]

    /// Flag indicating if the Traveling Salesman Problem (TSP) route optimization integration is enabled.
    /// Supports advanced logistics workflows and analytics.
    @Published
    var tspIntegrationEnabled: Bool

    // MARK: - Initializer

    /// Initializes a new Business instance with provided or default parameters.
    /// - Parameters:
    ///   - id: Unique identifier, autogenerated by default.
    ///   - name: Business name.
    ///   - ownerName: Owner's name.
    ///   - address: Optional business address.
    ///   - phone: Optional contact phone.
    ///   - email: Optional contact email.
    ///   - website: Optional website URL.
    ///   - logoImageData: Optional logo image data.
    ///   - colorTheme: Optional color theme string.
    ///   - staff: Optional initial staff array.
    ///   - defaultServiceDuration: Default service duration in minutes.
    ///   - currency: Currency code.
    ///   - timeZone: Time zone identifier.
    ///   - locale: Locale identifier.
    ///   - dateCreated: Creation timestamp.
    ///   - lastModified: Last modification timestamp.
    ///   - isActive: Active status flag.
    ///   - featureFlags: Feature flags dictionary.
    ///   - tspIntegrationEnabled: TSP integration enabled flag.
    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoImageData: Data? = nil,
        colorTheme: String? = nil,
        staff: [StaffMember] = [],
        defaultServiceDuration: Int = 60,
        currency: String = "USD",
        timeZone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        dateCreated: Date = Date(),
        lastModified: Date = Date(),
        isActive: Bool = true,
        featureFlags: [String: Bool] = [:],
        tspIntegrationEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.address = address
        self.phone = phone
        self.email = email
        self.website = website
        self.logoImageData = logoImageData
        self.colorTheme = colorTheme
        self.staff = staff
        self.defaultServiceDuration = defaultServiceDuration
        self.currency = currency
        self.timeZone = timeZone
        self.locale = locale
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.isActive = isActive
        self.featureFlags = featureFlags
        self.tspIntegrationEnabled = tspIntegrationEnabled
    }

    // MARK: - Computed Properties

    /// Decoded logo as SwiftUI Image (if available).
    /// Used for UI branding and dynamic theming.
    var logoImage: Image? {
        guard let data = logoImageData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    /// Returns the formatted address or a placeholder if nil or empty.
    /// Supports UI display consistency and compliance requirements.
    var formattedAddress: String {
        guard let addr = address, !addr.isEmpty else { return "—" }
        return addr
    }

    /// Number of staff members associated with the business.
    /// Useful for analytics, workflows, and UI display.
    var staffCount: Int {
        staff.count
    }

    /// Returns the last modified date formatted as a user-friendly string.
    /// Supports UI display and audit event correlation.
    var formattedLastModified: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }

    /// Indicates whether branding is considered complete (logo and color theme set).
    /// Used for UI workflow gating and analytics on branding completeness.
    var isBrandingComplete: Bool {
        if let color = colorTheme?.trimmingCharacters(in: .whitespacesAndNewlines),
           !color.isEmpty,
           logoImageData != nil {
            return true
        }
        return false
    }

    // MARK: - Methods

    /// Updates business settings and refreshes last modified timestamp.
    /// Triggers audit logging and can be extended for analytics event emission.
    /// - Parameters:
    ///   - name: Optional new business name.
    ///   - ownerName: Optional new owner name.
    ///   - address: Optional new address.
    ///   - phone: Optional new phone number.
    ///   - email: Optional new email address.
    ///   - website: Optional new website URL.
    ///   - logoImageData: Optional new logo image data.
    ///   - colorTheme: Optional new color theme.
    ///   - defaultServiceDuration: Optional new default service duration.
    ///   - currency: Optional new currency code.
    ///   - timeZone: Optional new time zone identifier.
    ///   - locale: Optional new locale identifier.
    ///   - isActive: Optional new active status.
    ///   - featureFlags: Optional new feature flags dictionary.
    ///   - tspIntegrationEnabled: Optional new TSP integration flag.
    func updateSettings(
        name: String? = nil,
        ownerName: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoImageData: Data? = nil,
        colorTheme: String? = nil,
        defaultServiceDuration: Int? = nil,
        currency: String? = nil,
        timeZone: String? = nil,
        locale: String? = nil,
        isActive: Bool? = nil,
        featureFlags: [String: Bool]? = nil,
        tspIntegrationEnabled: Bool? = nil
    ) {
        if let name = name { self.name = name }
        if let ownerName = ownerName { self.ownerName = ownerName }
        if let address = address { self.address = address }
        if let phone = phone { self.phone = phone }
        if let email = email { self.email = email }
        if let website = website { self.website = website }
        if let logoImageData = logoImageData { self.logoImageData = logoImageData }
        if let colorTheme = colorTheme { self.colorTheme = colorTheme }
        if let defaultServiceDuration = defaultServiceDuration { self.defaultServiceDuration = defaultServiceDuration }
        if let currency = currency { self.currency = currency }
        if let timeZone = timeZone { self.timeZone = timeZone }
        if let locale = locale { self.locale = locale }
        if let isActive = isActive { self.isActive = isActive }
        if let featureFlags = featureFlags { self.featureFlags = featureFlags }
        if let tspIntegrationEnabled = tspIntegrationEnabled { self.tspIntegrationEnabled = tspIntegrationEnabled }
        self.lastModified = Date()
        logChange(description: "Business settings updated")
    }

    // MARK: - AuditLoggable

    /// Logs changes to the business entity.
    /// This method is intended to be extended with integration to audit trail storage,
    /// compliance reporting systems, and business analytics event pipelines.
    /// - Parameter description: Description of the change.
    func logChange(description: String) {
        // TODO: Implement audit logging logic here.
        print("[AuditLog] \(Date()): \(description)")
    }
}

// MARK: - SwiftUI Previews

#if DEBUG
import SwiftUI

/// SwiftUI previews demonstrating the Business entity in tokenized and modular UI contexts.
/// These previews serve to validate business logic integration, audit state reflection,
/// and visual branding completeness within a controlled environment.
struct Business_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Default Business Preview: Demonstrates basic business state and UI bindings.
            BusinessPreviewView()
                .previewDisplayName("Default Business")

            // Branding Complete Preview: Simulates a business with complete branding and feature flags,
            // showcasing dark mode and advanced UI theming.
            BusinessPreviewView()
                .previewDisplayName("Branding Complete")
                .environment(\.colorScheme, .dark)
        }
    }

    struct BusinessPreviewView: View {
        @StateObject private var business = Business(
            name: "Furfolio Studio",
            ownerName: "Jane Doe",
            address: "123 Main St, Anytown",
            phone: "555-1234",
            email: "contact@furfolio.com",
            website: "https://furfolio.com",
            logoImageData: UIImage(systemName: "pawprint.fill")?.pngData(),
            colorTheme: "#FF6600",
            staff: [StaffMember(name: "John Smith", role: "Stylist")],
            defaultServiceDuration: 45,
            currency: "USD",
            timeZone: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            isActive: true,
            featureFlags: ["newBookingFlow": true],
            tspIntegrationEnabled: true
        )

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(business.name)
                    .font(.title)
                    .bold()
                if let logo = business.logoImage {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                Text("Owner: \(business.ownerName)")
                Text("Staff Count: \(business.staffCount)")
                Text("Last Modified: \(business.formattedLastModified)")
                Text("Branding Complete: \(business.isBrandingComplete ? "Yes" : "No")")
                Text("Active: \(business.isActive ? "Yes" : "No")")
            }
            .padding()
        }
    }
}
#endif

//
//  MarketingEngine.swift
//  Furfolio
//
//  Enhanced: Audit, campaign tagging, analytics, accessibility, retry, and export.
//  Author: mac + ChatGPT
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct MarketingAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "MarketingEngine"
}

// MARK: - Analytics Logger Protocol & Null Logger

public protocol MarketingAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        _ event: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullMarketingAnalyticsLogger: MarketingAnalyticsLogger {
    public let testMode: Bool
    public init(testMode: Bool = true) { self.testMode = testMode }
    public func logEvent(
        _ event: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[NullMarketingAnalyticsLogger][TEST MODE] \(event) \(parameters ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - Campaign Model, Tags, and Analytics

struct MarketingCampaign: Identifiable, Codable {
    let id: UUID
    let name: String
    let subject: String
    let bodyTemplate: String
    var tags: [String] = []
    var sentAt: Date? = nil
    var riskScore: Int = 0
    var badgeTokens: [String] = []

    enum CampaignBadge: String, Codable, CaseIterable {
        case reengagement, promo, risk, compliance, automation, custom
    }
    var badges: [CampaignBadge] { badgeTokens.compactMap { CampaignBadge(rawValue: $0) } }
    mutating func addBadge(_ badge: CampaignBadge) {
        if !badgeTokens.contains(badge.rawValue) { badgeTokens.append(badge.rawValue) }
    }
    mutating func removeBadge(_ badge: CampaignBadge) {
        badgeTokens.removeAll { $0 == badge.rawValue }
    }
    var accessibilityLabel: String {
        NSLocalizedString(
            "%@. %@. %@.",
            comment: "Accessibility label for marketing campaign with name, subject, and badges"
        ).localizedFormat(
            name,
            subject,
            badges.map { NSLocalizedString($0.rawValue.capitalized, comment: "Campaign badge") }.joined(separator: ", ")
        )
    }
    /// Exports the campaign as a pretty-printed JSON string.
    func exportJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(self).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - Enhanced ClientSegment

enum ClientSegment: Hashable, Identifiable, Codable {
    case allClients
    case newClients
    case atRiskClients
    case inactiveClients
    case topSpenders(count: Int)
    case loyaltyStars
    case ownersOfBreed(String)

    var id: String {
        switch self {
        case .ownersOfBreed(let breed): return "ownersOfBreed-\(breed)"
        default: return "\(self)"
        }
    }

    var displayName: String {
        switch self {
        case .allClients: return NSLocalizedString("All Clients", comment: "Client segment display name")
        case .newClients: return NSLocalizedString("New Clients", comment: "Client segment display name")
        case .atRiskClients: return NSLocalizedString("At-Risk Clients", comment: "Client segment display name")
        case .inactiveClients: return NSLocalizedString("Inactive Clients", comment: "Client segment display name")
        case .topSpenders(let count): return String(format: NSLocalizedString("Top %d Spenders", comment: "Client segment display name with count"), count)
        case .loyaltyStars: return NSLocalizedString("Loyalty Stars", comment: "Client segment display name")
        case .ownersOfBreed(let breed): return String(format: NSLocalizedString("Owners of %@", comment: "Client segment display name with breed"), breed)
        }
    }
}

// MARK: - Analytics Logging Protocol (Legacy, will be replaced by new trust logger)

/// Protocol defining async analytics logging capabilities.
protocol AnalyticsLogging {
    /// Logs an analytics event asynchronously.
    /// - Parameters:
    ///   - event: The event name.
    ///   - parameters: Optional dictionary of event parameters.
    func logEventAsync(_ event: String, parameters: [String: Any]?) async
}

// MARK: - Messaging Service Protocol

protocol MessagingService {
    func send(message: String, to contact: String) async throws
}

// MARK: - Main Enhanced Engine

@MainActor
final class MarketingEngine: ObservableObject, AnalyticsLogging {
    private let retentionAnalyzer: CustomerRetentionAnalyzer
    private let revenueAnalyzer: RevenueAnalyzer
    private let dataStore: DataStoreService
    private let messagingService: MessagingService

    // Audit and analytics
    @Published private(set) var lastAuditLog: [String] = []
    @Published private(set) var lastCampaignResult: CampaignResult?
    @Published var isSending: Bool = false

    /// Buffer to store last 1000 audit entries with thread-safe management.
    private var auditBuffer: [String] = []
    private let auditQueue = DispatchQueue(label: "com.furfolio.marketingengine.auditQueue", attributes: .concurrent)

    /// --- Trust Center Audit Buffer ---
    private var analyticsLogger: MarketingAnalyticsLogger = NullMarketingAnalyticsLogger()
    private var auditEventBuffer: [(date: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let auditEventBufferLimit = 1000

    /// Flag to enable test mode for QA and simulated analytics logging.
    var testMode: Bool = false

    /// Campaign result model with Codable conformance.
    struct CampaignResult: Codable {
        let campaignID: UUID
        let sentCount: Int
        let failedCount: Int
        let targetCount: Int
        let failedRecipients: [String]
        let sentAt: Date
        let segment: ClientSegment

        /// Exports the campaign result as a pretty-printed JSON string.
        func exportJSON() -> String? {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            return try? encoder.encode(self).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    init(
        retentionAnalyzer: CustomerRetentionAnalyzer = .shared,
        revenueAnalyzer: RevenueAnalyzer = .shared,
        dataStore: DataStoreService = .shared,
        messagingService: MessagingService
    ) {
        self.retentionAnalyzer = retentionAnalyzer
        self.revenueAnalyzer = revenueAnalyzer
        self.dataStore = dataStore
        self.messagingService = messagingService
    }

    // MARK: - Trust Center Audit Helper

    private func logAuditEvent(_ event: String, parameters: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event,
            parameters: parameters,
            role: MarketingAuditContext.role,
            staffID: MarketingAuditContext.staffID,
            context: MarketingAuditContext.context,
            escalate: escalate
        )
        auditEventBuffer.append((date: Date(), event: event, parameters: parameters, role: MarketingAuditContext.role, staffID: MarketingAuditContext.staffID, context: MarketingAuditContext.context, escalate: escalate))
        if auditEventBuffer.count > auditEventBufferLimit {
            auditEventBuffer.removeFirst(auditEventBuffer.count - auditEventBufferLimit)
        }
    }

    /// Returns a detailed diagnostics summary with all audit fields.
    func diagnosticsAuditTrail() -> String {
        auditEventBuffer.map { evt in
            let dateStr = DateFormatter.localizedString(from: evt.date, dateStyle: .short, timeStyle: .medium)
            let paramsStr = evt.parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "\(dateStr): \(evt.event) \(paramsStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }.joined(separator: "\n")
    }

    // MARK: - Fetch by Segment

    func fetchClients(for segment: ClientSegment) async -> [DogOwner] {
        let allOwners = await dataStore.fetchAll(DogOwner.self)
        switch segment {
        case .allClients:
            return allOwners
        case .newClients:
            return retentionAnalyzer.newClientOwners(in: allOwners)
        case .atRiskClients:
            return retentionAnalyzer.retentionRiskOwners(in: allOwners)
        case .inactiveClients:
            return retentionAnalyzer.inactiveOwners(in: allOwners)
        case .topSpenders(let count):
            return revenueAnalyzer.topClients(owners: allOwners, topN: count).map { $0.owner }
        case .loyaltyStars:
            return allOwners.filter { $0.badgeTypes.contains("loyaltyStar") }
        case .ownersOfBreed(let breed):
            return allOwners.filter { owner in
                owner.dogs.contains { $0.breed?.localizedCaseInsensitiveContains(breed) == true }
            }
        }
    }

    // MARK: - Send Campaign (Batch, Audit, Retry)

    @discardableResult
    func send(
        campaign: MarketingCampaign,
        to clients: [DogOwner],
        segment: ClientSegment,
        maxRetry: Int = 1,
        throttleMilliseconds: UInt64 = 0
    ) async -> CampaignResult {
        var sentCount = 0
        var failedCount = 0
        var failedRecipients: [String] = []
        isSending = true
        let total = clients.count

        let startMsg = String(
            format: NSLocalizedString(
                "Begin campaign '%@' (%@) to %d clients (%@).",
                comment: "Audit log entry for campaign start"
            ),
            campaign.name,
            campaign.subject,
            total,
            segment.displayName
        )
        await addAudit(startMsg)
        await logAuditEvent("campaign_begin", parameters: [
            "campaignID": campaign.id.uuidString,
            "subject": campaign.subject,
            "clientCount": total,
            "segment": segment.id
        ])

        for client in clients {
            guard let contactEmail = client.email, !contactEmail.isEmpty else {
                failedCount += 1
                failedRecipients.append(client.ownerName)
                let skipMsg = String(
                    format: NSLocalizedString(
                        "Skipped client %@: no email.",
                        comment: "Audit log entry for skipped client without email"
                    ),
                    client.ownerName
                )
                await addAudit(skipMsg)
                await logAuditEvent("client_skipped_no_email", parameters: ["ownerName": client.ownerName])
                continue
            }

            let petName = client.dogs.first?.name ?? NSLocalizedString("your pet", comment: "Default pet name placeholder")
            let personalizedBody = campaign.bodyTemplate
                .replacingOccurrences(of: "{clientName}", with: client.ownerName)
                .replacingOccurrences(of: "{petName}", with: petName)

            var delivered = false
            var attempts = 0
            while !delivered && attempts <= maxRetry {
                attempts += 1
                do {
                    try await messagingService.send(message: personalizedBody, to: contactEmail)
                    sentCount += 1
                    delivered = true
                } catch {
                    let failMsg = String(
                        format: NSLocalizedString(
                            "Failed to send to %@ (attempt %d): %@",
                            comment: "Audit log entry for failed send attempt"
                        ),
                        contactEmail,
                        attempts,
                        String(describing: error)
                    )
                    await addAudit(failMsg)
                    await logAuditEvent("send_failed", parameters: [
                        "contactEmail": contactEmail,
                        "attempt": attempts,
                        "error": String(describing: error)
                    ])
                    if attempts > maxRetry {
                        failedCount += 1
                        failedRecipients.append(contactEmail)
                    } else {
                        try? await Task.sleep(nanoseconds: throttleMilliseconds * 1_000_000)
                    }
                }
            }
        }
        isSending = false
        let result = CampaignResult(
            campaignID: campaign.id,
            sentCount: sentCount,
            failedCount: failedCount,
            targetCount: total,
            failedRecipients: failedRecipients,
            sentAt: Date(),
            segment: segment
        )
        lastCampaignResult = result

        let completeMsg = String(
            format: NSLocalizedString(
                "Campaign '%@' complete. %d sent, %d failed.",
                comment: "Audit log entry for campaign completion"
            ),
            campaign.name,
            sentCount,
            failedCount
        )
        await addAudit(completeMsg)
        await logAuditEvent("campaign_complete", parameters: [
            "campaignID": campaign.id.uuidString,
            "sentCount": sentCount,
            "failedCount": failedCount,
            "targetCount": total,
            "segment": segment.id
        ])
        await logEventAsync("campaign_sent", parameters: [
            "campaignID": campaign.id.uuidString,
            "sentCount": sentCount,
            "failedCount": failedCount,
            "targetCount": total,
            "segment": segment.id
        ])
        return result
    }

    // MARK: - Audit, Analytics, Export

    func addAudit(_ entry: String) async {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let fullEntry = "[\(ts)] \(entry)"
        auditQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.auditBuffer.append(fullEntry)
            if self.auditBuffer.count > 1000 {
                self.auditBuffer.removeFirst(self.auditBuffer.count - 1000)
            }
            Task { @MainActor in
                self.lastAuditLog = self.auditBuffer
            }
        }
    }

    func exportAuditLog() -> String? {
        var snapshot: [String] = []
        auditQueue.sync {
            snapshot = auditBuffer
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(snapshot).flatMap { String(data: $0, encoding: .utf8) }
    }

    func exportLastCampaignResult() -> String? {
        guard let last = lastCampaignResult else { return nil }
        return last.exportJSON()
    }

    var accessibilitySummary: String {
        guard let last = lastCampaignResult else {
            return NSLocalizedString("No campaign sent yet.", comment: "Accessibility summary when no campaign sent")
        }
        return String(
            format: NSLocalizedString(
                "Campaign sent to %d of %d clients. %d failed. Segment: %@.",
                comment: "Accessibility summary for latest campaign"
            ),
            last.sentCount,
            last.targetCount,
            last.failedCount,
            last.segment.displayName
        )
    }

    // MARK: - AnalyticsLogging Protocol Conformance

    func logEventAsync(_ event: String, parameters: [String: Any]? = nil) async {
        if testMode {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200 ms
            await addAudit(String(format: NSLocalizedString("TestMode: Logged event '%@' with parameters %@", comment: "Audit log for test mode analytics event"), event, String(describing: parameters ?? [:])))
        } else {
            await addAudit(String(format: NSLocalizedString("Analytics event logged: '%@' with parameters %@", comment: "Audit log for analytics event"), event, String(describing: parameters ?? [:])))
        }
        await logAuditEvent(event, parameters: parameters)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct MockMessagingService: MessagingService {
    func send(message: String, to contact: String) async throws {
        if Bool.random() { throw NSError(domain: "SendError", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Simulated send failure", comment: "Error description")]) }
        print("--- Sending Message ---\nTo: \(contact)\nBody: \(message)\n-----------------------")
    }
}

struct MarketingEngine_Preview: View {
    @State private var segment: ClientSegment = .atRiskClients
    @State private var messageBody: String = NSLocalizedString("Hi {clientName}! We've missed you and {petName}. Come back for your next groom and get 15% off!", comment: "Default marketing message body")
    @State private var targetedClientCount: Int = 0
    @State private var isSending = false
    @State private var sendResult: MarketingEngine.CampaignResult?
    @State private var auditLog: [String] = []
    @State private var auditDiagnostics: String = ""

    private var marketingEngine = MarketingEngine(messagingService: MockMessagingService())

    var body: some View {
        Form {
            Section(header: Text(NSLocalizedString("Campaign Details", comment: "Section header"))) {
                Picker(NSLocalizedString("Target Segment", comment: "Picker label"), selection: $segment) {
                    Text(NSLocalizedString("At-Risk Clients", comment: "Picker option")).tag(ClientSegment.atRiskClients)
                    Text(NSLocalizedString("New Clients", comment: "Picker option")).tag(ClientSegment.newClients)
                    Text(NSLocalizedString("Top 3 Spenders", comment: "Picker option")).tag(ClientSegment.topSpenders(count: 3))
                }
                TextEditor(text: $messageBody)
                    .frame(height: 100)
            }

            Section(header: Text(NSLocalizedString("Preview & Send", comment: "Section header"))) {
                Text(String(format: NSLocalizedString("Targets %d clients.", comment: "Preview target count"), targetedClientCount))
                    .font(.caption)

                Button(action: sendCampaign) {
                    HStack {
                        if isSending { ProgressView() }
                        Text(NSLocalizedString("Send Campaign", comment: "Send button label"))
                    }
                }
                .disabled(isSending)
                if let result = sendResult {
                    Text(String(format: NSLocalizedString("Sent: %d, Failed: %d", comment: "Send result summary"), result.sentCount, result.failedCount))
                        .font(.caption)
                }
            }
            Section(header: Text(NSLocalizedString("Audit Trail", comment: "Section header"))) {
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(auditLog, id: \.self) { log in
                            Text(log).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            Section(header: Text("Diagnostics (Trust Center)")) {
                ScrollView {
                    Text(auditDiagnostics)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                        .frame(maxHeight: 200)
                }
            }
        }
        .onAppear { fetchTargetCount() }
        .onChange(of: segment, initial: true) { _, _ in fetchTargetCount() }
        .navigationTitle(NSLocalizedString("Marketing", comment: "Navigation title"))
    }

    func fetchTargetCount() {
        Task {
            let clients = await marketingEngine.fetchClients(for: segment)
            targetedClientCount = clients.count > 0 ? clients.count : Int.random(in: 2...5)
        }
    }

    func sendCampaign() {
        isSending = true
        marketingEngine.testMode = true // Enable test mode for preview to simulate analytics
        let campaign = MarketingCampaign(id: UUID(), name: NSLocalizedString("Re-engagement", comment: "Campaign name"), subject: NSLocalizedString("We miss you!", comment: "Campaign subject"), bodyTemplate: messageBody)
        Task {
            let clients = await marketingEngine.fetchClients(for: segment)
            let result = await marketingEngine.send(campaign: campaign, to: clients, segment: segment, maxRetry: 2, throttleMilliseconds: 100)
            sendResult = result
            auditLog = marketingEngine.lastAuditLog
            auditDiagnostics = marketingEngine.diagnosticsAuditTrail()
            isSending = false
        }
    }
}

#Preview {
    NavigationView {
        MarketingEngine_Preview()
    }
}
#endif

//
//  MarketingEngine.swift
//  Furfolio
//
//  Enhanced: Audit, campaign tagging, analytics, accessibility, retry, and export.
//  Author: mac + ChatGPT
//

import Foundation

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
        "\(name). \(subject). \(badges.map { $0.rawValue.capitalized }.joined(separator: \", \"))."
    }
    func exportJSON() -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
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
        case .allClients: "All Clients"
        case .newClients: "New Clients"
        case .atRiskClients: "At-Risk Clients"
        case .inactiveClients: "Inactive Clients"
        case .topSpenders(let count): "Top \(count) Spenders"
        case .loyaltyStars: "Loyalty Stars"
        case .ownersOfBreed(let breed): "Owners of \(breed)"
        }
    }
}

// MARK: - Messaging Service Protocol

protocol MessagingService {
    func send(message: String, to contact: String) async throws
}

// MARK: - Main Enhanced Engine

@MainActor
final class MarketingEngine: ObservableObject {
    private let retentionAnalyzer: CustomerRetentionAnalyzer
    private let revenueAnalyzer: RevenueAnalyzer
    private let dataStore: DataStoreService
    private let messagingService: MessagingService

    // Audit and analytics
    @Published var lastAuditLog: [String] = []
    @Published var lastCampaignResult: CampaignResult?
    @Published var isSending: Bool = false

    struct CampaignResult: Codable {
        let campaignID: UUID
        let sentCount: Int
        let failedCount: Int
        let targetCount: Int
        let failedRecipients: [String]
        let sentAt: Date
        let segment: ClientSegment
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

    /// Sends a marketing campaign to a list of clients, with audit, retry, and analytics.
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

        addAudit("Begin campaign '\(campaign.name)' (\(campaign.subject)) to \(total) clients (\(segment.displayName)).")

        for client in clients {
            guard let contactEmail = client.email, !contactEmail.isEmpty else {
                failedCount += 1
                failedRecipients.append(client.ownerName)
                addAudit("Skipped client \(client.ownerName): no email.")
                continue
            }

            let petName = client.dogs.first?.name ?? "your pet"
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
                    addAudit("Failed to send to \(contactEmail) (attempt \(attempts)): \(error)")
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
            campaignID: campaign.id, sentCount: sentCount, failedCount: failedCount, targetCount: total,
            failedRecipients: failedRecipients, sentAt: Date(), segment: segment)
        lastCampaignResult = result
        addAudit("Campaign '\(campaign.name)' complete. \(sentCount) sent, \(failedCount) failed.")
        return result
    }

    // MARK: - Audit, Analytics, Export

    func addAudit(_ entry: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        lastAuditLog.append("[\(ts)] \(entry)")
        if lastAuditLog.count > 1000 { lastAuditLog.removeFirst() }
    }

    /// Export the most recent campaign result as JSON.
    func exportLastCampaignResult() -> String? {
        guard let last = lastCampaignResult else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return try? encoder.encode(last).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for latest campaign (for dashboards, VoiceOver)
    var accessibilitySummary: String {
        guard let last = lastCampaignResult else { return "No campaign sent yet." }
        return "Campaign sent to \(last.sentCount) of \(last.targetCount) clients. \(last.failedCount) failed. Segment: \(last.segment.displayName)."
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct MockMessagingService: MessagingService {
    func send(message: String, to contact: String) async throws {
        // Randomly throw to simulate error
        if Bool.random() { throw NSError(domain: "SendError", code: 1) }
        print("--- Sending Message ---\nTo: \(contact)\nBody: \(message)\n-----------------------")
    }
}

struct MarketingEngine_Preview: View {
    @State private var segment: ClientSegment = .atRiskClients
    @State private var messageBody: String = "Hi {clientName}! We've missed you and {petName}. Come back for your next groom and get 15% off!"
    @State private var targetedClientCount: Int = 0
    @State private var isSending = false
    @State private var sendResult: MarketingEngine.CampaignResult?
    @State private var auditLog: [String] = []

    private var marketingEngine = MarketingEngine(messagingService: MockMessagingService())

    var body: some View {
        Form {
            Section("Campaign Details") {
                Picker("Target Segment", selection: $segment) {
                    Text("At-Risk Clients").tag(ClientSegment.atRiskClients)
                    Text("New Clients").tag(ClientSegment.newClients)
                    Text("Top 3 Spenders").tag(ClientSegment.topSpenders(count: 3))
                }
                TextEditor(text: $messageBody)
                    .frame(height: 100)
            }

            Section("Preview & Send") {
                Text("Targets \(targetedClientCount) clients.").font(.caption)

                Button(action: sendCampaign) {
                    HStack {
                        if isSending { ProgressView() }
                        Text("Send Campaign")
                    }
                }
                .disabled(isSending)
                if let result = sendResult {
                    Text("Sent: \(result.sentCount), Failed: \(result.failedCount)")
                        .font(.caption)
                }
            }
            Section("Audit Trail") {
                ForEach(auditLog, id: \.self) { log in
                    Text(log).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .onAppear { fetchTargetCount() }
        .onChange(of: segment, initial: true) { _, _ in fetchTargetCount() }
        .navigationTitle("Marketing")
    }

    func fetchTargetCount() {
        Task {
            let clients = await marketingEngine.fetchClients(for: segment)
            targetedClientCount = clients.count > 0 ? clients.count : Int.random(in: 2...5)
        }
    }
    func sendCampaign() {
        isSending = true
        let campaign = MarketingCampaign(id: UUID(), name: "Re-engagement", subject: "We miss you!", bodyTemplate: messageBody)
        Task {
            let clients = await marketingEngine.fetchClients(for: segment)
            let result = await marketingEngine.send(campaign: campaign, to: clients, segment: segment)
            sendResult = result
            auditLog = marketingEngine.lastAuditLog
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

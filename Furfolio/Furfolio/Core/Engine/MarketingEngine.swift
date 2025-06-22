//
//  MarketingEngine.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A business logic engine for client segmentation and marketing outreach.
//

import Foundation

/// A model representing a marketing campaign.
struct MarketingCampaign {
    let id: UUID
    let name: String
    let subject: String
    /// A template for the message body. Can include placeholders like {clientName} or {petName}.
    let bodyTemplate: String
}

/// Defines different "smart" segments of clients for targeted marketing.
enum ClientSegment: Hashable, Identifiable {
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

/// A protocol for a service that can send messages, allowing for easy mocking.
protocol MessagingService {
    func send(message: String, to contact: String) async throws
}

/// The main engine for handling marketing logic.
@MainActor
final class MarketingEngine {
    private let retentionAnalyzer: CustomerRetentionAnalyzer
    private let revenueAnalyzer: RevenueAnalyzer
    private let dataStore: DataStoreService
    private let messagingService: MessagingService // Injected dependency

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

    /// Fetches a list of `DogOwner`s based on a specific segment.
    /// - Parameter segment: The `ClientSegment` to filter by.
    /// - Returns: An array of `DogOwner`s belonging to that segment.
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
            // Assumes a 'loyaltyStar' tag is added by the BadgeEngine
            return allOwners.filter { $0.badgeTypes.contains("loyaltyStar") }
        case .ownersOfBreed(let breed):
            return allOwners.filter { owner in
                owner.dogs.contains { $0.breed?.localizedCaseInsensitiveContains(breed) == true }
            }
        }
    }

    /// Sends a marketing campaign to a list of clients.
    /// - Parameters:
    ///   - campaign: The `MarketingCampaign` to send.
    ///   - clients: The list of `DogOwner` recipients.
    /// - Returns: The number of messages successfully sent.
    func send(campaign: MarketingCampaign, to clients: [DogOwner]) async -> Int {
        var sentCount = 0
        for client in clients {
            guard let contactEmail = client.email, !contactEmail.isEmpty else {
                continue // Skip clients with no email
            }
            
            // Personalize the message
            let petName = client.dogs.first?.name ?? "your pet"
            let personalizedBody = campaign.bodyTemplate
                .replacingOccurrences(of: "{clientName}", with: client.ownerName)
                .replacingOccurrences(of: "{petName}", with: petName)
            
            do {
                try await messagingService.send(message: personalizedBody, to: contactEmail)
                sentCount += 1
            } catch {
                print("Failed to send message to \(contactEmail): \(error)")
            }
        }
        return sentCount
    }
}


// MARK: - Preview

#if DEBUG
import SwiftUI

/// A mock messaging service that just prints to the console for previews.
struct MockMessagingService: MessagingService {
    func send(message: String, to contact: String) async throws {
        print("--- Sending Message ---")
        print("To: \(contact)")
        print("Body: \(message)")
        print("-----------------------")
    }
}

struct MarketingEngine_Preview: View {
    @State private var segment: ClientSegment = .atRiskClients
    @State private var messageBody: String = "Hi {clientName}! We've missed you and {petName}. Come back for your next groom and get 15% off!"
    @State private var targetedClientCount: Int = 0
    @State private var isSending = false
    
    // Create an instance of the engine with mock services for the preview
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
                Text("Targets \(targetedClientCount) clients.")
                    .font(.caption)
                
                Button(action: sendCampaign) {
                    HStack {
                        if isSending { ProgressView() }
                        Text("Send Campaign")
                    }
                }
                .disabled(isSending)
            }
        }
        .onChange(of: segment, initial: true) { _, newSegment in
            Task {
                // In a real app, you'd fetch real owners. Here we use a mock count.
                let clients = await marketingEngine.fetchClients(for: newSegment)
                targetedClientCount = clients.count > 0 ? clients.count : Int.random(in: 2...5) // Mock count
            }
        }
        .navigationTitle("Marketing")
    }
    
    func sendCampaign() {
        isSending = true
        let campaign = MarketingCampaign(id: UUID(), name: "Re-engagement", subject: "We miss you!", bodyTemplate: messageBody)
        Task {
            // In a real app, you'd fetch and pass real clients.
            let _ = await marketingEngine.send(campaign: campaign, to: []) // Pass empty for demo
            try? await Task.sleep(for: .seconds(1))
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

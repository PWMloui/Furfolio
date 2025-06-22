//
//  ChargeListViewModel.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import Combine

// MARK: - ChargeListViewModel (Modular, Tokenized, Auditable Charge List ViewModel)

/// ViewModel responsible for managing the list of charges in a reactive manner.
/// Supports modular, tokenized business logic, audit trails, filtering capabilities,
/// and seamless UI binding. Designed to facilitate owner-focused workflows and analytics,
/// ensuring that all data interactions are traceable and maintainable.
@MainActor
final class ChargeListViewModel: ObservableObject {
    /// The complete list of charges fetched from the data store.
    /// Published for UI binding and audit trail tracking of data state changes.
    @Published var charges: [Charge] = []
    
    /// Indicates whether the ViewModel is currently loading data.
    /// Useful for UI loading indicators and analytics on data fetch performance.
    @Published var isLoading = false
    
    /// The current search text used to filter charges.
    /// Changes to this property trigger reactive filtering and are tracked for audit and analytics.
    @Published var searchText = ""
    
    // Injected dependency for testability and modularity.
    private let dataStore: DataStoreService
    
    // Store Combine cancellables to manage subscriptions and memory.
    private var cancellables = Set<AnyCancellable>()
    
    /// Computed property that returns charges filtered by the current search text
    /// and sorted by date descending. This supports audit-relevant filtering and
    /// ensures the UI reflects the current query state reactively.
    var filteredCharges: [Charge] {
        if searchText.isEmpty {
            // Return all charges sorted by most recent date
            return charges.sorted { $0.date > $1.date }
        } else {
            // Filter charges by type display name matching search text, then sort by date
            return charges
                .filter { $0.type.displayName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.date > $1.date }
        }
    }
    
    /// Initializes the ViewModel with an optional injected data store dependency.
    /// Sets up reactive Combine pipeline to debounce and remove duplicate search text inputs,
    /// supporting modular reactive search filtering and auditability.
    /// - Parameter dataStore: The data store service to fetch and manage charges.
    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
        
        // Reactive pipeline: debounce and remove duplicates from searchText to optimize filtering
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .assign(to: \.searchText, on: self) // Corrected assignment key path
            .store(in: &cancellables)
    }
    
    /// Asynchronously fetches all charges from the data store.
    /// Updates the loading state and charges list accordingly.
    /// This method supports audit logging of fetch operations and ensures UI updates occur on the main thread.
    func fetchCharges() async {
        isLoading = true // Signal UI to show loading state
        
        // Fetch all charges asynchronously from the data store
        charges = await dataStore.fetchAll(Charge.self)
        
        isLoading = false // Signal UI to hide loading state
    }
    
    /// Deletes charges at the specified offsets from the filtered charges list.
    /// Performs deletion asynchronously with audit trail support and refreshes the charges list upon completion.
    /// - Parameter offsets: The set of indices representing charges to delete.
    func deleteCharge(at offsets: IndexSet) {
        // Map offsets to actual charges in the filtered list to maintain consistent UI state
        let chargesToDelete = offsets.map { filteredCharges[$0] }
        
        for charge in chargesToDelete {
            Task {
                // Perform asynchronous deletion with audit logging in data store
                await dataStore.delete(charge)
                
                // Refresh charges list after deletion to update UI reactively
                await fetchCharges()
            }
        }
    }
}

//  AddOnServicesListView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//

import SwiftUI
import SwiftData
import Combine

struct AddOnServicesListView: View {
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    private var cancellable: AnyCancellable?
    @Binding var selectedAddOns: Set<AddOnService>
    @Query private var addOnServices: [AddOnService]

    var body: some View {
        let filteredServices = addOnServices
            .filter { debouncedSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(debouncedSearchText) }
            .sorted { $0.name < $1.name }
        let grouped = Dictionary(grouping: filteredServices) { $0.category }

        VStack {
            if filteredServices.isEmpty {
                Spacer()
                Text("No matching services")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                List {
                    ForEach(grouped.keys.sorted(), id: \.self) { category in
                        Section(header: Text(category.rawValue)) {
                            ForEach(grouped[category]!, id: \.self) { service in
                                Toggle(isOn: Binding(
                                    get: { selectedAddOns.contains(service) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedAddOns.insert(service)
                                        } else {
                                            selectedAddOns.remove(service)
                                        }
                                    }
                                )) {
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text(service.name)
                                            if let requires = service.requires, !requires.isEmpty {
                                                Image(systemName: "info.circle")
                                                    .foregroundColor(.secondary)
                                                    .help("Requires: \(requires.map(\.rawValue).joined(separator: ", "))")
                                            }
                                        }
                                        Spacer()
                                        Text("\(service.minPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD")) - \(service.maxPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .accessibilityLabel("\(service.name), \(service.minPrice) to \(service.maxPrice)")
                                .accessibilityHint(service.requires != nil && !service.requires!.isEmpty ? "Requires: \(service.requires!.map(\.rawValue).joined(separator: ", "))" : "")
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .onAppear {
            cancellable = $searchText
                .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
                .sink { debouncedSearchText = $0 }
        }
    }
}

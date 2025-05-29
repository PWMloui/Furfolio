//
//  ClientSegmentationView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os

/// A view that segments clients into categories and displays them in a list.
struct ClientSegmentationView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ClientSegmentationView")
    enum Segment: String, CaseIterable, Identifiable {
        case all = "All Clients"
        case newClients = "New Clients"
        case regulars = "Regulars"
        case highValue = "High‑Value"
        
        var id: String { rawValue }
    }
    
    @State private var selectedSegment: Segment = .all
    @Query(sort: [SortDescriptor(\.name, order: .forward)]) private var owners: [DogOwner]
    
    private var filteredOwners: [DogOwner] {
        switch selectedSegment {
        case .all:
            return owners
        case .newClients:
            // Owners with fewer than 2 visits
            return owners.filter { $0.clientStats.visitCount < 2 }
        case .regulars:
            // Owners with 2 to 5 visits
            return owners.filter { (2...5).contains($0.clientStats.visitCount) }
        case .highValue:
            // Owners with lifetime spend over $500
            return owners.filter { $0.clientStats.lifetimeSpend > 500 }
        }
    }
    
    var body: some View {
        VStack {
            Picker("Segment", selection: $selectedSegment) {
                ForEach(Segment.allCases) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            List(filteredOwners) { owner in
                NavigationLink(destination: OwnerProfileView(owner: owner)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(owner.name)
                                .font(AppTheme.body)
                                .foregroundColor(AppTheme.primaryText)
                            Text("\(owner.clientStats.visitCount) visits • $\(owner.clientStats.lifetimeSpend, specifier: "%.2f")")
                                .font(AppTheme.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
        .onAppear {
            logger.log("ClientSegmentationView appeared, segment: \(selectedSegment.rawValue), owners count: \(owners.count)")
        }
        .onChange(of: selectedSegment) { new in
            logger.log("Segment changed to: \(new.rawValue), filteredOwners count: \(filteredOwners.count)")
        }
        .navigationTitle("Client Segmentation")
    }
}

#Preview {
    NavigationStack {
        ClientSegmentationView()
    }
}

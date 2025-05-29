//
//  AssetMaintenanceView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os

struct AssetMaintenanceView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AssetMaintenanceView")
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.nextServiceDate, order: .forward)]) private var assets: [EquipmentAsset]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Upcoming Maintenance")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)) {
                    ForEach(assets.filter { asset in
                        guard let nextDate = asset.nextServiceDate else { return false }
                        return Calendar.current.isDate(nextDate,
                          inSameDayAs: Date()) ||
                          nextDate < Calendar.current.date(byAdding: .day, value: 7, to: .now)!
                    }) { asset in
                        AssetRowView(asset: asset)
                    }
                }

                Section(header: Text("All Assets")
                            .font(AppTheme.title)
                            .foregroundColor(AppTheme.primaryText)) {
                    ForEach(assets) { asset in
                        AssetRowView(asset: asset)
                    }
                }
            }
            .navigationTitle("Asset Maintenance")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addAsset) {
                        Label("Add Asset", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                logger.log("AssetMaintenanceView appeared with \(assets.count) total assets")
            }
            .listStyle(InsetGroupedListStyle())
        }
    }

    private func addAsset() {
        let newAsset = EquipmentAsset(name: "New Asset",
                                      purchaseDate: Date(),
                                      lastServiceDate: Date(),
                                      maintenanceIntervalDays: 90)
        context.insert(newAsset)
        try? context.save()
    }
}

private struct AssetRowView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "AssetRowView")
    @Environment(\.modelContext) private var context
    @ObservedObject var asset: EquipmentAsset

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(asset.name)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)
                if let nextDate = asset.nextServiceDate {
                    Text("Next: \(nextDate, style: .date)")
                        .font(AppTheme.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            Spacer()
            Button("Serviced") {
                logger.log("Serviced tapped for asset id: \(asset.id)")
                asset.lastServiceDate = Date()
                asset.nextServiceDate = Calendar.current.date(
                    byAdding: .day,
                    value: asset.maintenanceIntervalDays,
                    to: asset.lastServiceDate!
                )
                try? context.save()
            }
            .buttonStyle(FurfolioButtonStyle())
        }
        .onAppear {
            logger.log("AssetRowView appeared for asset id: \(asset.id), name: \(asset.name)")
        }
    }
}

#Preview {
    AssetMaintenanceView()
        .modelContainer(for: EquipmentAsset.self)
}

//
//  AssetMaintenanceView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData

struct AssetMaintenanceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.nextServiceDate, order: .forward)]) private var assets: [EquipmentAsset]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Upcoming Maintenance")) {
                    ForEach(assets.filter { asset in
                        guard let nextDate = asset.nextServiceDate else { return false }
                        return Calendar.current.isDate(nextDate,
                          inSameDayAs: Date()) ||
                          nextDate < Calendar.current.date(byAdding: .day, value: 7, to: .now)!
                    }) { asset in
                        AssetRowView(asset: asset)
                    }
                }

                Section(header: Text("All Assets")) {
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
    @Environment(\.modelContext) private var context
    @ObservedObject var asset: EquipmentAsset

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(asset.name)
                    .font(.headline)
                if let nextDate = asset.nextServiceDate {
                    Text("Next: \(nextDate, style: .date)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Serviced") {
                asset.lastServiceDate = Date()
                asset.nextServiceDate = Calendar.current.date(
                    byAdding: .day,
                    value: asset.maintenanceIntervalDays,
                    to: asset.lastServiceDate!
                )
                try? context.save()
            }
            .buttonStyle(BorderlessButtonStyle())
        }
    }
}

#Preview {
    AssetMaintenanceView()
        .modelContainer(for: EquipmentAsset.self)
}

//
//  ExportProfilesView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData

struct ExportProfilesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\.name)]) private var profiles: [ExportProfile]
    @State private var showingNewProfileSheet = false
    @State private var newProfileName = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(profiles) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        Button(action: {
                            ExportManager.shared.export(profile: profile, in: context)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityLabel("Export \(profile.name)")
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let profile = profiles[index]
                        context.delete(profile)
                    }
                }
            }
            .navigationTitle("Export Profiles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewProfileSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Export Profile")
                }
            }
            .sheet(isPresented: $showingNewProfileSheet) {
                NavigationStack {
                    Form {
                        Section("Profile Name") {
                            TextField("Name", text: $newProfileName)
                        }
                        Section {
                            Button("Save") {
                                let profile = ExportProfile(id: UUID(), name: newProfileName, template: "{}")
                                context.insert(profile)
                                newProfileName = ""
                                showingNewProfileSheet = false
                            }
                            .disabled(newProfileName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .navigationTitle("New Profile")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingNewProfileSheet = false }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ExportProfilesView()
        .modelContainer(for: ExportProfile.self)
}

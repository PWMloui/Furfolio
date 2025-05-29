//
//  ExportProfilesView.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

import SwiftUI
import SwiftData
import os

struct ExportProfilesView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ExportProfilesView")
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
                            logger.log("Export button tapped for profile: \(profile.name)")
                            ExportManager.shared.export(profile: profile, in: context)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .accessibilityLabel("Export \(profile.name)")
                        }
                        .buttonStyle(FurfolioButtonStyle())
                    }
                    .onAppear {
                        logger.log("Displaying export profile: \(profile.name)")
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let profile = profiles[index]
                        context.delete(profile)
                    }
                }
            }
            .onAppear {
                logger.log("ExportProfilesView appeared with \(profiles.count) profiles")
            }
            .navigationTitle("Export Profiles")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        logger.log("Add Export Profile button tapped")
                        showingNewProfileSheet = true
                    }) {
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
                                logger.log("Saving new export profile: \(newProfileName)")
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
                            Button("Cancel") {
                                logger.log("New Profile sheet canceled")
                                showingNewProfileSheet = false
                            }
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

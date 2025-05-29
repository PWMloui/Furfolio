//
//  ReportBuilder.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import SwiftUI
import SwiftData
import os

/// Model for saving export templates
@Model
final class ExportProfile: Identifiable {
    @Attribute var id: UUID
    @Attribute var name: String
    @Attribute var includeAppointments: Bool
    @Attribute var includeCharges: Bool
    @Attribute var includeExpenses: Bool
    @Attribute var includeInventory: Bool
    @Attribute var createdAt: Date

    init(name: String,
         includeAppointments: Bool,
         includeCharges: Bool,
         includeExpenses: Bool,
         includeInventory: Bool) {
        self.id = UUID()
        self.name = name
        self.includeAppointments = includeAppointments
        self.includeCharges = includeCharges
        self.includeExpenses = includeExpenses
        self.includeInventory = includeInventory
        self.createdAt = Date()
    }
}

class ReportBuilderViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var includeAppointments: Bool = true
    @Published var includeCharges: Bool = true
    @Published var includeExpenses: Bool = false
    @Published var includeInventory: Bool = false

    func save(in context: ModelContext) {
        let profile = ExportProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            includeAppointments: includeAppointments,
            includeCharges: includeCharges,
            includeExpenses: includeExpenses,
            includeInventory: includeInventory
        )
        context.insert(profile)
    }
}

struct ReportBuilderView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ReportBuilderView")

    @Environment(\.modelContext) private var context
    @StateObject private var vm = ReportBuilderViewModel()
    @Query(
        sort: [SortDescriptor<ExportProfile>(\.createdAt, order: .reverse)]
    )
    private var profiles: [ExportProfile]

    @State private var profileToDelete: ExportProfile?
    @State private var showingSaveAlert = false

    public init() {}

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Name") {
                    TextField("Name", text: $vm.name)
                }
                Section("Include Data") {
                    Toggle("Appointments", isOn: $vm.includeAppointments)
                    Toggle("Charges", isOn: $vm.includeCharges)
                    Toggle("Expenses", isOn: $vm.includeExpenses)
                    Toggle("Inventory", isOn: $vm.includeInventory)
                }
                Button("Save Template") {
                    vm.save(in: context)
                    vm.name = ""
                    showingSaveAlert = true
                    logger.log("Saved export template '\(vm.name)'")
                }
                .disabled(vm.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .alert("Template Saved", isPresented: $showingSaveAlert) {
                    Button("OK") {
                        logger.log("Template Saved alert dismissed")
                    }
                } message: {
                    Text("Your export template has been saved.")
                }
                Section("Saved Templates") {
                    List {
                        ForEach(profiles) { profile in
                            VStack(alignment: .leading) {
                                Text(profile.name).font(.headline)
                                HStack {
                                    if profile.includeAppointments { Text("🗓") }
                                    if profile.includeCharges { Text("💰") }
                                    if profile.includeExpenses { Text("📄") }
                                    if profile.includeInventory { Text("📦") }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    profileToDelete = profile
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indices in
                            for i in indices {
                                context.delete(profiles[i])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Report Builder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .confirmationDialog("Delete this template?", unwrapping: $profileToDelete, actions: { profile in
                Button("Delete", role: .destructive) {
                    context.delete(profile)
                }
            }, message: { profile in
                Text("Are you sure you want to delete \"\(profile.name)\"?")
            })
        }
    }
}

#Preview {
    ReportBuilderView()
        .modelContainer(for: ExportProfile.self)
}

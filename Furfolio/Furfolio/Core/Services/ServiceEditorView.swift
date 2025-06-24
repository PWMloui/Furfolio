//
//  ServiceEditorView.swift
//  Furfolio
//
//  Created by senpai on 6/23/25.
//

import SwiftUI

/// A view to create or edit a grooming service (e.g., "Full Groom," "Nail Trim").
struct ServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // If editing an existing service, populate the fields
    @Binding var service: Service

    // Validation/error state
    @State private var showValidationAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Service Details")) {
                    TextField("Service Name", text: $service.name)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Service Name")

                    TextField("Description (optional)", text: $service.description)
                        .accessibilityLabel("Service Description")

                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("0", value: $service.price, formatter: currencyFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .accessibilityLabel("Service Price")
                    }

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $service.durationMinutes) {
                            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                        .accessibilityLabel("Service Duration")
                    }
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $service.notes)
                        .frame(height: 80)
                        .accessibilityLabel("Service Notes")
                }
            }
            .navigationTitle(service.id == nil ? "Add Service" : "Edit Service")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if service.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            showValidationAlert = true
                        } else {
                            // Save service logic here—call ViewModel, context, or callback
                            dismiss()
                        }
                    }
                    .disabled(service.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Service name cannot be empty.", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            }
            .background(AppTheme.color.background)
        }
    }

    // Currency formatter for price
    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        formatter.minimumFractionDigits = 0
        return formatter
    }
}

// MARK: - Service Model (for demo, adapt if you have one)
struct Service: Identifiable, Equatable {
    var id: UUID? = nil // Use UUID or Int or let database assign
    var name: String = ""
    var description: String = ""
    var price: Double = 0
    var durationMinutes: Int = 60
    var notes: String = ""
}

// MARK: - Preview
#if DEBUG
struct ServiceEditorView_Previews: PreviewProvider {
    @State static var demoService = Service(
        id: UUID(),
        name: "Full Groom",
        description: "Full grooming package for all breeds.",
        price: 85,
        durationMinutes: 90,
        notes: "Include deshedding."
    )

    static var previews: some View {
        ServiceEditorView(service: $demoService)
            .previewDisplayName("Edit Service")
    }
}
#endif

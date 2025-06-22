//
//  AddDogOwnerView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct AddDogOwnerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ownerName: String = ""
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var address: String = ""
    @State private var showAlert: Bool = false

    var onSave: ((String, String, String, String) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Owner Details")) {
                    TextField("Owner Name", text: $ownerName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)

                    TextField("Address", text: $address)
                        .textContentType(.fullStreetAddress)
                }
            }
            .navigationTitle("Add Dog Owner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if ownerName.trimmingCharacters(in: .whitespaces).isEmpty {
                            showAlert = true
                        } else {
                            onSave?(ownerName, phoneNumber, email, address)
                            dismiss()
                        }
                    }
                    .disabled(ownerName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Owner name is required.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }
}

#Preview {
    AddDogOwnerView()
}

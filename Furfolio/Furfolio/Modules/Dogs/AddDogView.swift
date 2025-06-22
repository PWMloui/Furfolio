//
//  AddDogView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DogData {
    var name: String = ""
    var breed: String = ""
    var birthdate: Date = Date()
    var notes: String = ""
}

struct AddDogView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var dogData = DogData()

    var onSave: ((DogData) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dog Information")) {
                    TextField("Name", text: $dogData.name)
                        .accessibilityLabel("Dog Name")
                        .autocapitalization(.words)
                    TextField("Breed", text: $dogData.breed)
                        .accessibilityLabel("Dog Breed")
                        .autocapitalization(.words)
                    DatePicker("Birthdate", selection: $dogData.birthdate, displayedComponents: .date)
                        .accessibilityLabel("Dog Birthdate")
                }

                Section(header: Text("Notes")) {
                    TextEditor(text: $dogData.notes)
                        .frame(minHeight: 100)
                        .accessibilityLabel("Dog Notes")
                }
            }
            .navigationTitle("Add Dog")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave?(dogData)
                        dismiss()
                    }
                    .disabled(dogData.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#if DEBUG
struct AddDogView_Previews: PreviewProvider {
    static var previews: some View {
        AddDogView(onSave: { dog in
            print("Saved dog: \(dog.name)")
        })
    }
}
#endif

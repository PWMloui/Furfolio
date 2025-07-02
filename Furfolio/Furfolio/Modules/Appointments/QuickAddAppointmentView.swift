//
//  QuickAddAppointmentView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - QuickAddAppointmentView

struct QuickAddAppointmentView: View {
    // Required bindings for data sources and callback
    @Binding var isPresented: Bool
    var owners: [DogOwner]
    var services: [String]
    var onAdd: (Appointment) -> Void

    // Local state for the form
    @State private var selectedOwner: DogOwner?
    @State private var selectedDog: Dog?
    @State private var selectedService: String = ""
    @State private var date: Date = Date()
    @State private var duration: Int = 60
    @State private var notes: String = ""
    @State private var showToast = false

    var body: some View {
        NavigationView {
            Form {
                // Owner
                Section(header: Text("Owner")) {
                    Picker("Select Owner", selection: $selectedOwner) {
                        Text("Choose...").tag(DogOwner?.none)
                        ForEach(owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .onChange(of: selectedOwner) { owner in
                        selectedDog = nil // reset dog if owner changes
                    }
                }
                // Dog
                if let dogs = selectedOwner?.dogs, !dogs.isEmpty {
                    Section(header: Text("Dog")) {
                        Picker("Select Dog", selection: $selectedDog) {
                            Text("Choose...").tag(Dog?.none)
                            ForEach(dogs) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                    }
                }
                // Service
                Section(header: Text("Service")) {
                    Picker("Service", selection: $selectedService) {
                        Text("Choose...").tag("")
                        ForEach(services, id: \.self) { svc in
                            Text(svc).tag(svc)
                        }
                    }
                }
                // Date & Time
                Section(header: Text("Date & Time")) {
                    DatePicker("Date", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                }
                // Duration
                Section(header: Text("Duration")) {
                    Stepper("\(duration) min", value: $duration, in: 15...180, step: 5)
                }
                // Notes
                Section(header: Text("Notes (optional)")) {
                    TextField("Notes", text: $notes)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle("Quick Add")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let owner = selectedOwner, let dog = selectedDog, !selectedService.isEmpty else { return }
                        let newAppointment = Appointment(
                            id: UUID(),
                            date: date,
                            owner: owner,
                            dog: dog,
                            serviceType: selectedService,
                            duration: duration,
                            notes: notes.isEmpty ? nil : notes,
                            tags: []
                        )
                        onAdd(newAppointment)
                        showToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            isPresented = false
                        }
                    }
                    .disabled(selectedOwner == nil || selectedDog == nil || selectedService.isEmpty)
                }
            }
            .overlay(
                Group {
                    if showToast {
                        Text("Appointment Added!")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.green.opacity(0.8)))
                            .foregroundColor(.white)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }, alignment: .top
            )
        }
    }
}

// MARK: - Models (Sample/Replace with actual app models)

struct Appointment: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var owner: DogOwner
    var dog: Dog
    var serviceType: String
    var duration: Int
    var notes: String?
    var tags: [String]
}

struct DogOwner: Identifiable, Hashable, Equatable {
    var id: UUID
    var ownerName: String
    var dogs: [Dog]?
}

struct Dog: Identifiable, Hashable, Equatable {
    var id: UUID
    var name: String
    var owner: DogOwner? = nil
}

// MARK: - Preview

#if DEBUG
struct QuickAddAppointmentView_Previews: PreviewProvider {
    static var previews: some View {
        let dog = Dog(id: UUID(), name: "Rex")
        let owner = DogOwner(id: UUID(), ownerName: "Joe Smith", dogs: [dog])
        QuickAddAppointmentView(
            isPresented: .constant(true),
            owners: [owner],
            services: ["Full Groom", "Bath Only", "Nail Trim"]
        ) { appt in
            print("Appointment: \(appt)")
        }
    }
}
#endif

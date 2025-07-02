//
//  AppointmentChecklistView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import SwiftUI

/// Represents a single checklist item with its state and optional notes.
struct ChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    var isCompleted: Bool = false
    var notes: String = ""
    var showNotes: Bool = false
}

/// Represents an audit log entry for checklist actions.
struct AuditLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let appointmentID: UUID
    let itemTitle: String
    let action: String
}

/// Represents an appointment model.
struct Appointment {
    let id: UUID
    let type: AppointmentType
}

/// Defines appointment types for prefilling checklist.
enum AppointmentType {
    case grooming
    case nailTrim
    case checkIn
    case other
}

/// The main view displaying the appointment checklist.
struct AppointmentChecklistView: View {
    /// The appointment model, optional for add/edit use.
    let appointment: Appointment?
    
    /// The list of checklist items displayed and managed in the view.
    @State private var checklistItems: [ChecklistItem] = []
    
    /// The audit log entries tracking checklist actions.
    @State private var auditLog: [AuditLogEntry] = []
    
    /// Initializes the checklist based on appointment type.
    private func initializeChecklist() {
        var baseItems = [
            ChecklistItem(title: "Confirm appointment time"),
            ChecklistItem(title: "Check vaccination records"),
            ChecklistItem(title: "Brush coat"),
            ChecklistItem(title: "Trim nails"),
            ChecklistItem(title: "Clean ears"),
            ChecklistItem(title: "Perform health check"),
            ChecklistItem(title: "Confirm pickup/notes")
        ]
        
        // Prefill checklist based on appointment type
        if let type = appointment?.type {
            switch type {
            case .nailTrim:
                // Omit brush coat and clean ears for nail trim
                baseItems.removeAll(where: { $0.title == "Brush coat" || $0.title == "Clean ears" })
            case .checkIn:
                // For check-in, keep all items
                break
            case .grooming:
                // For grooming, keep all items
                break
            case .other:
                // For other types, keep all items
                break
            }
        }
        
        checklistItems = baseItems
    }
    
    /// Logs an action in the audit log with timestamp, appointment ID, and item title.
    private func logAction(itemTitle: String, action: String) {
        guard let appointmentID = appointment?.id else { return }
        let entry = AuditLogEntry(timestamp: Date(), appointmentID: appointmentID, itemTitle: itemTitle, action: action)
        auditLog.append(entry)
    }
    
    /// Marks all checklist items as complete and logs the actions.
    private func markAllComplete() {
        for index in checklistItems.indices {
            if !checklistItems[index].isCompleted {
                checklistItems[index].isCompleted = true
                logAction(itemTitle: checklistItems[index].title, action: "Marked Complete")
            }
        }
    }
    
    /// Computes the number of completed checklist items.
    private var completedCount: Int {
        checklistItems.filter { $0.isCompleted }.count
    }
    
    /// The total number of checklist items.
    private var totalCount: Int {
        checklistItems.count
    }
    
    var body: some View {
        VStack {
            // List of checklist items
            List {
                ForEach($checklistItems) { $item in
                    VStack(alignment: .leading) {
                        HStack {
                            Button(action: {
                                item.isCompleted.toggle()
                                logAction(itemTitle: item.title, action: item.isCompleted ? "Marked Complete" : "Marked Incomplete")
                            }) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .foregroundColor(item.isCompleted ? .green : .primary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Text(item.title)
                                .strikethrough(item.isCompleted, color: .gray)
                                .foregroundColor(item.isCompleted ? .gray : .primary)
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    item.showNotes.toggle()
                                }
                            }) {
                                Image(systemName: item.showNotes ? "chevron.up.circle" : "chevron.down.circle")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        if item.showNotes {
                            TextEditor(text: $item.notes)
                                .frame(minHeight: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                                .padding(.top, 4)
                                .onChange(of: item.notes) { _ in
                                    logAction(itemTitle: item.title, action: "Notes Updated")
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
            
            // Mark All Complete button
            Button(action: {
                markAllComplete()
            }) {
                Text("Mark All Complete")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Summary of completion
            Text("\(completedCount)/\(totalCount) completed")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .navigationTitle("Appointment Checklist")
        .onAppear {
            initializeChecklist()
        }
    }
}

#if DEBUG
struct AppointmentChecklistView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppointmentChecklistView(appointment: Appointment(id: UUID(), type: .grooming))
        }
    }
}
#endif

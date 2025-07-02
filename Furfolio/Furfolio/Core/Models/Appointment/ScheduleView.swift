//
//  ScheduleView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ScheduleTemplateAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ScheduleTemplate"
}

public struct ScheduleTemplateAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let templateID: UUID
    public let templateName: String
    public let services: [String]
    public let status: String
    public let error: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        templateID: UUID,
        templateName: String,
        services: [String],
        status: String,
        error: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.templateID = templateID
        self.templateName = templateName
        self.services = services
        self.status = status
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = "[\(dateStr)] ScheduleTemplate \(operation) [\(status)]"
        let details = [
            "TemplateID: \(templateID)",
            "Name: \(templateName)",
            !services.isEmpty ? "Services: \(services.joined(separator: \", \"))" : nil,
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class ScheduleTemplateAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.scheduletemplate.audit.logger")
    private static var log: [ScheduleTemplateAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        operation: String,
        templateID: UUID,
        templateName: String,
        services: [String],
        status: String,
        error: String? = nil
    ) {
        let escalate = operation.lowercased().contains("danger") || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
            || (error?.lowercased().contains("danger") ?? false)
        let event = ScheduleTemplateAuditEvent(
            timestamp: Date(),
            operation: operation,
            templateID: templateID,
            templateName: templateName,
            services: services,
            status: status,
            error: error,
            role: ScheduleTemplateAuditContext.role,
            staffID: ScheduleTemplateAuditContext.staffID,
            context: ScheduleTemplateAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([ScheduleTemplateAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    public static func exportLogJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(log)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
}

/// Model representing a schedule template.
struct ScheduleTemplate: Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var service: String
    var durationMinutes: Int
    var price: Double
}

/// Observable object to manage the list of schedule templates.
class ScheduleTemplateStore: ObservableObject {
    @Published var templates: [ScheduleTemplate] = [
        // Example data
        ScheduleTemplate(id: UUID(), name: NSLocalizedString("Full Groom", comment: ""), description: NSLocalizedString("Complete grooming service", comment: ""), service: NSLocalizedString("Grooming", comment: ""), durationMinutes: 90, price: 60.0),
        ScheduleTemplate(id: UUID(), name: NSLocalizedString("Bath Only", comment: ""), description: NSLocalizedString("Bath and dry", comment: ""), service: NSLocalizedString("Bath", comment: ""), durationMinutes: 45, price: 30.0)
    ]

    /// Add a new template
    func add(template: ScheduleTemplate) {
        templates.append(template)
        ScheduleTemplateAuditLogger.record(
            operation: "add",
            templateID: template.id,
            templateName: template.name,
            services: [template.service],
            status: "added"
        )
    }

    /// Update an existing template
    func update(template: ScheduleTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
            ScheduleTemplateAuditLogger.record(
                operation: "update",
                templateID: template.id,
                templateName: template.name,
                services: [template.service],
                status: "updated"
            )
        }
    }

    /// Delete a template
    func delete(at offsets: IndexSet) {
        let deletedTemplates = offsets.map { templates[$0] }
        templates.remove(atOffsets: offsets)
        for template in deletedTemplates {
            ScheduleTemplateAuditLogger.record(
                operation: "delete",
                templateID: template.id,
                templateName: template.name,
                services: [template.service],
                status: "deleted"
            )
        }
    }
}

/// View for adding or editing a ScheduleTemplate.
struct ScheduleTemplateEditView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var template: ScheduleTemplate
    var onSave: (ScheduleTemplate) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("Details", comment: ""))) {
                    TextField(NSLocalizedString("Name", comment: ""), text: $template.name)
                    TextField(NSLocalizedString("Description", comment: ""), text: $template.description)
                    TextField(NSLocalizedString("Service", comment: ""), text: $template.service)
                }
                Section(header: Text(NSLocalizedString("Duration & Price", comment: ""))) {
                    Stepper(value: $template.durationMinutes, in: 1...600) {
                        Text(
                            String(format: NSLocalizedString("Duration: %d min", comment: ""), template.durationMinutes)
                        )
                    }
                    TextField(NSLocalizedString("Price", comment: ""), value: $template.price, formatter: NumberFormatter.currency)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(template.id == UUID() ? NSLocalizedString("Add Template", comment: "") : NSLocalizedString("Edit Template", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("Save", comment: "")) {
                        onSave(template)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(template.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Main Schedule View for managing templates.
struct ScheduleView: View {
    @ObservedObject var store: ScheduleTemplateStore = ScheduleTemplateStore()
    @State private var isPresentingEditSheet = false
    @State private var isEditing = false
    @State private var editingTemplate: ScheduleTemplate? = nil
    @State private var searchText: String = ""

    /// Filtered templates based on search text.
    var filteredTemplates: [ScheduleTemplate] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return store.templates }
        return store.templates.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.service.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if filteredTemplates.isEmpty {
                    // Handle empty state gracefully.
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("No Schedule Templates", comment: ""))
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(NSLocalizedString("Tap the plus button to add your first schedule template.", comment: ""))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(filteredTemplates) { template in
                            Button {
                                // Edit template
                                editingTemplate = template
                                isEditing = true
                            } label: {
                                ScheduleTemplateRow(template: template)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle(NSLocalizedString("Schedule Templates", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        editingTemplate = ScheduleTemplate(id: UUID(), name: "", description: "", service: "", durationMinutes: 30, price: 0.0)
                        isEditing = false
                        isPresentingEditSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(NSLocalizedString("Add Template", comment: "")))
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: NSLocalizedString("Search Templates", comment: ""))
            .sheet(isPresented: $isPresentingEditSheet) {
                if let template = editingTemplate {
                    ScheduleTemplateEditView(template: template) { newTemplate in
                        if store.templates.contains(where: { $0.id == newTemplate.id }) {
                            store.update(template: newTemplate)
                        } else {
                            store.add(template: newTemplate)
                        }
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                if let template = editingTemplate {
                    ScheduleTemplateEditView(template: template) { updatedTemplate in
                        store.update(template: updatedTemplate)
                    }
                }
            }
        }
    }

    /// Delete templates from the store.
    private func deleteTemplates(at offsets: IndexSet) {
        // Map offsets from filteredTemplates to original store.templates
        let idsToDelete = offsets.map { filteredTemplates[$0].id }
        store.templates.removeAll { idsToDelete.contains($0.id) }
    }
}

/// Row view for a single schedule template.
struct ScheduleTemplateRow: View {
    let template: ScheduleTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(template.name)
                    .font(.headline)
                Spacer()
                Text(template.service)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            if !template.description.isEmpty {
                Text(template.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(String(format: NSLocalizedString("%d min", comment: ""), template.durationMinutes))
                }
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                    Text(NumberFormatter.currency.string(from: NSNumber(value: template.price)) ?? "")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - NumberFormatter Extension for Currency
extension NumberFormatter {
    static var currency: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// MARK: - Preview
#if DEBUG
struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        ScheduleView(store: ScheduleTemplateStore())
    }
}
#endif

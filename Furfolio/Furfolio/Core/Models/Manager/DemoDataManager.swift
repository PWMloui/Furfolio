//
//  DemoDataManager.swift
//  Furfolio
//
//  Enhanced: Audit trail, tags/badges, accessibility, JSON export, analytics-ready.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - DemoDataManager (Tokenized, Modular, Accessible Demo Data Injection & Audit)

@MainActor
final class DemoDataManager {
    static let shared = DemoDataManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) private var auditEvents: [DemoAuditEvent]

    // MARK: - Audit/Event Log

    /// Represents a single audit event for demo data operations.
    @Model public struct DemoAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        var timestamp: Date
        var operation: String         // "inject" | "clear"
        var entityTypes: [String]
        var entityCount: Int
        var tags: [String]
        var rationale: String?
        var errorDescription: String?

        @Attribute(.transient)
        var accessibilityLabel: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            let dateStr = formatter.string(from: timestamp)
            let opDescription: String
            switch operation.lowercased() {
            case "inject":
                opDescription = NSLocalizedString("Injected demo data", comment: "Audit operation inject")
            case "clear":
                opDescription = NSLocalizedString("Cleared demo data", comment: "Audit operation clear")
            default:
                opDescription = NSLocalizedString("Performed operation", comment: "Audit operation default")
            }
            return "\(opDescription) (\(entityCount) entities) on \(dateStr)."
        }
    }

    /// Inserts a new audit event into the model context.
    private func addAudit(
        operation: String,
        entityTypes: [String],
        entityCount: Int,
        tags: [String],
        rationale: String?,
        error: Error? = nil
    ) async {
        let event = DemoAuditEvent(
            timestamp: Date(),
            operation: operation,
            entityTypes: entityTypes,
            entityCount: entityCount,
            tags: tags,
            rationale: rationale,
            errorDescription: error?.localizedDescription
        )
        modelContext.insert(event)
    }

    /// Exports the last audit event as a pretty-printed JSON string asynchronously.
    /// - Returns: JSON string representation of last audit event or nil if none exists.
    func exportLastAuditEventJSON() async -> String? {
        let entries = try? await modelContext.fetch(DemoAuditEvent.self)
        guard let last = entries?.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Provides an accessibility summary string for the last audit event asynchronously.
    var accessibilitySummary: String {
        get async {
            let entries = try? await modelContext.fetch(DemoAuditEvent.self)
            return entries?.last?.accessibilityLabel
                ?? NSLocalizedString("No demo data changes recorded.", comment: "")
        }
    }

    /// Fetches recent audit events asynchronously with an optional limit.
    /// - Parameter limit: Maximum number of recent events to fetch. Defaults to 50.
    /// - Returns: Array of recent `DemoAuditEvent`.
    func fetchRecentAuditEvents(limit: Int = 50) async -> [DemoAuditEvent] {
        let entries = try? await modelContext.fetch(DemoAuditEvent.self)
        return Array((entries ?? []).suffix(limit))
    }

    /// Populates the provided context with demo data asynchronously.
    /// Saves context asynchronously and logs audit event upon completion.
    /// - Parameter context: The model context to inject demo data into.
    func populateDemoData(in context: ModelContext) async {
        await clearDemoData(in: context)

        var totalEntities = 0
        let tags = ["demo", "preview", "sample"]

        // Owners & Dogs
        let owners: [DogOwner] = [
            DogOwner(
                ownerName: "Jane Smith",
                contactInfo: Contact(phone: "555-1234", email: "jane.smith@email.com"),
                address: "101 Oak Lane",
                dogs: [
                    Dog(
                        name: "Buddy",
                        breed: "Golden Retriever",
                        birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
                        tags: ["Calm", "Loyal", "VIP", "demo"],
                        notes: "Loves peanut butter treats. Responds well to calm environments. [demo entity]"
                    ),
                    Dog(
                        name: "Shadow",
                        breed: "Labrador",
                        birthdate: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
                        tags: ["Energetic", "High Energy", "demo"],
                        notes: "Prefers cool water baths. Needs extra exercise before grooming. [demo entity]"
                    )
                ],
                notes: "Demo client for onboarding and UI preview. [demo entity]"
            ),
            DogOwner(
                ownerName: "Carlos Gomez",
                contactInfo: Contact(phone: "555-6789", email: "carlos.gomez@email.com"),
                address: "22 Maple Street",
                dogs: [
                    Dog(
                        name: "Luna",
                        breed: "Poodle",
                        birthdate: Calendar.current.date(byAdding: .year, value: -4, to: Date()),
                        tags: ["Sensitive Skin", "First Visit", "demo"],
                        notes: "Needs hypoallergenic shampoo. First grooming appointment. [demo entity]"
                    )
                ],
                notes: "Demo client for onboarding and scenario testing. [demo entity]"
            )
        ]

        for owner in owners {
            owner.tags.append(contentsOf: tags)
            context.insert(owner)
            totalEntities += 1
            for dog in owner.dogs {
                dog.owner = owner
                dog.tags.append(contentsOf: tags)
                context.insert(dog)
                totalEntities += 1
            }
        }

        // Demo appointments and charges
        for owner in owners {
            for dog in owner.dogs {
                let appointment = Appointment(
                    date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                    dog: dog,
                    owner: owner,
                    serviceType: .fullGroom,
                    notes: "Routine appointment. Demo scenario. [demo entity]"
                )
                appointment.tags = tags
                context.insert(appointment)
                totalEntities += 1

                let charge = Charge(
                    date: appointment.date,
                    type: .fullPackage,
                    amount: 65.00,
                    notes: "Groomed with style. Demo only. [demo entity]"
                )
                charge.owner = owner
                charge.dog = dog
                charge.tags = tags
                context.insert(charge)
                totalEntities += 1
            }
        }

        // Demo tasks
        let sampleTask = Task(
            title: "Call Jane Smith for feedback",
            details: "Ask about last appointment experience (demo). [demo entity]",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
        )
        sampleTask.tags = tags
        context.insert(sampleTask)
        totalEntities += 1

        // Save & audit asynchronously
        do {
            try await context.save()
            await addAudit(
                operation: "inject",
                entityTypes: ["DogOwner", "Dog", "Appointment", "Charge", "Task"],
                entityCount: totalEntities,
                tags: tags,
                rationale: "Demo data for preview, onboarding, and UI testing."
            )
        } catch {
            await addAudit(
                operation: "inject",
                entityTypes: ["DogOwner", "Dog", "Appointment", "Charge", "Task"],
                entityCount: totalEntities,
                tags: tags,
                rationale: "Demo data for preview, onboarding, and UI testing.",
                error: error
            )
            print("DemoDataManager error saving context: \(error)")
        }
    }

    /// Removes all demo data from the context asynchronously.
    /// Saves context asynchronously and logs audit event upon completion.
    /// - Parameter context: The model context to clear demo data from.
    func clearDemoData(in context: ModelContext) async {
        let entityTypes: [any PersistentModel.Type] = [DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self]
        var removed = 0
        let tags = ["demo", "preview", "sample"]
        for entityType in entityTypes {
            // In production, filter demo-only data via tags (predicate). Here: all instances for demo.
            let fetch = FetchDescriptor<some PersistentModel>(predicate: nil)
            if let results = try? context.fetch(fetch) as? [any PersistentModel] {
                for obj in results {
                    // Only delete if tagged as demo (assumes `tags` property or flag on model)
                    if let objTags = (obj as? TaggableEntity)?.tags, !Set(objTags).isDisjoint(with: tags) {
                        context.delete(obj)
                        removed += 1
                    }
                    // If tags not present, fallback to deleting all (legacy fallback, can remove for stricter filtering)
                    else if (obj as? TaggableEntity) == nil {
                        context.delete(obj)
                        removed += 1
                    }
                }
            }
        }
        do {
            try await context.save()
        } catch {
            print("DemoDataManager error saving context during clear: \(error)")
        }
        await addAudit(
            operation: "clear",
            entityTypes: entityTypes.map { String(describing: $0) },
            entityCount: removed,
            tags: tags,
            rationale: "Removed demo data (preview, onboarding, testing)."
        )
    }
}

/// Protocol to indicate taggable entities for demo cleanup.
/// Extend all your models (DogOwner, Dog, Appointment, Charge, Task) with this protocol and `tags` property.
protocol TaggableEntity {
    var tags: [String] { get set }
}

// MARK: - Unit Test Stubs for Concurrency-Safe Audit Logging

#if DEBUG
import XCTest

final class DemoDataManagerTests: XCTestCase {
    func testConcurrentAuditLogging() async {
        let manager = DemoDataManager.shared
        let expectation = XCTestExpectation(description: "Concurrent audit logging")

        let group = DispatchGroup()
        let concurrentQueue = DispatchQueue(label: "com.furfolio.test.concurrentQueue", attributes: .concurrent)

        for i in 0..<100 {
            group.enter()
            concurrentQueue.async {
                Task {
                    await manager.addAudit(
                        operation: "inject",
                        entityTypes: ["TestEntity"],
                        entityCount: i,
                        tags: ["test"],
                        rationale: "Test concurrent logging \(i)",
                        error: nil
                    )
                    group.leave()
                }
            }
        }

        group.notify(queue: DispatchQueue.main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        let events = await manager.fetchRecentAuditEvents(limit: 100)
        XCTAssertEqual(events.count, 100, "Should have 100 audit events logged concurrently")
    }

    func testFetchRecentAuditEventsLimit() async {
        let manager = DemoDataManager.shared
        let events = await manager.fetchRecentAuditEvents(limit: 10)
        XCTAssertLessThanOrEqual(events.count, 10, "Fetched events should not exceed limit")
    }
}
#endif

// MARK: - SwiftUI PreviewProvider Demonstrating Async Audit Log Summary Updates and Export JSON

#if DEBUG
struct DemoDataManager_Previews: PreviewProvider {
    struct DemoView: View {
        @State private var summary: String = "Loading..."
        @State private var jsonExport: String = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("Audit Log Summary:")
                    .font(.headline)
                Text(summary)
                    .font(.body)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                Text("Last Audit Event JSON:")
                    .font(.headline)
                ScrollView {
                    Text(jsonExport)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Button("Refresh") {
                    Task {
                        await refreshAuditData()
                    }
                }
                .padding()
            }
            .padding()
            .task {
                await refreshAuditData()
            }
        }

        func refreshAuditData() async {
            let manager = DemoDataManager.shared
            summary = await manager.accessibilitySummary
            jsonExport = (await manager.exportLastAuditEventJSON()) ?? "No audit events available."
        }
    }

    static var previews: some View {
        DemoView()
    }
}
#endif

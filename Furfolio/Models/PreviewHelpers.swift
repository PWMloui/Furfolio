//
//  PreviewHelpers.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//  Updated on 06/26/2025 — made MainActor-isolated and fixed ModelContainer init.
//

import SwiftUI
import SwiftData

// TODO: Allow customization of preview model types and injection of seeded data for testing.

/// Helper utilities providing a SwiftData in-memory container and contexts for SwiftUI previews and tests.
@MainActor
enum PreviewHelpers {
  /// In-memory ModelContainer preconfigured with app models for use in previews.
  static let container: ModelContainer = {
    do {
      return try ModelContainer(
        for: DogOwner.self, Appointment.self, DailyRevenue.self, Charge.self, Task.self
      )
    } catch {
      fatalError("Failed to create preview ModelContainer: \(error)")
    }
  }()

  /// Main context for SwiftUI previews, bound to the in-memory container.
  static var context: ModelContext {
    container.mainContext
  }

  /// Seeds the in-memory container with sample data. Call at the start of previews to populate test data.
  static func seedSampleData() {
    let ctx = context
    // Insert sample models into the main context
    let owner = DogOwner.sample
    ctx.insert(owner)
    // Save seeded data for previews
    try? ctx.save()
  }
}

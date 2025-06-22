//
//  DashboardCustomizationView.swift
//  Furfolio
//
//  Created by Gemini on 6/22/25.
//

import SwiftUI
import Combine

/// A view that allows users to manage and reorder their dashboard widgets.
/// It uses the `DashboardWidgetManager` as its source of truth to display
/// and modify the state of the widgets.
struct DashboardCustomizationView: View {
    
    /// The manager that controls the dashboard widgets. Using @ObservedObject
    /// ensures that the view redraws when the widgets array changes.
    @ObservedObject var manager: DashboardWidgetManager
    
    var body: some View {
        // Using a NavigationView to provide a title and standard navigation bar appearance.
        NavigationView {
            // A List is the ideal container for editable rows of data.
            List {
                // Section provides clear visual grouping for the list of widgets.
                Section(header: Text("Manage Widgets"), footer: Text("Drag and drop widgets to change their order on the Dashboard. Toggling a widget off will hide it.")) {
                    // We iterate through the widgets using ForEach.
                    // The binding `$manager.widgets` allows direct modification of widget properties.
                    ForEach($manager.widgets) { $widget in
                        WidgetRowView(widget: $widget, manager: manager)
                    }
                    // The .onMove modifier enables drag-and-drop reordering for the ForEach view.
                    .onMove(perform: moveWidget)
                }
            }
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            // An EditButton is a standard SwiftUI component that toggles the list's edit mode.
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            // Use the insetGrouped style for a modern, clean appearance.
            .listStyle(.insetGrouped)
        }
    }
    
    /// This function is called by the .onMove modifier when the user reorders a row.
    /// - Parameters:
    ///   - source: The original positions of the items being moved.
    ///   - destination: The final position for the moved items.
    private func moveWidget(from source: IndexSet, to destination: Int) {
        // 1. Create a mutable copy of the current widgets.
        var updatedWidgets = manager.widgets
        
        // 2. Perform the move operation on the copied array.
        updatedWidgets.move(fromOffsets: source, toOffset: destination)
        
        // 3. Extract the new order of UUIDs from the reordered array.
        let newOrder = updatedWidgets.map { $0.id }
        
        // 4. Call the manager's reorder function to update the model and persist the changes.
        manager.reorderWidgets(by: newOrder)
    }
}

/// A helper view to display a single row in the widget list.
/// Separating this into its own view keeps the main body clean.
struct WidgetRowView: View {
    
    /// A binding to the widget this row represents.
    @Binding var widget: DashboardWidget
    
    /// A reference to the manager to call its methods.
    @ObservedObject var manager: DashboardWidgetManager

    var body: some View {
        HStack {
            // Display the title of the widget.
            Text(widget.title)
            
            Spacer()
            
            // The Toggle controls the `isEnabled` property of the widget.
            // When its value changes, it automatically calls the manager's
            // setWidgetEnabled function via the .onChange modifier.
            Toggle("Show", isOn: $widget.isEnabled)
                .labelsHidden() // We don't need the "Show" label to be visible.
                .onChange(of: widget.isEnabled) { newValue in
                    manager.setWidgetEnabled(id: widget.id, isEnabled: newValue)
                }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - SwiftUI Preview

/// Provides a design-time preview of the DashboardCustomizationView.
/// This is essential for rapid UI development without needing to run the full app.
struct DashboardCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        // We create a mock instance of the DashboardWidgetManager for the preview.
        let previewManager = DashboardWidgetManager()
        
        // Now we can render the view with the mock manager.
        DashboardCustomizationView(manager: previewManager)
    }
}


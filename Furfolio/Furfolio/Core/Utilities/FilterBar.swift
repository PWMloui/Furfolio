//
//  FilterBar.swift
//  Furfolio
//
//  Enhanced: Tokenized, Modular, Auditable Filter/Search Bar (2025)
//

import SwiftUI

// MARK: - FilterBar Audit/Event Logging

fileprivate struct FilterBarAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "editSearch", "clearSearch", "filterChange"
    let searchText: String
    let filter: String
    let tags: [String]
    let actor: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(operation.capitalized) [\(filter)] \"\(searchText)\" at \(dateStr)"
    }
}

fileprivate final class FilterBarAudit {
    static private(set) var log: [FilterBarAuditEvent] = []

    static func record(
        operation: String,
        searchText: String,
        filter: String,
        tags: [String],
        actor: String? = nil,
        context: String? = nil
    ) {
        let event = FilterBarAuditEvent(
            timestamp: Date(),
            operation: operation,
            searchText: searchText,
            filter: filter,
            tags: tags,
            actor: actor,
            context: context
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No filter/search events recorded."
    }
}

// MARK: - FilterBar (Tokenized, Modular, Auditable Filter/Search Bar)

struct FilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: FilterOption
    var filterOptions: [FilterOption]
    var placeholder: String = NSLocalizedString("Search", comment: "Placeholder for filter bar")
    var accessibilityID: String? = nil
    var trailingButtons: [AnyView] = []
    var isEnabled: Bool = true
    var actor: String? = nil
    var context: String? = nil

    // Local state to track changes for audit
    @State private var previousSearch: String = ""
    @State private var previousFilter: FilterOption? = nil

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                TextField(placeholder, text: $searchText, onEditingChanged: { _ in
                    // Log only if changed
                    if previousSearch != searchText {
                        FilterBarAudit.record(
                            operation: "editSearch",
                            searchText: searchText,
                            filter: selectedFilter.id,
                            tags: ["search", "filter", "edit"],
                            actor: actor,
                            context: context
                        )
                        previousSearch = searchText
                    }
                })
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .onSubmit {
                    FilterBarAudit.record(
                        operation: "editSearch",
                        searchText: searchText,
                        filter: selectedFilter.id,
                        tags: ["search", "filter", "submit"],
                        actor: actor,
                        context: context
                    )
                }
                .accessibilityIdentifier(accessibilityID)
                .disabled(!isEnabled)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        FilterBarAudit.record(
                            operation: "clearSearch",
                            searchText: "",
                            filter: selectedFilter.id,
                            tags: ["search", "filter", "clear"],
                            actor: actor,
                            context: context
                        )
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .accessibilityLabel(NSLocalizedString("Clear search text", comment: "Accessibility label for clear search button"))
                }
                ForEach(trailingButtons.indices, id: \.self) { i in
                    trailingButtons[i]
                }
            }
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
            .appShadow(AppShadows.card)

            if filterOptions.count > 1 {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(filterOptions) { option in
                        Label(NSLocalizedString(option.label, comment: "Filter label"), systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .font(AppFonts.body)
                .padding(.horizontal, AppSpacing.small)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onChange(of: selectedFilter) { newValue in
                    if previousFilter?.id != newValue.id {
                        FilterBarAudit.record(
                            operation: "filterChange",
                            searchText: searchText,
                            filter: newValue.id,
                            tags: ["search", "filter", "segment"],
                            actor: actor,
                            context: context
                        )
                        previousFilter = newValue
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
        .disabled(!isEnabled)
        .onAppear {
            previousSearch = searchText
            previousFilter = selectedFilter
        }
    }
}

// MARK: - Filter Option Model

struct FilterOption: Hashable, Identifiable {
    let id: String
    let label: String
    let icon: String

    init(id: String, label: String, icon: String) {
        self.id = id
        self.label = label
        self.icon = icon
    }

    // Presets for different screens
    static let all = FilterOption(id: "all", label: NSLocalizedString("All", comment: "Filter label for all items"), icon: "line.3.horizontal")
    static let appointments = FilterOption(id: "appointments", label: NSLocalizedString("Appointments", comment: "Filter label for appointments"), icon: "calendar")
    static let owners = FilterOption(id: "owners", label: NSLocalizedString("Owners", comment: "Filter label for owners"), icon: "person.3.fill")
    static let dogs = FilterOption(id: "dogs", label: NSLocalizedString("Dogs", comment: "Filter label for dogs"), icon: "pawprint")
    static let charges = FilterOption(id: "charges", label: NSLocalizedString("Charges", comment: "Filter label for charges"), icon: "creditcard")
}

// MARK: - Audit/Admin Accessors

public enum FilterBarAuditAdmin {
    public static var lastSummary: String { FilterBarAudit.accessibilitySummary }
    public static var lastJSON: String? { FilterBarAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        FilterBarAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct FilterBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var search = ""
        @State private var selected = FilterOption.all
        let filters = [
            .all, .appointments, .owners, .dogs, .charges
        ]

        var body: some View {
            VStack(spacing: AppSpacing.medium) {
                FilterBar(
                    searchText: $search,
                    selectedFilter: $selected,
                    filterOptions: filters,
                    accessibilityID: "mainFilterBar",
                    trailingButtons: [
                        AnyView(
                            Button(action: { print("Dev button tapped") }) {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(AppColors.accent)
                            }
                            .accessibilityLabel("Developer tool button")
                        )
                    ],
                    isEnabled: true,
                    actor: "preview"
                )
                .padding(AppSpacing.medium)

                FilterBar(
                    searchText: $search,
                    selectedFilter: $selected,
                    filterOptions: filters,
                    accessibilityID: "disabledFilterBar",
                    trailingButtons: [],
                    isEnabled: false,
                    actor: "preview"
                )
                .padding(AppSpacing.medium)
            }
            .padding(AppSpacing.medium)
        }
    }

    static var previews: some View {
        Group {
            PreviewWrapper()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            PreviewWrapper()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif

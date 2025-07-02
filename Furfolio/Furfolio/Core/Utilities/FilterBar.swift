//
//  FilterBar.swift
//  Furfolio
//
//  Enhanced: Tokenized, Modular, Auditable Filter/Search Bar (2025)
//

import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol FilterBarAnalyticsLogger {
    /// Log a filter bar event asynchronously.
    func log(event: String, searchText: String, filter: String) async
}

public protocol FilterBarAuditLogger {
    /// Record a filter bar audit entry asynchronously.
    func record(event: String, searchText: String, filter: String, tags: [String]) async
}

public struct NullFilterBarAnalyticsLogger: FilterBarAnalyticsLogger {
    public init() {}
    public func log(event: String, searchText: String, filter: String) async {}
}

public struct NullFilterBarAuditLogger: FilterBarAuditLogger {
    public init() {}
    public func record(event: String, searchText: String, filter: String, tags: [String]) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a filter bar audit event.
public struct FilterBarAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let searchText: String
    public let filter: String
    public let tags: [String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        searchText: String,
        filter: String,
        tags: [String]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.searchText = searchText
        self.filter = filter
        self.tags = tags
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(event.capitalized) [\(filter)] \"\(searchText)\" at \(dateStr)"
    }
}

/// Concurrency-safe actor for logging filter bar events.
public actor FilterBarAuditManager {
    private var buffer: [FilterBarAuditEntry] = []
    private let maxEntries = 500
    public static let shared = FilterBarAuditManager()

    public func add(_ entry: FilterBarAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [FilterBarAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportLastJSON() -> String? {
        guard let last = buffer.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    public var accessibilitySummary: String {
        recent(limit: 1).first?.accessibilityLabel ??
           "No filter/search events recorded."
    }
}

// MARK: - FilterBar (Tokenized, Modular, Auditable Filter/Search Bar)

public struct FilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: FilterOption
    var filterOptions: [FilterOption]
    var analytics: FilterBarAnalyticsLogger
    var audit: FilterBarAuditLogger
    var placeholder: String = NSLocalizedString("Search", comment: "Placeholder for filter bar")
    var accessibilityID: String? = nil
    var trailingButtons: [AnyView] = []
    var isEnabled: Bool = true
    var actorID: String? = nil
    var context: String? = nil

    // Local state to track changes for audit
    @State private var previousSearch: String = ""
    @State private var previousFilter: FilterOption? = nil

    public init(
        searchText: Binding<String>,
        selectedFilter: Binding<FilterOption>,
        filterOptions: [FilterOption],
        analytics: FilterBarAnalyticsLogger = NullFilterBarAnalyticsLogger(),
        audit: FilterBarAuditLogger = NullFilterBarAuditLogger(),
        placeholder: String = NSLocalizedString("Search", comment: "Placeholder for filter bar"),
        accessibilityID: String? = nil,
        trailingButtons: [AnyView] = [],
        isEnabled: Bool = true,
        actorID: String? = nil,
        context: String? = nil
    ) {
        self._searchText = searchText
        self._selectedFilter = selectedFilter
        self.filterOptions = filterOptions
        self.analytics = analytics
        self.audit = audit
        self.placeholder = placeholder
        self.accessibilityID = accessibilityID
        self.trailingButtons = trailingButtons
        self.isEnabled = isEnabled
        self.actorID = actorID
        self.context = context
        self.previousSearch = searchText.wrappedValue
        self.previousFilter = selectedFilter.wrappedValue
    }

    public var body: some View {
        VStack(spacing: AppSpacing.small) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                TextField(placeholder, text: $searchText, onEditingChanged: { _ in
                    // Log only if changed
                    if previousSearch != searchText {
                        let tags = ["search", "filter", "edit"]
                        Task {
                            await analytics.log(
                                event: "editSearch",
                                searchText: searchText,
                                filter: selectedFilter.id
                            )
                            await audit.record(
                                event: "editSearch",
                                searchText: searchText,
                                filter: selectedFilter.id,
                                tags: tags
                            )
                            await FilterBarAuditManager.shared.add(
                                FilterBarAuditEntry(
                                    event: "editSearch",
                                    searchText: searchText,
                                    filter: selectedFilter.id,
                                    tags: tags
                                )
                            )
                        }
                        previousSearch = searchText
                    }
                })
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .autocapitalization(.none)
                .onSubmit {
                    let tags = ["search", "filter", "submit"]
                    Task {
                        await analytics.log(
                            event: "editSearch",
                            searchText: searchText,
                            filter: selectedFilter.id
                        )
                        await audit.record(
                            event: "editSearch",
                            searchText: searchText,
                            filter: selectedFilter.id,
                            tags: tags
                        )
                        await FilterBarAuditManager.shared.add(
                            FilterBarAuditEntry(
                                event: "editSearch",
                                searchText: searchText,
                                filter: selectedFilter.id,
                                tags: tags
                            )
                        )
                    }
                }
                .accessibilityIdentifier(accessibilityID)
                .disabled(!isEnabled)
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        let tags = ["search", "filter", "clear"]
                        Task {
                            await analytics.log(
                                event: "clearSearch",
                                searchText: "",
                                filter: selectedFilter.id
                            )
                            await audit.record(
                                event: "clearSearch",
                                searchText: "",
                                filter: selectedFilter.id,
                                tags: tags
                            )
                            await FilterBarAuditManager.shared.add(
                                FilterBarAuditEntry(
                                    event: "clearSearch",
                                    searchText: "",
                                    filter: selectedFilter.id,
                                    tags: tags
                                )
                            )
                        }
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
                        let tags = ["search", "filter", "segment"]
                        Task {
                            await analytics.log(
                                event: "filterChange",
                                searchText: searchText,
                                filter: newValue.id
                            )
                            await audit.record(
                                event: "filterChange",
                                searchText: searchText,
                                filter: newValue.id,
                                tags: tags
                            )
                            await FilterBarAuditManager.shared.add(
                                FilterBarAuditEntry(
                                    event: "filterChange",
                                    searchText: searchText,
                                    filter: newValue.id,
                                    tags: tags
                                )
                            )
                        }
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
    public static var lastSummary: String {
        get async { await FilterBarAuditManager.shared.accessibilitySummary }
    }
    public static func lastJSON() async -> String? {
        await FilterBarAuditManager.shared.exportLastJSON()
    }
    public static func recentEvents(limit: Int = 5) async -> [String] {
        await FilterBarAuditManager.shared.recent(limit: limit)
            .map { $0.accessibilityLabel }
    }
}

// MARK: - Diagnostics

public extension FilterBar {
    static func recentAuditEntries(limit: Int = 20) async -> [FilterBarAuditEntry] {
        await FilterBarAuditManager.shared.recent(limit: limit)
    }
    static func exportLastAuditJSON() async -> String? {
        await FilterBarAuditManager.shared.exportLastJSON()
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

//
//  FilterBar.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - FilterBar (Tokenized, Modular, Auditable Filter/Search Bar)

/**
 `FilterBar` is a fully modular, tokenized, and auditable search and filter component used throughout Furfolio. It supports business analytics, accessibility, localization, and UI design system integration for search and filter scenarios across all modules including owners, dogs, appointments, and financial records.
 
 - Features:
   - Integrated search with clear button
   - Optional segmented filter with icons (e.g., Dogs, Owners, Charges)
   - Customizable for additional business modules or dev tools
   - Modular: supports trailing buttons for dev/test features
   - Accessible: supports identifiers for UI testing
   - Design-system friendly with AppColors, AppFonts, AppSpacing, BorderRadius, and AppShadows tokens
   - Ready for localization and business analytics integration
 */
struct FilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: FilterOption
    var filterOptions: [FilterOption]
    var placeholder: String = NSLocalizedString("Search", comment: "Placeholder for filter bar")
    var accessibilityID: String? = nil
    var trailingButtons: [AnyView] = []
    var isEnabled: Bool = true

    var body: some View {
        VStack(spacing: AppSpacing.small) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                TextField(placeholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
                    .onSubmit {
                        // Optional: perform search
                    }
                    .accessibilityIdentifier(accessibilityID)
                    .disabled(!isEnabled)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
            }
        }
        .padding(.horizontal, AppSpacing.medium)
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
        .disabled(!isEnabled)
    }
}

// MARK: - Filter Option Model

/// Represents a single filter tab/segment in Furfolio’s filter bar, used for fast switching between business domains.
struct FilterOption: Hashable, Identifiable {
    let id: String
    let label: String
    let icon: String

    init(id: String, label: String, icon: String) {
        self.id = id
        self.label = label
        self.icon = icon
    }

    // Examples: create presets for use in different screens
    static let all = FilterOption(id: "all", label: NSLocalizedString("All", comment: "Filter label for all items"), icon: "line.3.horizontal")
    static let appointments = FilterOption(id: "appointments", label: NSLocalizedString("Appointments", comment: "Filter label for appointments"), icon: "calendar")
    static let owners = FilterOption(id: "owners", label: NSLocalizedString("Owners", comment: "Filter label for owners"), icon: "person.3.fill")
    static let dogs = FilterOption(id: "dogs", label: NSLocalizedString("Dogs", comment: "Filter label for dogs"), icon: "pawprint")
    static let charges = FilterOption(id: "charges", label: NSLocalizedString("Charges", comment: "Filter label for charges"), icon: "creditcard")
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
                // Demo preview showcasing FilterBar with trailing dev tool button
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
                    isEnabled: true
                )
                .padding(AppSpacing.medium)

                // Business preview showcasing disabled state and no trailing buttons
                FilterBar(
                    searchText: $search,
                    selectedFilter: $selected,
                    filterOptions: filters,
                    accessibilityID: "disabledFilterBar",
                    trailingButtons: [],
                    isEnabled: false
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

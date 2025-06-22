//
//  TagSelectorView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Allows multi-selection from a list of tags, with search and optional new tag creation.
struct TagSelectorView: View {
    @Binding var selectedTags: Set<String>
    let allTags: [String]
    var allowAddTag: Bool = true

    @State private var searchText = ""
    @State private var newTagText = ""
    @FocusState private var newTagFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) { // Replaced hardcoded spacing 18 with AppSpacing.medium
            // Title
            Text("Select Tags")
                .font(AppFonts.headline) // Replaced .font(.headline) with AppFonts.headline token
                .padding(.top, AppSpacing.small) // Replaced 8 with AppSpacing.small

            // Search field
            TextField("Search tags…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, AppSpacing.xSmall) // Replaced 4 with AppSpacing.xSmall

            // Tags Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.xSmall)], spacing: AppSpacing.small) { // Spacing tokens used
                    ForEach(filteredTags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTags.contains(tag),
                            action: { toggle(tag) }
                        )
                    }
                }
                .padding(.vertical, AppSpacing.xSmall) // Replaced 4 with AppSpacing.xSmall
            }
            .frame(maxHeight: 210) // 210 kept as is, no token specified

            // Add new tag input
            if allowAddTag {
                HStack {
                    TextField("Add new tag", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                        .focused($newTagFocused)
                        .onSubmit { addNewTag() }
                    Button(action: addNewTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2) // No token specified; keeping as is
                            .foregroundColor(newTagText.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.tertiaryText : AppColors.accent) // Replaced .gray and .accentColor with tokens
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, AppSpacing.xSmall) // Replaced 4 with AppSpacing.xSmall
            }

            // Selected tags summary with removable chips
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xSmall) { // Replaced 8 with AppSpacing.xSmall
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true, action: { toggle(tag) }, showRemove: true)
                        }
                    }
                }
                .padding(.top, AppSpacing.small) // Replaced 8 with AppSpacing.small
            }

            Spacer()
        }
        .padding(AppSpacing.medium) // Replaced default padding with AppSpacing.medium
        .background(AppColors.background.ignoresSafeArea()) // Replaced systemGroupedBackground with AppColors.background token
        .accessibilityElement(children: .contain) // Accessibility: group children for better navigation
    }

    // Filter tags based on search text
    private var filteredTags: [String] {
        let filtered = searchText.isEmpty ? allTags : allTags.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted()
    }

    // Toggle selection state for a tag
    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
    }

    // Add a new tag if it doesn't already exist and is not empty
    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !allTags.contains(trimmed), !selectedTags.contains(trimmed) else { return }
        selectedTags.insert(trimmed)
        newTagText = ""
        newTagFocused = false
    }
}

/// Visual chip for a tag, selectable and optionally removable
private struct TagChip: View {
    let tag: String
    var isSelected: Bool
    var action: () -> Void
    var showRemove: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) { // Replaced 4 with AppSpacing.xSmall for consistent spacing
            Button(action: action) {
                Text(tag)
                    .font(AppFonts.caption) // Replaced .font(.caption) with AppFonts.caption token
                    .padding(.horizontal, AppSpacing.medium) // Replaced 11 with AppSpacing.medium for horizontal padding
                    .padding(.vertical, AppSpacing.small) // Replaced 6 with AppSpacing.small for vertical padding
                    .background(isSelected ? AppColors.accent.opacity(0.16) : AppColors.backgroundSecondary) // Replaced hardcoded colors with tokens
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary) // Replaced .accentColor and .primary with tokens
                    .cornerRadius(BorderRadius.medium) // Replaced hardcoded corner radius 14 with BorderRadius.medium token
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.medium)
                            .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 1.7 : 1) // Replaced colors with tokens
                    )
            }
            // Keeping buttonStyle plain for accessibility and expected button behavior
            .buttonStyle(.plain) // Comment: Keep plain style for accessibility and consistent tap area

            if showRemove && isSelected {
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.secondaryText) // Replaced .secondary with token
                        // Comment: Use AppFonts or icon size tokens if available for image scale
                        .imageScale(.small) // Placeholder for icon size token usage
                }
                // Keeping buttonStyle plain for accessibility and consistent tap area
                .buttonStyle(.plain) // Comment: Keep plain style for accessibility and consistent tap area
                .accessibilityLabel("Remove \(tag)") // Accessibility: descriptive label for remove button
            }
        }
    }
}

// MARK: - Preview

/// Demo / Business / Tokenized preview for TagSelectorView
#Preview {
    @State var selected: Set<String> = ["Aggressive", "VIP"]
    return TagSelectorView(
        selectedTags: $selected,
        allTags: ["Aggressive", "Sensitive Skin", "Timid", "VIP", "Special Shampoo", "Allergic"]
    )
    .frame(width: AppSpacing.extraLarge * 23, height: AppSpacing.extraLarge * 18) // Replaced hardcoded width and height with token-based multiples
}

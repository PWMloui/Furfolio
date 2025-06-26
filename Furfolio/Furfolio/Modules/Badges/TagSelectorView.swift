//
//  TagSelectorView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Tag Selector
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct TagSelectorAuditEvent: Codable {
    let timestamp: Date
    let operation: String            // "select", "remove", "search", "add"
    let tag: String?
    let tags: [String]
    let searchText: String?
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let tagLabel = tag != nil ? " tag: \(tag!)" : ""
        let search = searchText != nil ? " search: \(searchText!)" : ""
        return "[\(op)]\(tagLabel)\(search) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class TagSelectorAudit {
    static private(set) var log: [TagSelectorAuditEvent] = []

    static func record(
        operation: String,
        tag: String? = nil,
        tags: [String] = [],
        searchText: String? = nil,
        actor: String? = "user",
        context: String? = "TagSelectorView",
        detail: String? = nil
    ) {
        let event = TagSelectorAuditEvent(
            timestamp: Date(),
            operation: operation,
            tag: tag,
            tags: tags,
            searchText: searchText,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 200 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tag selector events recorded."
    }
}

// MARK: - TagSelectorView (Enhanced)

struct TagSelectorView: View {
    @Binding var selectedTags: Set<String>
    let allTags: [String]
    var allowAddTag: Bool = true

    @State private var searchText = ""
    @State private var newTagText = ""
    @FocusState private var newTagFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            // Title
            Text("Select Tags")
                .font(AppFonts.headline)
                .padding(.top, AppSpacing.small)

            // Search field
            TextField("Search tags…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.bottom, AppSpacing.xSmall)
                .onChange(of: searchText) { val in
                    TagSelectorAudit.record(
                        operation: "search",
                        tags: Array(selectedTags),
                        searchText: val,
                        detail: "User searched for tag"
                    )
                }

            // Tags Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.xSmall)], spacing: AppSpacing.small) {
                    ForEach(filteredTags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: selectedTags.contains(tag),
                            action: { toggle(tag) }
                        )
                    }
                }
                .padding(.vertical, AppSpacing.xSmall)
            }
            .frame(maxHeight: 210)

            // Add new tag input
            if allowAddTag {
                HStack {
                    TextField("Add new tag", text: $newTagText)
                        .textFieldStyle(.roundedBorder)
                        .focused($newTagFocused)
                        .onSubmit { addNewTag() }
                    Button(action: addNewTag) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(newTagText.trimmingCharacters(in: .whitespaces).isEmpty ? AppColors.tertiaryText : AppColors.accent)
                    }
                    .disabled(newTagText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, AppSpacing.xSmall)
            }

            // Selected tags summary with removable chips
            if !selectedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xSmall) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag, isSelected: true, action: { toggle(tag) }, showRemove: true)
                        }
                    }
                }
                .padding(.top, AppSpacing.small)
            }

            Spacer()
        }
        .padding(AppSpacing.medium)
        .background(AppColors.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }

    // Filter tags based on search text
    private var filteredTags: [String] {
        let filtered = searchText.isEmpty ? allTags : allTags.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted()
    }

    // Toggle selection state for a tag, with audit
    private func toggle(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
            TagSelectorAudit.record(
                operation: "remove",
                tag: tag,
                tags: Array(selectedTags),
                detail: "Tag removed"
            )
        } else {
            selectedTags.insert(tag)
            TagSelectorAudit.record(
                operation: "select",
                tag: tag,
                tags: Array(selectedTags),
                detail: "Tag selected"
            )
        }
    }

    // Add a new tag if it doesn't already exist and is not empty, with audit
    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !allTags.contains(trimmed), !selectedTags.contains(trimmed) else { return }
        selectedTags.insert(trimmed)
        TagSelectorAudit.record(
            operation: "add",
            tag: trimmed,
            tags: Array(selectedTags),
            detail: "New tag created"
        )
        newTagText = ""
        newTagFocused = false
    }
}

/// Visual chip for a tag, selectable and optionally removable, with audit on tap
private struct TagChip: View {
    let tag: String
    var isSelected: Bool
    var action: () -> Void
    var showRemove: Bool = false

    var body: some View {
        HStack(spacing: AppSpacing.xSmall) {
            Button(action: action) {
                Text(tag)
                    .font(AppFonts.caption)
                    .padding(.horizontal, AppSpacing.medium)
                    .padding(.vertical, AppSpacing.small)
                    .background(isSelected ? AppColors.accent.opacity(0.16) : AppColors.backgroundSecondary)
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textPrimary)
                    .cornerRadius(BorderRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: BorderRadius.medium)
                            .stroke(isSelected ? AppColors.accent : AppColors.border, lineWidth: isSelected ? 1.7 : 1)
                    )
            }
            .buttonStyle(.plain)

            if showRemove && isSelected {
                Button(action: action) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.secondaryText)
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(tag)")
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum TagSelectorAuditAdmin {
    public static var lastSummary: String { TagSelectorAudit.accessibilitySummary }
    public static var lastJSON: String? { TagSelectorAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TagSelectorAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#Preview {
    @State var selected: Set<String> = ["Aggressive", "VIP"]
    return TagSelectorView(
        selectedTags: $selected,
        allTags: ["Aggressive", "Sensitive Skin", "Timid", "VIP", "Special Shampoo", "Allergic"]
    )
    .frame(width: AppSpacing.extraLarge * 23, height: AppSpacing.extraLarge * 18)
}

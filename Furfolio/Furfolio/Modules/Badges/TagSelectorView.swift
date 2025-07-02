//
//  TagSelectorView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Tag Selector
//

import SwiftUI
import AVFoundation

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

    /// Records an audit event and posts VoiceOver announcements for tag operations.
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
        
        // Accessibility: Post VoiceOver announcements for add, remove, select operations
        if let tag = tag, ["add", "remove", "select"].contains(operation) {
            let message: String
            switch operation {
            case "add":
                message = "Tag \(tag) added"
            case "remove":
                message = "Tag \(tag) removed"
            case "select":
                message = "Tag \(tag) selected"
            default:
                message = ""
            }
            if !message.isEmpty {
                DispatchQueue.main.async {
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
        }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tag selector events recorded."
    }
    
    /// Exports all audit events as CSV string with headers: timestamp,operation,tag,tags,searchText,actor,context,detail.
    /// This allows easy export and analysis of audit data.
    static func exportCSV() -> String {
        let header = "timestamp,operation,tag,tags,searchText,actor,context,detail"
        let rows = log.map { event in
            let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
            let operation = event.operation
            let tag = event.tag?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tags = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let searchText = event.searchText?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let actor = event.actor?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let context = event.context?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            // CSV fields containing commas or quotes are wrapped in quotes
            func csvField(_ field: String) -> String {
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field)\""
                } else {
                    return field
                }
            }
            return [
                csvField(timestamp),
                csvField(operation),
                csvField(tag),
                csvField(tags),
                csvField(searchText),
                csvField(actor),
                csvField(context),
                csvField(detail)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Computes the most frequently added tag, if any.
    /// Useful for analytics and understanding user tag preferences.
    static var mostAddedTag: String? {
        let addedTags = log.filter { $0.operation == "add" }.compactMap { $0.tag }
        let counts = Dictionary(grouping: addedTags, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of add operations recorded.
    static var totalTagAdds: Int {
        log.filter { $0.operation == "add" }.count
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
            
            // DEV overlay: shows last 3 audit events and the most added tag for debugging and analytics
            #if DEBUG
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit Log (last 3 events):")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(TagSelectorAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(.secondary)
                }
                if let mostAdded = TagSelectorAudit.mostAddedTag {
                    Text("Most Added Tag: \(mostAdded)")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                } else {
                    Text("Most Added Tag: None")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.05))
            #endif
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

    // Toggle selection state for a tag, with audit and accessibility announcement
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

    // Add a new tag if it doesn't already exist and is not empty, with audit and accessibility announcement
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
    /// Exposes CSV export for audit log, useful for external analysis and reporting.
    public static func exportCSV() -> String { TagSelectorAudit.exportCSV() }
    /// Returns last N audit events as accessibility labels.
    public static func recentEvents(limit: Int = 5) -> [String] {
        TagSelectorAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Returns the most frequently added tag, if any.
    public static var mostAddedTag: String? { TagSelectorAudit.mostAddedTag }
    /// Returns total number of add operations recorded.
    public static var totalTagAdds: Int { TagSelectorAudit.totalTagAdds }
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

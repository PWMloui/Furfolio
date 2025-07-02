// MARK: - ChargeFilterBar (Tokenized, Modular, Auditable Filter Bar for Charges)
//
// ChargeFilterBar is a modular, tokenized, and auditable UI component for filtering displayed charges.
// Designed for business analytics, accessibility, localization, and seamless UI design system integration.
// All colors, fonts, and spacing are referenced via design tokens to ensure consistency and maintainability.
//
//  ChargeFilterBar.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular, Analytics-Ready
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct ChargeFilterAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "filter", "clear"
    let filterType: String?
    let tags: [String]
    let context: String
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let filter = filterType ?? "All"
        return "[\(op)] filter: \(filter) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ChargeFilterAudit {
    static private(set) var log: [ChargeFilterAuditEvent] = []

    /// Records a filter or clear operation with associated metadata.
    static func record(
        operation: String,
        filterType: String?,
        tags: [String] = [],
        context: String = "ChargeFilterBar"
    ) {
        let event = ChargeFilterAuditEvent(
            timestamp: Date(),
            operation: operation,
            filterType: filterType,
            tags: tags,
            context: context
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
        
        // Post VoiceOver announcement summarizing the filter action for accessibility.
        var announcement = ""
        if operation == "filter", let filter = filterType {
            announcement = "Charges filtered by \(filter)"
        } else if operation == "clear" {
            announcement = filterType == nil ? "All charges shown" : "Filter cleared for \(filterType!)"
        }
        if !announcement.isEmpty {
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
    }

    /// Exports the last audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as CSV string with headers: timestamp,operation,filterType,tags,context.
    static func exportCSV() -> String {
        let header = "timestamp,operation,filterType,tags,context"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let filterTypeStr = event.filterType ?? ""
            let tagsStr = event.tags.joined(separator: ";")
            // Escape commas in context and filterType if needed (simple quotes)
            let contextStr = event.context.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(timestampStr)\",\"\(event.operation)\",\"\(filterTypeStr)\",\"\(tagsStr)\",\"\(contextStr)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// The filterType most used in "filter" operations, or nil if none.
    static var mostUsedFilterType: String? {
        let filterEvents = log.filter { $0.operation == "filter" && $0.filterType != nil }
        let counts = Dictionary(grouping: filterEvents, by: { $0.filterType! }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of "filter" operations recorded.
    static var totalFilterEvents: Int {
        log.filter { $0.operation == "filter" }.count
    }
    
    /// Accessibility summary of the last event or default message.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge filter events recorded."
    }
}

// MARK: - ChargeFilterBar

struct ChargeFilterBar: View {
    /// Selected charge type filter (nil means "All")
    @Binding var selectedChargeType: String?
    /// List of charge types to display as filter options
    var chargeTypes: [String]
    /// Callback when filters are cleared
    var onClearFilters: (() -> Void)? = nil
    
    // For DEV overlay: last 3 audit events and most used filter
    #if DEBUG
    @State private var devOverlayVisible = true
    #endif

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.filterChipSpacing) { // Use spacing token for filter chips
                    // "All" filter button
                    Button(action: {
                        if selectedChargeType != nil {
                            ChargeFilterAudit.record(
                                operation: "clear",
                                filterType: nil,
                                tags: ["all", "clear"]
                            )
                        }
                        selectedChargeType = nil
                        onClearFilters?()
                    }) {
                        Text("All")
                            .font(AppFonts.subheadline) // Tokenized font
                            .font(AppFonts.subheadlineSemibold) // Tokenized semibold variant
                            .padding(.vertical, AppSpacing.filterChipVertical) // Tokenized vertical padding
                            .padding(.horizontal, AppSpacing.filterChipHorizontal) // Tokenized horizontal padding
                            .background(
                                selectedChargeType == nil ? AppColors.accent : AppColors.backgroundSecondary
                            )
                            .foregroundColor(
                                selectedChargeType == nil ? AppColors.textOnAccent : AppColors.textPrimary
                            )
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel(Text("Show all charges"))

                    // Individual charge type filter buttons
                    ForEach(chargeTypes, id: \.self) { type in
                        Button(action: {
                            if selectedChargeType == type {
                                selectedChargeType = nil
                                onClearFilters?()
                                ChargeFilterAudit.record(
                                    operation: "clear",
                                    filterType: type,
                                    tags: ["clear", type]
                                )
                            } else {
                                selectedChargeType = type
                                ChargeFilterAudit.record(
                                    operation: "filter",
                                    filterType: type,
                                    tags: ["filter", type]
                                )
                            }
                        }) {
                            Text(type)
                                .font(AppFonts.subheadline)
                                .font(AppFonts.subheadlineSemibold)
                                .padding(.vertical, AppSpacing.filterChipVertical)
                                .padding(.horizontal, AppSpacing.filterChipHorizontal)
                                .background(
                                    selectedChargeType == type ? AppColors.accent : AppColors.backgroundSecondary
                                )
                                .foregroundColor(
                                    selectedChargeType == type ? AppColors.textOnAccent : AppColors.textPrimary
                                )
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel(Text("Filter charges by \(type)"))
                    }
                }
                .padding(.horizontal, AppSpacing.filterBarHorizontal)
                .padding(.vertical, AppSpacing.filterBarVertical)
            }
            .background(AppColors.background)
            .accessibilityElement(children: .contain)
            
            #if DEBUG
            // DEV overlay showing last 3 audit events and most used filter for debugging and analytics insight.
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("🔍 Audit Log (last 3 events):")
                    .font(AppFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                ForEach(ChargeFilterAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                    Text(event.accessibilityLabel)
                        .font(AppFonts.caption2)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                if let mostUsed = ChargeFilterAudit.mostUsedFilterType {
                    Text("📊 Most used filter: \(mostUsed)")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 2)
                } else {
                    Text("📊 Most used filter: None")
                        .font(AppFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 2)
                }
            }
            .padding([.horizontal, .bottom], AppSpacing.filterBarHorizontal)
            .background(AppColors.backgroundSecondary.opacity(0.8))
            #endif
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeFilterAuditAdmin {
    public static var lastSummary: String { ChargeFilterAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeFilterAudit.exportLastJSON() }
    /// Exports all audit events as CSV string.
    public static var exportCSV: String { ChargeFilterAudit.exportCSV() }
    /// The filterType most used in "filter" operations, or nil if none.
    public static var mostUsedFilterType: String? { ChargeFilterAudit.mostUsedFilterType }
    /// Total number of "filter" operations recorded.
    public static var totalFilterEvents: Int { ChargeFilterAudit.totalFilterEvents }
    /// Returns recent audit event accessibility labels, limited to `limit`.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeFilterAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct ChargeFilterBar_Previews: PreviewProvider {
    @State static var selectedType: String? = nil
    static var previews: some View {
        // Demo/business/tokenized preview: uses design tokens for color, font, and spacing
        ChargeFilterBar(
            selectedChargeType: $selectedType,
            chargeTypes: ["Full Package", "Basic Package", "Nail Trim", "Bath Only"],
            onClearFilters: { print("Filters cleared") }
        )
        .previewLayout(.sizeThatFits)
        .padding(AppSpacing.previewPadding)
        .background(AppColors.background)
    }
}
#endif

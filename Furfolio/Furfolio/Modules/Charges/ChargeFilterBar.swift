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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
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

    var body: some View {
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
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeFilterAuditAdmin {
    public static var lastSummary: String { ChargeFilterAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeFilterAudit.exportLastJSON() }
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

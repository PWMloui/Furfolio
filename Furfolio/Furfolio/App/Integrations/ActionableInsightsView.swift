//
//  ActionableInsightsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Actionable Insights View, Admin & Analytics-Ready
//

import SwiftUI

// MARK: - Actionable Insights View

struct ActionableInsightsView: View {
    struct InsightMetric: Identifiable {
        var id: String { title }
        let title: String
        let value: String
        let icon: String
        let color: Color
        let tags: [String]
        let description: String?
        let accessibilityLabel: String
        let accessibilityHint: String?
        /// Optional action closure for this insight (tapping card)
        var onTap: (() -> Void)? = nil
        /// Optional minimumRole or permission required
        var minRole: String? = nil
    }

    let insights: [InsightMetric]
    /// Optional analytics/event logger (injected for compliance/testing/preview)
    static var analyticsLogger: ((String, [String: Any]) -> Void)?
    /// Optional audit/event logger (for compliance/business intelligence)
    static var auditLogger: ((String, [String: Any]) -> Void)?
    /// Optional admin override for card tap (e.g. deep link, alert)
    var onInsightTap: ((InsightMetric) -> Void)? = nil
    /// Optional permission checker (for owner/admin only insights)
    var permissionChecker: ((InsightMetric) -> Bool)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actionable Insights")
                .font(.title2.bold())
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(10)

            ForEach(insights) { metric in
                if permissionChecker?(metric) ?? true {
                    InsightCard(
                        title: metric.title,
                        value: metric.value,
                        systemImage: metric.icon,
                        color: metric.color,
                        description: metric.description,
                        tags: metric.tags,
                        accessibilityLabel: metric.accessibilityLabel,
                        accessibilityHint: metric.accessibilityHint,
                        onTap: {
                            // Audit + analytics + handler
                            Self.auditLogger?("tap", [
                                "metric": metric.title,
                                "value": metric.value,
                                "tags": metric.tags,
                                "timestamp": Date().iso8601String
                            ])
                            Self.analyticsLogger?("tap", [
                                "metric": metric.title,
                                "value": metric.value,
                                "tags": metric.tags,
                                "timestamp": Date().iso8601String
                            ])
                            onInsightTap?(metric)
                            metric.onTap?()
                        }
                    )
                    .onAppear {
                        Self.auditLogger?("appear", [
                            "metric": metric.title,
                            "value": metric.value,
                            "tags": metric.tags,
                            "timestamp": Date().iso8601String
                        ])
                        Self.analyticsLogger?("appear", [
                            "metric": metric.title,
                            "value": metric.value,
                            "tags": metric.tags,
                            "timestamp": Date().iso8601String
                        ])
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - InsightCard

private struct InsightCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color
    let description: String?
    let tags: [String]
    let accessibilityLabel: String
    let accessibilityHint: String?
    let onTap: (() -> Void)?

    @State private var showCopied = false

    var body: some View {
        Button(action: {
            withAnimation(.easeOut(duration: 0.15)) {
                showCopied = false
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap?()
        }) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundColor(color)

                Text(value)
                    .font(.title)
                    .bold()
                    .foregroundColor(color)
                    .accessibilityValue(value)
                Text(title)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                // Tag Badges
                if !tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            BadgeView(tag: tag, color: color)
                        }
                    }
                }
                if showCopied {
                    Text("Copied!")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 3)
            )
            .contextMenu {
                Button {
                    UIPasteboard.general.string = "\(title): \(value)"
                    withAnimation(.easeInOut) { showCopied = true }
                    ActionableInsightsView.auditLogger?("copy", [
                        "metric": title,
                        "value": value,
                        "timestamp": Date().iso8601String
                    ])
                    ActionableInsightsView.analyticsLogger?("copy", [
                        "metric": title,
                        "value": value,
                        "timestamp": Date().iso8601String
                    ])
                } label: {
                    Label("Copy Value", systemImage: "doc.on.doc")
                }
                Button {
                    let msg = "\(title): \(value)"
                    ActionableInsightsView.auditLogger?("share", [
                        "metric": title,
                        "value": value,
                        "timestamp": Date().iso8601String
                    ])
                    ActionableInsightsView.analyticsLogger?("share", [
                        "metric": title,
                        "value": value,
                        "timestamp": Date().iso8601String
                    ])
                    withAnimation(.easeInOut) { showCopied = true }
                } label: {
                    Label("Share Insight", systemImage: "square.and.arrow.up")
                }
            }
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilitySortPriority(5)
        }
        .buttonStyle(.plain)
        .scaleEffect(showCopied ? 1.06 : 1.0)
        .animation(.easeInOut, value: showCopied)
    }
}

private struct BadgeView: View {
    let tag: String
    let color: Color
    var body: some View {
        Text(tag.capitalized)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
            .foregroundColor(color)
            .accessibilityLabel("Tag: \(tag)")
    }
}

// MARK: - Audit/Event Export/Utility

private extension Date {
    var iso8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

// MARK: - Preview

#if DEBUG
struct ActionableInsightsView_Previews: PreviewProvider {
    @State static var exportText: String = ""

    static var previews: some View {
        VStack {
            ActionableInsightsView(
                insights: [
                    .init(title: "Upcoming Appointments", value: "5", icon: "calendar", color: .blue, tags: ["appointments"], description: nil, accessibilityLabel: "5 upcoming appointments", accessibilityHint: "Shows number of future appointments"),
                    .init(title: "Total Revenue", value: "$3,450", icon: "dollarsign.circle", color: .green, tags: ["revenue"], description: nil, accessibilityLabel: "Total revenue $3,450", accessibilityHint: "Total earned so far"),
                    .init(title: "Inactive Customers", value: "3", icon: "person.fill.xmark", color: .red, tags: ["inactive"], description: "Consider sending a re-engagement offer", accessibilityLabel: "3 inactive customers", accessibilityHint: "Customers not seen recently"),
                    .init(title: "Loyalty Progress", value: "65%", icon: "star.circle.fill", color: .yellow, tags: ["loyalty"], description: "65% progress toward next reward", accessibilityLabel: "Loyalty program progress 65 percent", accessibilityHint: "See rewards dashboard")
                ],
                onInsightTap: { metric in
                    print("Tapped: \(metric.title)")
                },
                permissionChecker: { metric in
                    // Example: Only show "Total Revenue" for owner/admin in preview
                    if metric.title == "Total Revenue" {
                        // Plug in your role checker here, e.g.: AccessControl.shared.can(.viewReports)
                        return true // Assume owner/admin for preview
                    }
                    return true
                }
            )
            Button("Export Recent Insights") {
                exportText = "Audit/analytics export coming soon..." // Replace with your actual export logic
            }
            .padding()
            if !exportText.isEmpty {
                ScrollView {
                    Text(exportText)
                        .font(.footnote)
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)
            }
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

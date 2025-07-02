//
//  ProfitabilityChartView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI
import Charts

// MARK: - Data Model

/// Represents a profit/loss entry for a given period (day, week, month)
struct ProfitEntry: Identifiable {
    let id = UUID()
    let date: Date
    let revenue: Double
    let expenses: Double
    var profit: Double { revenue - expenses }
}

// MARK: - Main View

struct ProfitabilityChartView: View {
    // Data source (swap to your analytics/DB as needed)
    var entries: [ProfitEntry]
    var periodLabel: String = "Date" // e.g. "Day", "Month", etc.

    // MARK: - Chart state
    @State private var selectedTrend: TrendType = .profit
    @State private var showMarginPercent: Bool = false
    @State private var selectedEntry: ProfitEntry? = nil
    @State private var chartFrame: CGRect = .zero // For annotation positioning

    // MARK: - Trend line selection enum
    enum TrendType: String, CaseIterable, Identifiable {
        case profit = "Profit"
        case revenue = "Revenue"
        case expenses = "Expenses"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Profitability Trend")
                .font(.headline)

            // MARK: - Trend Picker
            Picker("Trend", selection: $selectedTrend) {
                ForEach(TrendType.allCases) { trend in
                    Text(trend.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)

            // MARK: - Margin % Toggle (only for profit)
            if selectedTrend == .profit {
                Toggle(isOn: $showMarginPercent) {
                    Text("Show as margin %")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .padding(.bottom, 2)
            }

            if #available(iOS 16.0, *) {
                // Chart with dynamic trend line
                Chart {
                    // --- Revenue & Expenses bars (always shown for context) ---
                    ForEach(entries) { entry in
                        BarMark(
                            x: .value(periodLabel, entry.date),
                            y: .value("Revenue", entry.revenue)
                        )
                        .foregroundStyle(.green.opacity(0.3))
                    }
                    ForEach(entries) { entry in
                        BarMark(
                            x: .value(periodLabel, entry.date),
                            y: .value("Expenses", entry.expenses)
                        )
                        .foregroundStyle(.red.opacity(0.3))
                    }

                    // --- Trend line ---
                    switch selectedTrend {
                    case .profit:
                        ForEach(entries) { entry in
                            let yValue = showMarginPercent
                                ? (entry.revenue != 0 ? entry.profit / entry.revenue * 100 : 0)
                                : entry.profit
                            LineMark(
                                x: .value(periodLabel, entry.date),
                                y: .value(showMarginPercent ? "Profit Margin (%)" : "Profit", yValue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                showMarginPercent ?
                                    (yValue >= 0 ? .green : .red)
                                    : (entry.profit >= 0 ? .green : .red)
                            )
                            .symbol(Circle())
                            // Tap/callout annotation
                            .accessibilityLabel(Text(dateFormatter.string(from: entry.date)))
                            .accessibilityValue(
                                Text(
                                    showMarginPercent
                                    ? String(format: "%.1f%%", yValue)
                                    : currencyFormatter.string(from: NSNumber(value: yValue)) ?? "\(yValue)"
                                )
                            )
                            .annotation(position: .top, alignment: .center, spacing: 0) {
                                // Chart annotation/callout for selected entry
                                if let sel = selectedEntry, sel.id == entry.id {
                                    calloutView(for: entry)
                                }
                            }
                            .onTapGesture {
                                // Set as selected for callout/tooltip
                                selectedEntry = entry
                            }
                        }
                    case .revenue:
                        ForEach(entries) { entry in
                            LineMark(
                                x: .value(periodLabel, entry.date),
                                y: .value("Revenue", entry.revenue)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.green)
                            .symbol(Circle())
                            .annotation(position: .top, alignment: .center, spacing: 0) {
                                if let sel = selectedEntry, sel.id == entry.id {
                                    calloutView(for: entry, trend: .revenue)
                                }
                            }
                            .onTapGesture {
                                selectedEntry = entry
                            }
                        }
                    case .expenses:
                        ForEach(entries) { entry in
                            LineMark(
                                x: .value(periodLabel, entry.date),
                                y: .value("Expenses", entry.expenses)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.red)
                            .symbol(Circle())
                            .annotation(position: .top, alignment: .center, spacing: 0) {
                                if let sel = selectedEntry, sel.id == entry.id {
                                    calloutView(for: entry, trend: .expenses)
                                }
                            }
                            .onTapGesture {
                                selectedEntry = entry
                            }
                        }
                    }
                }
                .chartYScale(domain: yDomain)
                .frame(height: 220)
                .padding(.bottom, 4)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: entries.count > 10 ? 2 : 1)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(
                            format: yAxisFormat
                        )
                    }
                }
                // Dismiss callout on tap outside
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .onEnded {
                            selectedEntry = nil
                        }
                )
            } else {
                Text("Profit charts require iOS 16+.")
            }

            // MARK: - Mini legend
            HStack(spacing: 16) {
                Group {
                    if selectedTrend == .profit {
                        legendCircle(color: .green)
                        Text(showMarginPercent ? "Profit Margin" : "Profit")
                            .font(.caption)
                    } else if selectedTrend == .revenue {
                        legendCircle(color: .green)
                        Text("Revenue")
                            .font(.caption)
                    } else if selectedTrend == .expenses {
                        legendCircle(color: .red)
                        Text("Expenses")
                            .font(.caption)
                    }
                }
                legendCircle(color: .green.opacity(0.3))
                Text("Revenue")
                    .font(.caption)
                legendCircle(color: .red.opacity(0.3))
                Text("Expenses")
                    .font(.caption)
            }
            .padding(.leading, 2)

            // MARK: - Mini stats footer
            if !entries.isEmpty {
                Divider()
                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg Profit")
                            .font(.caption2)
                        Text(currencyFormatter.string(from: NSNumber(value: avgProfit)) ?? "-")
                            .font(.footnote)
                            .bold()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("High Profit")
                            .font(.caption2)
                        Text(currencyFormatter.string(from: NSNumber(value: maxProfit)) ?? "-")
                            .font(.footnote)
                            .bold()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Low Profit")
                            .font(.caption2)
                        Text(currencyFormatter.string(from: NSNumber(value: minProfit)) ?? "-")
                            .font(.footnote)
                            .bold()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Avg Margin")
                            .font(.caption2)
                        Text(String(format: "%.1f%%", avgMargin))
                            .font(.footnote)
                            .bold()
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    // MARK: - Y domain auto scale (buffered) for each trend
    private var yDomain: ClosedRange<Double> {
        switch selectedTrend {
        case .profit:
            if showMarginPercent {
                let vals = entries.map { $0.revenue != 0 ? $0.profit / $0.revenue * 100 : 0 }
                let minVal = vals.min() ?? 0
                let maxVal = vals.max() ?? 1
                let buffer = max(5, (maxVal - minVal) * 0.1)
                return (minVal - buffer)...(maxVal + buffer)
            } else {
                let minVal = entries.map { $0.profit }.min() ?? 0
                let maxVal = entries.map { $0.profit }.max() ?? 1
                let buffer = max(100, (maxVal - minVal) * 0.1)
                return (minVal - buffer)...(maxVal + buffer)
            }
        case .revenue:
            let minVal = entries.map { $0.revenue }.min() ?? 0
            let maxVal = entries.map { $0.revenue }.max() ?? 1
            let buffer = max(100, (maxVal - minVal) * 0.1)
            return (minVal - buffer)...(maxVal + buffer)
        case .expenses:
            let minVal = entries.map { $0.expenses }.min() ?? 0
            let maxVal = entries.map { $0.expenses }.max() ?? 1
            let buffer = max(100, (maxVal - minVal) * 0.1)
            return (minVal - buffer)...(maxVal + buffer)
        }
    }

    // MARK: - Y axis format for each trend
    private var yAxisFormat: FloatingPointFormatStyle<Double> {
        if selectedTrend == .profit && showMarginPercent {
            return .number.precision(.fractionLength(0)).percent
        }
        return .currency(code: "USD")
    }

    // MARK: - Mini stats calculations
    private var avgProfit: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { $0.profit }.reduce(0, +) / Double(entries.count)
    }
    private var maxProfit: Double {
        entries.map { $0.profit }.max() ?? 0
    }
    private var minProfit: Double {
        entries.map { $0.profit }.min() ?? 0
    }
    private var avgMargin: Double {
        let margins = entries.map { $0.revenue != 0 ? $0.profit / $0.revenue * 100 : 0 }
        guard !margins.isEmpty else { return 0 }
        return margins.reduce(0, +) / Double(margins.count)
    }

    // MARK: - Chart annotation/callout view
    @ViewBuilder
    private func calloutView(for entry: ProfitEntry, trend: TrendType? = nil) -> some View {
        // Determine which trend is being shown
        let t = trend ?? selectedTrend
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: entry.date))
                .font(.caption)
                .foregroundColor(.secondary)
            switch t {
            case .profit:
                if showMarginPercent {
                    let margin = entry.revenue != 0 ? entry.profit / entry.revenue * 100 : 0
                    Text("Margin: \(String(format: "%.1f", margin))%")
                        .font(.caption)
                        .foregroundColor(.primary)
                } else {
                    Text("Profit: \(currencyFormatter.string(from: NSNumber(value: entry.profit)) ?? "-")")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            case .revenue:
                Text("Revenue: \(currencyFormatter.string(from: NSNumber(value: entry.revenue)) ?? "-")")
                    .font(.caption)
                    .foregroundColor(.primary)
            case .expenses:
                Text("Expenses: \(currencyFormatter.string(from: NSNumber(value: entry.expenses)) ?? "-")")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            // Always show revenue/expenses for context
            if t != .revenue {
                Text("Revenue: \(currencyFormatter.string(from: NSNumber(value: entry.revenue)) ?? "-")")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
            if t != .expenses {
                Text("Expenses: \(currencyFormatter.string(from: NSNumber(value: entry.expenses)) ?? "-")")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(radius: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Date/currency formatter helpers
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }
    private var currencyFormatter: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.currencyCode = "USD"
        nf.maximumFractionDigits = 2
        return nf
    }

    // MARK: - Legend circle
    @ViewBuilder
    private func legendCircle(color: Color) -> some View {
        Circle()
            .frame(width: 10, height: 10)
            .foregroundColor(color)
    }
}

// MARK: - Preview

#Preview {
    // Mock data for preview
    let sampleEntries = (0..<10).map { offset in
        ProfitEntry(
            date: Calendar.current.date(byAdding: .day, value: -offset, to: Date())!,
            revenue: Double.random(in: 300...500),
            expenses: Double.random(in: 100...350)
        )
    }.reversed()
    return ProfitabilityChartView(entries: Array(sampleEntries))
}

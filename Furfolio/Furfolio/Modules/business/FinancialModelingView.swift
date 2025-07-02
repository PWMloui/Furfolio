//
//  FinancialModelingView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol FinancialModelingAnalyticsLogger {
    /// Log a financial modeling event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol FinancialModelingAuditLogger {
    /// Record a financial modeling audit entry asynchronously.
    func record(_ event: String, parameters: [String: String]?) async
}

public struct NullFinancialModelingAnalyticsLogger: FinancialModelingAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullFinancialModelingAuditLogger: FinancialModelingAuditLogger {
    public init() {}
    public func record(_ event: String, parameters: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a financial modeling audit event.
public struct FinancialModelingAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging financial modeling events.
public actor FinancialModelingAuditManager {
    private var buffer: [FinancialModelingAuditEntry] = []
    private let maxEntries = 100
    public static let shared = FinancialModelingAuditManager()

    public func add(_ entry: FinancialModelingAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [FinancialModelingAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - View

public struct FinancialModelingView: View {
    @State private var projectionYears: Int = 5
    @State private var initialInvestment: Double = 10000
    @State private var annualReturn: Double = 7.0
    @State private var projectedValues: [Double] = []
    @State private var isLoading: Bool = false
    @State private var showAuditSheet: Bool = false

    let analytics: FinancialModelingAnalyticsLogger
    let audit: FinancialModelingAuditLogger

    public init(
        analytics: FinancialModelingAnalyticsLogger = NullFinancialModelingAnalyticsLogger(),
        audit: FinancialModelingAuditLogger = NullFinancialModelingAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Parameters")) {
                    Stepper(value: $projectionYears, in: 1...30) {
                        Text("Years: \(projectionYears)")
                    }
                    HStack {
                        Text("Initial Investment")
                        TextField("10000", value: $initialInvestment, formatter: NumberFormatter.currency)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Annual Return (%)")
                        TextField("7.0", value: $annualReturn, formatter: NumberFormatter.percent)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Calculate Projection") {
                        Task {
                            await analytics.log(event: "calculate_start", parameters: nil)
                            await audit.record("calculate_start", parameters: ["years":"\(projectionYears)"])
                            await FinancialModelingAuditManager.shared.add(
                                FinancialModelingAuditEntry(event: "calculate_start", detail: "years:\(projectionYears)")
                            )
                            await calculateProjection()
                            await analytics.log(event: "calculate_complete", parameters: ["count":"\(projectedValues.count)"])
                            await audit.record("calculate_complete", parameters: ["results": "\(projectedValues.count)"])
                            await FinancialModelingAuditManager.shared.add(
                                FinancialModelingAuditEntry(event: "calculate_complete", detail: "\(projectedValues.count) results")
                            )
                        }
                    }
                }

                if !projectedValues.isEmpty {
                    Section(header: Text("Projection")) {
                        ChartView(values: projectedValues)
                            .frame(height: 200)
                    }
                }
            }
            .navigationTitle("Financial Projection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Export Audit JSON") {
                        Task {
                            let json = await FinancialModelingAuditManager.shared.exportJSON()
                            UIPasteboard.general.string = json
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("View Audit Log") {
                        showAuditSheet = true
                    }
                }
            }
            .disabled(isLoading)
        }
        .sheet(isPresented: $showAuditSheet) {
            NavigationView {
                List {
                    ForEach(await FinancialModelingAuditManager.shared.recent(limit: 50)) { entry in
                        VStack(alignment: .leading) {
                            Text(entry.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(entry.event)
                                .font(.headline)
                            if let detail = entry.detail {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showAuditSheet = false }
                    }
                }
            }
        }
    }

    private func calculateProjection() async {
        isLoading = true
        projectedValues = (0...projectionYears).map { year in
            initialInvestment * pow(1 + annualReturn/100, Double(year))
        }
        // simulate delay
        try? await Task.sleep(nanoseconds: 200_000_000)
        isLoading = false
    }
}

// MARK: - Diagnostics

public extension FinancialModelingView {
    /// Fetch recent financial modeling audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [FinancialModelingAuditEntry] {
        await FinancialModelingAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await FinancialModelingAuditManager.shared.exportJSON()
    }
}

// MARK: - Helpers

fileprivate extension NumberFormatter {
    static var currency: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }
    static var percent: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 2
        return f
    }
}

// MARK: - ChartView Placeholder

public struct ChartView: View {
    let values: [Double]
    public init(values: [Double]) { self.values = values }
    public var body: some View {
        GeometryReader { geo in
            Path { path in
                guard let max = values.max(), max > 0 else { return }
                let stepX = geo.size.width / CGFloat(values.count - 1)
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(val / max))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.accentColor, lineWidth: 2)
        }
    }
}

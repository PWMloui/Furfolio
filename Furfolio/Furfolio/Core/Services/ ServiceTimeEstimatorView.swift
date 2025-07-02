//
//  ServiceTimeEstimatorView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, unified, and architecturally ready for owner-focused business management.
//  This file provides an adaptive, business-grade estimator for average service times.
//

/**
 ServiceTimeEstimatorView
 ------------------------
 A SwiftUI view for estimating and recording average service times in Furfolio.

 - **Architecture**: MVVM-compatible, using `ServiceTimeEstimatorViewModel` as an `ObservableObject`.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols and integrates a dedicated audit manager actor.
 - **Localization**: All static text and accessibility labels use `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Accessibility identifiers and combined elements for VoiceOver.
 - **Diagnostics & Preview/Testability**: Exposes async methods to retrieve and export audit logs.
 */

import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol ServiceTimeAnalyticsLogger {
    /// Log a service time event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol ServiceTimeAuditLogger {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

/// No-op implementations for previews/testing.
public struct NullServiceTimeAnalyticsLogger: ServiceTimeAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}
public struct NullServiceTimeAuditLogger: ServiceTimeAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a service time estimator audit event.
public struct ServiceTimeEstimatorAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging service time estimator events.
public actor ServiceTimeEstimatorAuditManager {
    private var buffer: [ServiceTimeEstimatorAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ServiceTimeEstimatorAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: ServiceTimeEstimatorAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ServiceTimeEstimatorAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as a pretty‑printed JSON string.
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

// MARK: - ServiceTimeEstimatorView (Tokenized, Modular, Auditable Service Time Analytics UI)

// MARK: - Main Service Time Estimator View

/// Owner-facing view for estimating and displaying average service times per service type.
/// Built for business analytics, UX efficiency, and rapid team onboarding.
public struct ServiceTimeEstimatorView: View {
    @ObservedObject var viewModel: ServiceTimeEstimatorViewModel
    let analytics: ServiceTimeAnalyticsLogger
    let audit: ServiceTimeAuditLogger

    public init(viewModel: ServiceTimeEstimatorViewModel,
                analytics: ServiceTimeAnalyticsLogger = NullServiceTimeAnalyticsLogger(),
                audit: ServiceTimeAuditLogger = NullServiceTimeAuditLogger()) {
        self.viewModel = viewModel
        self.analytics = analytics
        self.audit = audit
    }

    @State private var selectedServiceType: String = ""
    @State private var showAddDuration: Bool = false
    @Namespace private var durationNamespace

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Layout with Tokens and Accessibility

    public var body: some View {
        VStack(spacing: AppSpacing.large) {
            // Title with modular font and accessibility identifier
            Text(LocalizedStringKey("Service Time Estimator"))
                .font(AppFonts.title2Bold)
                .padding(.top, AppSpacing.medium)
                .accessibilityIdentifier("title")

            // Business service type picker (segmented for iPhone, menu for iPad/Mac)
            Picker(LocalizedStringKey("Service Type"), selection: $selectedServiceType) {
                ForEach(viewModel.serviceTypes, id: \.self) { type in
                    Text(LocalizedStringKey(type)).tag(type)
                }
            }
            .pickerStyle(horizontalSizeClass == .compact ? .segmented : .menu)
            .padding(.horizontal, AppSpacing.medium)
            .accessibilityIdentifier("serviceTypePicker")

            // Service analytics + quick add
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Text(LocalizedStringKey("Average Duration:"))
                        .font(AppFonts.headline)
                    if let avg = viewModel.averageDuration(for: selectedServiceType) {
                        Text(viewModel.formatDuration(avg))
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.accent)
                            .accessibilityIdentifier("averageDurationValue")
                    } else {
                        Text("—").accessibilityIdentifier("averageDurationDash")
                    }
                }
                .accessibilityElement(children: .combine)

                // Business-optimized quick entry buttons
                HStack(spacing: AppSpacing.small) {
                    ForEach(viewModel.quickDurations, id: \.self) { mins in
                        Button("\(mins) min") {
                            Task {
                                viewModel.addDuration(TimeInterval(mins * 60), for: selectedServiceType)
                                await analytics.log(event: "quick_add", parameters: ["minutes": mins, "type": selectedServiceType])
                                await audit.record("Quick add \(mins)min", metadata: ["type": selectedServiceType])
                                await ServiceTimeEstimatorAuditManager.shared.add(
                                    ServiceTimeEstimatorAuditEntry(event: "quick_add", detail: "\(mins)min for \(selectedServiceType)")
                                )
                            }
                        }
                        .buttonStyle(PulseButtonStyle(color: AppColors.success))
                        .accessibilityIdentifier("quickAdd_\(mins)")
                    }
                    Button(LocalizedStringKey("Custom")) {
                        Task {
                            await analytics.log(event: "custom_add_open", parameters: nil)
                            await audit.record("Opened custom duration sheet", metadata: nil)
                            await ServiceTimeEstimatorAuditManager.shared.add(
                                ServiceTimeEstimatorAuditEntry(event: "custom_open")
                            )
                            showAddDuration = true
                        }
                    }
                    .buttonStyle(PulseButtonStyle(color: AppColors.accent))
                    .accessibilityIdentifier("customAdd")
                }
            }
            .padding(.horizontal, AppSpacing.medium)

            Divider()

            // Animated business record list with accessibility identifiers
            ScrollViewReader { proxy in
                List {
                    ForEach(viewModel.durations(for: selectedServiceType).enumerated().map(Array.init), id: \.offset) { idx, duration in
                        HStack {
                            Text("#\(idx + 1)").foregroundColor(AppColors.secondaryText)
                            Spacer()
                            Text(viewModel.formatDuration(duration))
                        }
                        .id(idx)
                        .accessibilityIdentifier("durationRow_\(idx)")
                    }
                    .onDelete { indices in
                        Task {
                            viewModel.deleteDurations(at: indices, for: selectedServiceType)
                            await analytics.log(event: "delete_durations", parameters: ["count": indices.count, "type": selectedServiceType])
                            await audit.record("Deleted \(indices.count) durations", metadata: ["type": selectedServiceType])
                            await ServiceTimeEstimatorAuditManager.shared.add(
                                ServiceTimeEstimatorAuditEntry(event: "delete", detail: "\(indices.count) for \(selectedServiceType)")
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
                .onChange(of: viewModel.durations(for: selectedServiceType).count) { _ in
                    // Auto-scroll to last entry
                    if let lastIdx = viewModel.durations(for: selectedServiceType).indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIdx, anchor: .bottom)
                        }
                    }
                }
            }
            .accessibilityIdentifier("durationList")

            Spacer()
        }
        .background(AppColors.background)
        .sheet(isPresented: $showAddDuration) {
            AddDurationSheet(isPresented: $showAddDuration) { duration in
                Task {
                    viewModel.addDuration(duration, for: selectedServiceType)
                    await analytics.log(event: "custom_add", parameters: ["duration": duration, "type": selectedServiceType])
                    await audit.record("Custom add \(duration)s", metadata: ["type": selectedServiceType])
                    await ServiceTimeEstimatorAuditManager.shared.add(
                        ServiceTimeEstimatorAuditEntry(event: "custom_add", detail: "\(duration)s for \(selectedServiceType)")
                    )
                }
            }
        }
        .onAppear {
            if selectedServiceType.isEmpty, let first = viewModel.serviceTypes.first {
                selectedServiceType = first
            }
            Task {
                await analytics.log(event: "estimator_appear", parameters: nil)
                await audit.record("Estimator appeared", metadata: nil)
                await ServiceTimeEstimatorAuditManager.shared.add(
                    ServiceTimeEstimatorAuditEntry(event: "appear")
                )
            }
        }
        .padding(.bottom, AppSpacing.medium)
        .environment(\.horizontalSizeClass, UIDevice.current.userInterfaceIdiom == .pad ? .regular : .compact)
    }
}

// MARK: - ServiceTimeEstimatorViewModel (Business-Optimized Service Duration Analytics)

/// ViewModel for business-optimized service time analytics.
/// Designed for multi-user, role-aware, and design-system-ready use.
final class ServiceTimeEstimatorViewModel: ObservableObject {
    @Published var serviceTypes: [String]
    @Published private var durationsByType: [String: [TimeInterval]] = [:]
    let quickDurations = [15, 30, 45] // minutes

    init(serviceTypes: [String] = ["Full Groom", "Bath Only", "Nail Trim"]) {
        self.serviceTypes = serviceTypes
        for type in serviceTypes { durationsByType[type] = [] }
    }

    func durations(for type: String) -> [TimeInterval] {
        durationsByType[type] ?? []
    }

    func addDuration(_ duration: TimeInterval, for type: String) {
        guard duration > 0 else { return }
        durationsByType[type, default: []].append(duration)
        objectWillChange.send()
    }

    func deleteDurations(at offsets: IndexSet, for type: String) {
        durationsByType[type, default: []].remove(atOffsets: offsets)
        objectWillChange.send()
    }

    func averageDuration(for type: String) -> TimeInterval? {
        let list = durations(for: type)
        guard !list.isEmpty else { return nil }
        return list.reduce(0, +) / Double(list.count)
    }

    func formatDuration(_ interval: TimeInterval) -> String {
        let mins = Int(interval) / 60
        let secs = Int(interval) % 60
        return String(format: "%d min %02d sec", mins, secs)
    }
}

// MARK: - AddDurationSheet (Tokenized Custom Duration Input Sheet)

/// Sheet for entering a custom service duration with validation and design-system UI.
struct AddDurationSheet: View {
    @Binding var isPresented: Bool
    @State private var minutes: String = ""
    @State private var seconds: String = ""
    var onAdd: (TimeInterval) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStringKey("Enter Duration"))) {
                    HStack {
                        TextField(LocalizedStringKey("Minutes"), text: $minutes)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("minutesInput")
                        Text(LocalizedStringKey("min"))
                        TextField(LocalizedStringKey("Seconds"), text: $seconds)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("secondsInput")
                        Text(LocalizedStringKey("sec"))
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Add Duration"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Add")) {
                        let mins = Int(minutes) ?? 0
                        let secs = Int(seconds) ?? 0
                        let total = TimeInterval(mins * 60 + secs)
                        if total > 0 {
                            onAdd(total)
                            isPresented = false
                        }
                    }
                    .disabled(!isPositiveDuration)
                    .accessibilityIdentifier("addCustomDuration")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) {
                        isPresented = false
                    }
                    .accessibilityIdentifier("cancelCustomDuration")
                }
            }
        }
    }

    var isPositiveDuration: Bool {
        (Int(minutes) ?? 0) > 0 || (Int(seconds) ?? 0) > 0
    }
}

// MARK: - Preview

#if DEBUG
struct ServiceTimeEstimatorView_Previews: PreviewProvider {
    static var previews: some View {
        ServiceTimeEstimatorView(viewModel: ServiceTimeEstimatorViewModel())
    }
}
#endif

// MARK: - Diagnostics

public extension ServiceTimeEstimatorView {
    /// Fetch recent audit entries for diagnostics.
    static func recentAuditEntries(limit: Int = 20) async -> [ServiceTimeEstimatorAuditEntry] {
        await ServiceTimeEstimatorAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as a JSON string.
    static func exportAuditLogJSON() async -> String {
        await ServiceTimeEstimatorAuditManager.shared.exportJSON()
    }
}

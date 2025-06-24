//
//  ServiceTimeEstimatorView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, unified, and architecturally ready for owner-focused business management.
//  This file provides an adaptive, business-grade estimator for average service times.
//

import SwiftUI

// MARK: - ServiceTimeEstimatorView (Tokenized, Modular, Auditable Service Time Analytics UI)

// MARK: - Main Service Time Estimator View

/// Owner-facing view for estimating and displaying average service times per service type.
/// Built for business analytics, UX efficiency, and rapid team onboarding.
struct ServiceTimeEstimatorView: View {
    @ObservedObject var viewModel: ServiceTimeEstimatorViewModel

    @State private var selectedServiceType: String = ""
    @State private var showAddDuration: Bool = false
    @Namespace private var durationNamespace

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Layout with Tokens and Accessibility

    var body: some View {
        VStack(spacing: AppSpacing.large) {
            // Title with modular font and accessibility identifier
            Text("Service Time Estimator")
                .font(AppFonts.title2Bold)
                .padding(.top, AppSpacing.medium)
                .accessibilityIdentifier("title")

            // Business service type picker (segmented for iPhone, menu for iPad/Mac)
            Picker("Service Type", selection: $selectedServiceType) {
                ForEach(viewModel.serviceTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(horizontalSizeClass == .compact ? .segmented : .menu)
            .padding(.horizontal, AppSpacing.medium)
            .accessibilityIdentifier("serviceTypePicker")

            // Service analytics + quick add
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                HStack {
                    Text("Average Duration:")
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
                            viewModel.addDuration(TimeInterval(mins * 60), for: selectedServiceType)
                        }
                        .buttonStyle(PulseButtonStyle(color: AppColors.success))
                        .accessibilityIdentifier("quickAdd_\(mins)")
                    }
                    Button("Custom") { showAddDuration = true }
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
                        withAnimation {
                            viewModel.deleteDurations(at: indices, for: selectedServiceType)
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
                viewModel.addDuration(duration, for: selectedServiceType)
            }
        }
        .onAppear {
            if selectedServiceType.isEmpty, let first = viewModel.serviceTypes.first {
                selectedServiceType = first
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
                Section(header: Text("Enter Duration")) {
                    HStack {
                        TextField("Minutes", text: $minutes)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("minutesInput")
                        Text("min")
                        TextField("Seconds", text: $seconds)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("secondsInput")
                        Text("sec")
                    }
                }
            }
            .navigationTitle("Add Duration")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
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
                    Button("Cancel") {
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

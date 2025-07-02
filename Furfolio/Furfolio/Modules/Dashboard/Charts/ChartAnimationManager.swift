// ChartAnimationManager.swift

import Foundation
import Combine

// MARK: - Audit/Event Logging

fileprivate struct ChartAnimationAuditEvent: Codable {
    let timestamp: Date
    let action: String      // "start", "stop", "toggle"
    let isAnimating: Bool
    let cycleDuration: TimeInterval
    let animationDelay: TimeInterval
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(action.capitalized)] Animating: \(isAnimating), Cycle: \(cycleDuration)s, Delay: \(animationDelay)s [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class ChartAnimationAudit {
    static private(set) var log: [ChartAnimationAuditEvent] = []
    static let auditPublisher = PassthroughSubject<ChartAnimationAuditEvent, Never>()

    static func record(
        action: String,
        isAnimating: Bool,
        cycleDuration: TimeInterval,
        animationDelay: TimeInterval,
        tags: [String] = ["chartAnimation"]
    ) {
        let event = ChartAnimationAuditEvent(
            timestamp: Date(),
            action: action,
            isAnimating: isAnimating,
            cycleDuration: cycleDuration,
            animationDelay: animationDelay,
            tags: tags
        )
        log.append(event)
        auditPublisher.send(event)
        if log.count > 50 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports the entire audit log as a CSV string including:
    /// timestamp, action, isAnimating, cycleDuration, animationDelay, tags
    static func exportCSV() -> String {
        let header = "timestamp,action,isAnimating,cycleDuration,animationDelay,tags"
        let rows = log.map { event in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsStr = event.tags.joined(separator: ";")
            return "\(timestampStr),\(event.action),\(event.isAnimating),\(event.cycleDuration),\(event.animationDelay),\"\(tagsStr)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Total number of "start" actions recorded.
    static var totalStarts: Int {
        log.filter { $0.action == "start" }.count
    }
    
    /// Total number of "stop" actions recorded.
    static var totalStops: Int {
        log.filter { $0.action == "stop" }.count
    }
    
    /// Average cycleDuration across all logged events, or 0 if none.
    static var averageCycleDuration: TimeInterval {
        guard !log.isEmpty else { return 0 }
        let total = log.reduce(0) { $0 + $1.cycleDuration }
        return total / Double(log.count)
    }
    
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No chart animation events recorded."
    }
}

// MARK: - ChartAnimationManager

/// Manages chart animation state toggling in a periodic cycle, with full audit logging and observability.
final class ChartAnimationManager: ObservableObject {
    @Published var isAnimating: Bool = false {
        didSet {
            ChartAnimationAudit.record(
                action: "toggle",
                isAnimating: isAnimating,
                cycleDuration: cycleDuration,
                animationDelay: animationDelay,
                tags: ["toggle"]
            )
        }
    }

    private var animationTimer: Timer?
    private let cycleDuration: TimeInterval
    private let animationDelay: TimeInterval

    /// Initializes the manager.
    /// - Parameters:
    ///   - duration: Duration of one toggle cycle. Default is 1.2s.
    ///   - delay: Delay before the first animation cycle starts. Default is 0s.
    init(duration: TimeInterval = 1.2, delay: TimeInterval = 0.0) {
        self.cycleDuration = duration
        self.animationDelay = delay
    }

    /// Starts the animation cycle.
    /// Posts a VoiceOver announcement if cycleDuration > 2.0 seconds.
    func startAnimation() {
        stopAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) { [weak self] in
            guard let self = self else { return }
            self.isAnimating = true
            ChartAnimationAudit.record(
                action: "start",
                isAnimating: true,
                cycleDuration: self.cycleDuration,
                animationDelay: self.animationDelay,
                tags: ["start"]
            )
            
            // Accessibility: Announce slow animation cycle start if duration > 2.0s
            if self.cycleDuration > 2.0 {
                DispatchQueue.main.async {
                    UIAccessibility.post(notification: .announcement, argument: "Slow animation cycle started.")
                }
            }
            
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: self.cycleDuration * 2,
                                                       repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.isAnimating.toggle()
            }

            // Add to common RunLoop to prevent blocking UI updates
            if let timer = self.animationTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    /// Stops the animation and clears the timer.
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        if isAnimating {
            isAnimating = false
            ChartAnimationAudit.record(
                action: "stop",
                isAnimating: false,
                cycleDuration: cycleDuration,
                animationDelay: animationDelay,
                tags: ["stop"]
            )
        }
    }

    // MARK: - Audit/Admin Accessors

    static var lastAuditSummary: String { ChartAnimationAudit.accessibilitySummary }
    static var lastAuditJSON: String? { ChartAnimationAudit.exportLastJSON() }
    
    /// Exposes CSV export of audit log.
    static func exportCSV() -> String {
        ChartAnimationAudit.exportCSV()
    }
    
    /// Exposes total number of "start" actions.
    static var totalStarts: Int { ChartAnimationAudit.totalStarts }
    
    /// Exposes total number of "stop" actions.
    static var totalStops: Int { ChartAnimationAudit.totalStops }
    
    /// Exposes average cycle duration from audit log.
    static var averageCycleDuration: TimeInterval { ChartAnimationAudit.averageCycleDuration }
    
    static func recentAuditEvents(limit: Int = 5) -> [String] {
        ChartAnimationAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    static var auditEventsPublisher: AnyPublisher<ChartAnimationAuditEvent, Never> {
        ChartAnimationAudit.auditPublisher.eraseToAnyPublisher()
    }
}

// MARK: - Demo & Preview

#if DEBUG
import SwiftUI

struct ChartAnimationManagerDemoView: View {
    @StateObject private var animationManager = ChartAnimationManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Chart Animation State: \(animationManager.isAnimating ? "Animating" : "Stopped")")
                .font(.headline)
                .accessibilityIdentifier("ChartAnimationManagerDemo-State")

            Button(animationManager.isAnimating ? "Stop Animation" : "Start Animation") {
                animationManager.isAnimating ? animationManager.stopAnimation() : animationManager.startAnimation()
            }
            .padding()
            .background(animationManager.isAnimating ? Color.red : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("ChartAnimationManagerDemo-ToggleButton")

            if let last = ChartAnimationManager.lastAuditJSON {
                ScrollView {
                    Text("Last Audit:\n" + last)
                        .font(.caption2)
                        .padding()
                }
                .frame(maxHeight: 100)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // DEV Overlay: Show last 3 audit events and analytics summary
            ChartAnimationAuditOverlay()
                .padding(.top, 10)
        }
        .padding()
    }
}

/// DEV Overlay view displaying recent audit events and analytics summary.
/// Visible only in DEBUG builds for developer insight.
private struct ChartAnimationAuditOverlay: View {
    @State private var recentEvents: [String] = []
    @State private var totalStarts: Int = 0
    @State private var totalStops: Int = 0
    @State private var averageCycleDuration: TimeInterval = 0
    
    private var formatter: NumberFormatter {
        let fmt = NumberFormatter()
        fmt.maximumFractionDigits = 2
        fmt.minimumFractionDigits = 2
        return fmt
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Events (Last 3):")
                .font(.caption)
                .bold()
            ForEach(recentEvents, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Divider()
            
            HStack {
                Text("Starts: \(totalStarts)")
                Spacer()
                Text("Stops: \(totalStops)")
                Spacer()
                Text("Avg Cycle: \(formatter.string(from: NSNumber(value: averageCycleDuration)) ?? "0.00")s")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray5).opacity(0.9))
        .cornerRadius(8)
        .onAppear(perform: refreshData)
        .onReceive(ChartAnimationManager.auditEventsPublisher) { _ in
            refreshData()
        }
    }
    
    private func refreshData() {
        recentEvents = ChartAnimationManager.recentAuditEvents(limit: 3)
        totalStarts = ChartAnimationManager.totalStarts
        totalStops = ChartAnimationManager.totalStops
        averageCycleDuration = ChartAnimationManager.averageCycleDuration
    }
}

struct ChartAnimationManager_Previews: PreviewProvider {
    static var previews: some View {
        ChartAnimationManagerDemoView()
    }
}
#endif

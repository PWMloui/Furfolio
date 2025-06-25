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
        }
        .padding()
    }
}

struct ChartAnimationManager_Previews: PreviewProvider {
    static var previews: some View {
        ChartAnimationManagerDemoView()
    }
}
#endif

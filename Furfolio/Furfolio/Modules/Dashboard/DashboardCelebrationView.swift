//
//  DashboardCelebrationView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Celebration Overlay
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct CelebrationAuditEvent: Codable {
    let timestamp: Date
    let message: String
    let particleCount: Int
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Appear] \(message) (particles: \(particleCount)) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class CelebrationAudit {
    static private(set) var log: [CelebrationAuditEvent] = []

    static func record(
        message: String,
        particleCount: Int,
        tags: [String] = ["celebration"]
    ) {
        let event = CelebrationAuditEvent(
            timestamp: Date(),
            message: message,
            particleCount: particleCount,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No celebration events recorded."
    }
    
    // MARK: - New Analytics Computed Properties
    
    /// Returns the celebration message that appears most often in the log.
    static var mostFrequentMessage: String? {
        guard !log.isEmpty else { return nil }
        let frequency = Dictionary(grouping: log, by: { $0.message }).mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the average particle count of all logged celebration events.
    static var averageParticleCount: Double {
        guard !log.isEmpty else { return 0 }
        let totalParticles = log.reduce(0) { $0 + $1.particleCount }
        return Double(totalParticles) / Double(log.count)
    }
    
    /// Returns the total number of celebration events recorded.
    static var totalCelebrations: Int {
        log.count
    }
    
    // MARK: - CSV Export
    
    /// Exports the entire celebration log as a CSV string.
    /// CSV columns: timestamp,message,particleCount,tags
    static func exportCSV() -> String {
        let header = "timestamp,message,particleCount,tags"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event -> String in
            let timestampStr = formatter.string(from: event.timestamp)
            let escapedMessage = event.message.replacingOccurrences(of: "\"", with: "\"\"")
            let tagsJoined = event.tags.joined(separator: ";")
            // CSV escaping for message (in quotes) to handle commas/newlines
            return "\"\(timestampStr)\",\"\(escapedMessage)\",\(event.particleCount),\"\(tagsJoined)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - DashboardCelebrationView

struct DashboardCelebrationView: View {
    @Binding var isPresented: Bool

    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var animateConfetti = false
    
    // For accessibility announcements
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    private let particleCount = 100
    private let message = "🎉 Congratulations! 🎉 You've reached an important milestone!"

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                Text("🎉 Congratulations! 🎉")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Congratulations, you've reached an important milestone.")

                Text("You've reached an important milestone!")
                    .font(.title3)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Button(action: {
                    isPresented = false
                }) {
                    Text("Close")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 180)
                        .background(Color.white)
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                }
                .accessibilityLabel("Close celebration")
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isPresented)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.accentColor)
                    .shadow(radius: 10)
            )
            .padding()

            ConfettiView(particles: confettiParticles, animate: $animateConfetti)
                .allowsHitTesting(false)
            
            #if DEBUG
            // DEV Overlay showing audit info and stats at bottom
            VStack {
                Spacer()
                DebugAuditOverlay()
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
            }
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Celebration overlay with congratulatory message")
        .task {
            generateConfetti()
            withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
                animateConfetti = true
            }
            CelebrationAudit.record(
                message: message,
                particleCount: particleCount
            )
            // Accessibility: Post VoiceOver announcement when celebration appears
            if accessibilityEnabled {
                UIAccessibility.post(notification: .announcement, argument: "Congratulations! You've reached an important milestone.")
            }
        }
    }

    private func generateConfetti() {
        confettiParticles = (0..<particleCount).map { _ in ConfettiParticle.random() }
    }
}

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let xPosition: CGFloat
    let yPosition: CGFloat
    let rotation: Angle
    let rotationSpeed: Double
    let delay: Double

    static func random() -> ConfettiParticle {
        ConfettiParticle(
            color: Color(
                red: .random(in: 0.1...1),
                green: .random(in: 0.1...1),
                blue: .random(in: 0.1...1)
            ),
            size: CGFloat.random(in: 6...14),
            xPosition: CGFloat.random(in: 0...1),
            yPosition: 0,
            rotation: Angle.degrees(Double.random(in: 0...360)),
            rotationSpeed: Double.random(in: 30...90),
            delay: Double.random(in: 0...2)
        )
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    let particles: [ConfettiParticle]
    @Binding var animate: Bool

    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                Rectangle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.4)
                    .rotationEffect(animate ? Angle.degrees(particle.rotation.degrees + particle.rotationSpeed) : particle.rotation)
                    .position(x: geo.size.width * particle.xPosition,
                              y: animate ? geo.size.height + particle.size : geo.size.height * particle.yPosition)
                    .animation(
                        Animation.linear(duration: 4)
                            .delay(particle.delay)
                            .repeatForever(autoreverses: false),
                        value: animate
                    )
                    .opacity(animate ? 0 : 1)
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum CelebrationAuditAdmin {
    public static var lastSummary: String { CelebrationAudit.accessibilitySummary }
    public static var lastJSON: String? { CelebrationAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        CelebrationAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    // Expose new analytics properties
    
    /// The most frequent celebration message recorded.
    public static var mostFrequentMessage: String? {
        CelebrationAudit.mostFrequentMessage
    }
    
    /// The average particle count of all celebrations.
    public static var averageParticleCount: Double {
        CelebrationAudit.averageParticleCount
    }
    
    /// The total number of celebration events recorded.
    public static var totalCelebrations: Int {
        CelebrationAudit.totalCelebrations
    }
    
    /// Export the entire celebration audit log as CSV string.
    public static func exportCSV() -> String {
        CelebrationAudit.exportCSV()
    }
}

#if DEBUG
// MARK: - Debug Audit Overlay View
/// A debug overlay showing recent audit events and analytics statistics.
/// Displayed in DEBUG builds at the bottom of the celebration view.
private struct DebugAuditOverlay: View {
    private let maxEventsToShow = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Events (last \(maxEventsToShow)):")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(CelebrationAudit.log.suffix(maxEventsToShow).reversed(), id: \.timestamp) { event in
                Text(event.accessibilityLabel)
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Divider().background(Color.white.opacity(0.5))
            Text("Analytics:")
                .font(.headline)
                .foregroundColor(.white)
            Text("Most Frequent Message: \(CelebrationAudit.mostFrequentMessage ?? "N/A")")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
            Text(String(format: "Average Particle Count: %.2f", CelebrationAudit.averageParticleCount))
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text("Total Celebrations: \(CelebrationAudit.totalCelebrations)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(8)
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct DashboardCelebrationView_Previews: PreviewProvider {
    @State static var isPresented = true

    static var previews: some View {
        DashboardCelebrationView(isPresented: $isPresented)
            .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
#endif

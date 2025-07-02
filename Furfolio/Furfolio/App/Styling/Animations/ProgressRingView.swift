//
//  ProgressRingView.swift
//  Furfolio
//
//  Created by ChatGPT on 6/22/25.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ProgressRingAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ProgressRingView"
}

/**
 ProgressRingView is a reusable SwiftUI component that displays a circular progress ring with customizable colors and thickness.

 Architecture:
 - Built using SwiftUI's declarative view system.
 - Separation of concerns: view rendering and analytics logging are handled independently.
 - Designed for extensibility with configurable colors, line width, and progress value.

 Extensibility:
 - Easily customizable colors and line width.
 - Can be extended to support additional animations or styles.

 Analytics / Audit / Trust Center:
 - Integrates with ProgressRingAnalyticsLoggerProtocol to asynchronously log progress events with audit context.
 - Supports a testMode to enable console-only logging for QA, tests, and previews.
 - Logs include role, staffID, and context for compliance and audit traceability.

 Diagnostics:
 - Provides a public API to retrieve the last 20 analytics events for diagnostics or admin UI.
 - Supports accessibility labels and values for assistive technologies.

 Localization:
 - All user-facing strings and log event messages are wrapped in NSLocalizedString with keys and comments for translators.

 Accessibility:
 - Accessibility elements are properly labeled and values are descriptive for users relying on VoiceOver or other assistive technologies.

 Compliance:
 - Adheres to localization, accessibility, audit logging, and trust center best practices.
 - Designed to meet corporate Trust Center requirements.

 Preview / Testability:
 - Includes SwiftUI previews with testMode enabled for console logging.
 - Analytics logger supports async/await for concurrency and future-proofing.

 Future maintainers should ensure continued adherence to these guidelines when extending or modifying this component.
 */

public protocol ProgressRingAnalyticsLoggerProtocol {
    var testMode: Bool { get }
    func log(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent]
    func escalate(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?) async
}

public struct ProgressRingAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let eventName: String
    public let progress: Double
    public let colorDescription: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

public final class InMemoryProgressRingAnalyticsLogger: ProgressRingAnalyticsLoggerProtocol {
    public var testMode: Bool = false
    private var events: [ProgressRingAnalyticsEvent] = []
    private let queue = DispatchQueue(label: "ProgressRingAnalyticsLogger.queue")
    public func log(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let evt = ProgressRingAnalyticsEvent(
            timestamp: Date(),
            eventName: event,
            progress: progress,
            colorDescription: color,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        queue.async {
            self.events.append(evt)
            if self.events.count > 20 { self.events.removeFirst(self.events.count - 20) }
        }
        if testMode {
            print("[ProgressRingAnalyticsLogger] \(event) progress:\(progress) color:\(color) role:\(role ?? "-") staff:\(staffID ?? "-") ctx:\(context ?? "-")\(escalate ? " [ESCALATE]" : "")")
        }
    }
    public func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent] {
        await withCheckedContinuation { cont in
            queue.async {
                cont.resume(returning: Array(self.events.suffix(count)))
            }
        }
    }
    public func escalate(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?) async {
        await log(event: event, progress: progress, color: color, role: role, staffID: staffID, context: context, escalate: true)
    }
}

public class NullProgressRingAnalyticsLogger: ProgressRingAnalyticsLoggerProtocol {
    public var testMode: Bool = false
    public func log(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [ProgressRingAnalyticsEvent] { [] }
    public func escalate(event: String, progress: Double, color: String, role: String?, staffID: String?, context: String?) async {}
}

struct ProgressRingView: View {
    /// Progress value between 0.0 and 1.0
    var progress: Double

    /// The color of the progress arc
    var color: Color

    /// The color of the background ring
    var backgroundColor: Color

    /// Thickness of the ring
    var lineWidth: CGFloat = 12

    /// Analytics logger instance (injectable)
    var analyticsLogger: ProgressRingAnalyticsLoggerProtocol = InMemoryProgressRingAnalyticsLogger()

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    backgroundColor.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth)
                )

            // Foreground progress ring
            Circle()
                .trim(from: 0.0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            NSLocalizedString(
                "ProgressRingView.accessibilityLabel",
                value: "Progress ring",
                comment: "Accessibility label for the progress ring view"
            )
        )
        .accessibilityValue(
            NSLocalizedString(
                "ProgressRingView.accessibilityValue",
                value: "\(Int(progress * 100)) percent complete",
                comment: "Accessibility value indicating progress percentage"
            )
        )
        .task {
            let colorDesc = color.description
            let escalate = colorDesc.lowercased().contains("red") || progress < 0.1
            await analyticsLogger.log(
                event: NSLocalizedString(
                    "ProgressRingView.analyticsEvent.progressUpdated",
                    value: "Progress updated",
                    comment: "Analytics event name for progress update"
                ),
                progress: progress,
                color: colorDesc,
                role: ProgressRingAuditContext.role,
                staffID: ProgressRingAuditContext.staffID,
                context: ProgressRingAuditContext.context,
                escalate: escalate
            )
        }
    }

    /**
     Public API to fetch the last 20 analytics events for diagnostics or admin UI.

     - Returns: An array of AnalyticsEvent structs representing recent logged events.
     */
    public func fetchRecentAnalyticsEvents() async -> [ProgressRingAnalyticsEvent] {
        return await analyticsLogger.fetchRecentEvents(count: 20)
    }
}

#if DEBUG
struct ProgressRingView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            ProgressRingView(
                progress: 0.9,
                color: .green,
                backgroundColor: .gray.opacity(0.3),
                lineWidth: 16,
                analyticsLogger: {
                    let logger = InMemoryProgressRingAnalyticsLogger()
                    logger.testMode = true
                    return logger
                }()
            )
            .frame(width: 120, height: 120)

            ProgressRingView(
                progress: 0.4,
                color: .orange,
                backgroundColor: .gray.opacity(0.3),
                lineWidth: 16,
                analyticsLogger: {
                    let logger = InMemoryProgressRingAnalyticsLogger()
                    logger.testMode = true
                    return logger
                }()
            )
            .frame(width: 120, height: 120)
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .previewLayout(.sizeThatFits)
        .task {
            // Enable testMode for console logging during previews.
            let logger = InMemoryProgressRingAnalyticsLogger()
            logger.testMode = true
            ProgressRingAuditContext.role = "PreviewRole"
            ProgressRingAuditContext.staffID = "PreviewStaffID"
            ProgressRingAuditContext.context = "PreviewContext"
            await logger.log(
                event: NSLocalizedString(
                    "ProgressRingView.analyticsEvent.previewShown",
                    value: "Preview shown",
                    comment: "Analytics event name for preview display"
                ),
                progress: 0.0,
                color: "N/A",
                role: ProgressRingAuditContext.role,
                staffID: ProgressRingAuditContext.staffID,
                context: ProgressRingAuditContext.context,
                escalate: false
            )
        }
    }
}
#endif

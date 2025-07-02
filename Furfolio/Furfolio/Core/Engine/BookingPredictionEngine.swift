//
//  BookingPredictionEngine.swift
//  Furfolio
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Audit Context (set at login/session)
public struct BookingPredictionAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "BookingPredictionEngine"
}

// MARK: - Analytics/Audit Protocol

public protocol BookingPredictionAnalyticsLogger: AnyObject {
    var testMode: Bool { get set }
    func logEvent(
        _ event: String,
        properties: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

// Null logger for previews/tests: does nothing except optionally print to console.
public final class NullBookingPredictionAnalyticsLogger: BookingPredictionAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func logEvent(
        _ event: String,
        properties: [String : Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[TestMode][NullLogger] \(event) \(properties ?? [:]) role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

// MARK: - Main Engine
public final class BookingPredictionEngine {
    public var analyticsLogger: BookingPredictionAnalyticsLogger

    // Enhanced buffer: (date, event, properties, role, staffID, context, escalate)
    private var analyticsEventBuffer: [(date: Date, event: String, properties: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let bufferCapacity = 20
    private let bufferQueue = DispatchQueue(label: "BookingPredictionEngine.analyticsBuffer")

    public init(analyticsLogger: BookingPredictionAnalyticsLogger = NullBookingPredictionAnalyticsLogger()) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Prediction & Suggestion

    public func predictNextBooking(for userID: String) async throws -> String {
        let logKey = "prediction_attempt"
        let logMsg = NSLocalizedString(
            logKey,
            value: "Predicting next booking for user \(userID)",
            comment: "Analytics: Attempting to predict next booking for a user"
        )
        await logAnalyticsEvent(logMsg, properties: ["userID": userID])
        let prediction = NSLocalizedString(
            "prediction_stub_result",
            value: "Next booking predicted for user \(userID)",
            comment: "Stubbed result for next booking prediction"
        )
        return prediction
    }

    public func suggestSlots(for userID: String) async -> [String] {
        let logKey = "slot_suggestion"
        let logMsg = NSLocalizedString(
            logKey,
            value: "Suggesting slots for user \(userID)",
            comment: "Analytics: Suggesting booking slots for a user"
        )
        await logAnalyticsEvent(logMsg, properties: ["userID": userID])
        return [
            NSLocalizedString("slot_morning", value: "9:00 AM - 10:00 AM", comment: "Suggested morning slot"),
            NSLocalizedString("slot_afternoon", value: "2:00 PM - 3:00 PM", comment: "Suggested afternoon slot")
        ]
    }

    // MARK: - Audit & Diagnostics

    public func auditLog(_ message: String) async {
        let auditKey = "audit_event"
        let auditMsg = NSLocalizedString(
            auditKey,
            value: "Audit: \(message)",
            comment: "Audit log event"
        )
        await logAnalyticsEvent(auditMsg, properties: nil)
    }

    public func diagnostics() -> String {
        let header = NSLocalizedString(
            "diagnostics_header",
            value: "BookingPredictionEngine Diagnostics",
            comment: "Diagnostics header"
        )
        let events = recentAnalyticsEvents().map { event in
            let dateStr = DateFormatter.localizedString(from: event.date, dateStyle: .short, timeStyle: .medium)
            let role = event.role ?? "-"
            let staffID = event.staffID ?? "-"
            let context = event.context ?? "-"
            let escalate = event.escalate ? "YES" : "NO"
            return "\(dateStr): \(event.event) \(event.properties ?? [:]) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }.joined(separator: "\n")
        return "\(header)\n\(events)"
    }

    /// Returns the last N analytics events (for admin/diagnostics), now with audit fields.
    public func recentAnalyticsEvents() -> [(date: Date, event: String, properties: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] {
        bufferQueue.sync {
            return analyticsEventBuffer
        }
    }

    // MARK: - Localization & Accessibility

    public static var predictionFailedErrorMessage: String {
        NSLocalizedString(
            "prediction_failed_error",
            value: "Could not predict the next booking. Please try again.",
            comment: "Error message shown when booking prediction fails"
        )
    }

    public static var predictionSuccessMessage: String {
        NSLocalizedString(
            "prediction_success",
            value: "Booking prediction succeeded.",
            comment: "Status message when prediction succeeds"
        )
    }

    // MARK: - Private Helpers

    /// Log an analytics event and add to buffer, now with audit fields.
    private func logAnalyticsEvent(_ event: String, properties: [String: Any]?) async {
        let escalate = event.lowercased().contains("danger")
            || event.lowercased().contains("critical")
            || event.lowercased().contains("delete")
            || (properties?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)

        await analyticsLogger.logEvent(
            event,
            properties: properties,
            role: BookingPredictionAuditContext.role,
            staffID: BookingPredictionAuditContext.staffID,
            context: BookingPredictionAuditContext.context,
            escalate: escalate
        )

        bufferQueue.sync {
            if analyticsEventBuffer.count >= bufferCapacity {
                analyticsEventBuffer.removeFirst()
            }
            analyticsEventBuffer.append(
                (date: Date(), event: event, properties: properties,
                 role: BookingPredictionAuditContext.role,
                 staffID: BookingPredictionAuditContext.staffID,
                 context: BookingPredictionAuditContext.context,
                 escalate: escalate)
            )
        }
    }
}

#if canImport(SwiftUI)
struct BookingPredictionEngine_Previews: PreviewProvider {
    static var previews: some View {
        DemoView()
            .previewDisplayName("BookingPredictionEngine Diagnostics Preview")
            .environment(\.accessibilityEnabled, true)
    }

    struct DemoView: View {
        @State private var diagnosticsText: String = ""
        private let engine: BookingPredictionEngine

        init() {
            let logger = NullBookingPredictionAnalyticsLogger()
            logger.testMode = true
            self.engine = BookingPredictionEngine(analyticsLogger: logger)
        }

        var body: some View {
            VStack(spacing: 16) {
                Text("BookingPredictionEngine Preview")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Button(NSLocalizedString("predict_button", value: "Predict Next Booking", comment: "Button to trigger prediction")) {
                    Task {
                        do {
                            let result = try await engine.predictNextBooking(for: "demo_user")
                            diagnosticsText = result
                        } catch {
                            diagnosticsText = BookingPredictionEngine.predictionFailedErrorMessage
                        }
                    }
                }
                Button(NSLocalizedString("diagnostics_button", value: "Show Diagnostics", comment: "Button to show diagnostics")) {
                    diagnosticsText = engine.diagnostics()
                }
                ScrollView {
                    Text(diagnosticsText)
                        .font(.body)
                        .accessibilityLabel(NSLocalizedString("diagnostics_label", value: "Diagnostics Output", comment: "Accessibility label for diagnostics output"))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
                .frame(minHeight: 100, maxHeight: 200)
            }
            .padding()
        }
    }
}
#endif

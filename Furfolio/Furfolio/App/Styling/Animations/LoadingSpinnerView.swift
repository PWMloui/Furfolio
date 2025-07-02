//
//  LoadingSpinnerView.swift
//  Furfolio
//
//  Architecture & Extensibility:
//  LoadingSpinnerView is designed as a reusable, theme-aware SwiftUI component for displaying loading spinners.
//  It integrates seamlessly with app-wide design tokens for size, color, and animation duration, ensuring consistent theming.
//  The component supports extensibility via dependency injection of analytics loggers, allowing audit and Trust Center integrations.
//
//  Analytics/Audit & Trust Center Hooks:
//  The SpinnerAnalyticsLogger protocol defines async logging methods, enabling non-blocking event tracking.
//  The built-in NullSpinnerAnalyticsLogger provides a no-op default, while implementations can override for real analytics.
//  A testMode flag allows console-only logging for QA, tests, and previews.
//  The component exposes a public async method to retrieve the last 20 logged events for diagnostics or admin UI.
//
//  Diagnostics & Localization:
//  All user-facing and log event strings are localized using NSLocalizedString with clear keys and comments.
//  This ensures compliance with internationalization and audit requirements.
//
//  Accessibility & Compliance:
//  The spinner is fully accessible with appropriate labels, hints, live region announcements, and accessibility roles.
//  Accessibility elements are carefully managed to provide a clear experience for VoiceOver and other assistive technologies.
//
//  Preview & Testability:
//  The preview provider demonstrates usage with custom analytics loggers and different configurations.
//  Async logging and testMode support make it straightforward to test and audit spinner behavior in various environments.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct SpinnerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "LoadingSpinnerView"
}

// MARK: - Audit Event Model

public struct SpinnerAuditEvent: Identifiable {
    public let id = UUID()
    public let event: String
    public let size: CGFloat
    public let color: Color
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
    public let timestamp: Date
}

// MARK: - Analytics/Audit Protocol

/// Protocol defining asynchronous analytics logging for spinner events.
/// Conforms to async/await to support concurrency and future-proof analytics pipelines.
/// Supports audit context and escalation for compliance and trust center integration.
public protocol SpinnerAnalyticsLogger {
    /// Indicates if the logger is in test mode, where logs are printed to console only.
    var testMode: Bool { get }
    
    /// Logs an analytics event asynchronously with event name, spinner size, color, audit context, and escalation flag.
    /// - Parameters:
    ///   - event: The event name to log.
    ///   - size: The spinner size associated with the event.
    ///   - color: The spinner color associated with the event.
    ///   - role: The user role from audit context.
    ///   - staffID: The staff ID from audit context.
    ///   - context: The context string from audit context.
    ///   - escalate: Flag indicating if this event should be escalated for audit/trust center.
    func log(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?, escalate: Bool) async
    
    /// Fetches recent audit events asynchronously.
    /// - Parameter count: Number of recent events to retrieve.
    /// - Returns: An array of SpinnerAuditEvent.
    func fetchRecentEvents(count: Int) async -> [SpinnerAuditEvent]
    
    /// Escalates a specific event for audit/trust center handling.
    /// - Parameters:
    ///   - event: The event name.
    ///   - size: Spinner size.
    ///   - color: Spinner color.
    ///   - role: User role.
    ///   - staffID: Staff ID.
    ///   - context: Context string.
    func escalate(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?) async
}

/// A no-operation analytics logger implementation.
/// Useful as a default to avoid optionality and for components that do not require analytics.
/// Supports test mode console logging for QA and previews.
public struct NullSpinnerAnalyticsLogger: SpinnerAnalyticsLogger {
    public let testMode: Bool
    
    /// Internal storage for audit events for diagnostics or admin UI.
    private var storedEvents = [SpinnerAuditEvent]()
    
    /// Initializes a NullSpinnerAnalyticsLogger.
    /// - Parameter testMode: If true, logs are printed to console for testing purposes.
    public init(testMode: Bool = false) {
        self.testMode = testMode
    }
    
    /// Asynchronous no-op log method.
    /// Prints to console if in testMode.
    public func log(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        if testMode {
            print("[SpinnerAnalytics - TestMode] \(NSLocalizedString(event, comment: "Spinner event")) size:\(size) color:\(color) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
        // No-op otherwise
    }
    
    /// Returns empty array as no events are stored.
    public func fetchRecentEvents(count: Int) async -> [SpinnerAuditEvent] {
        return []
    }
    
    /// No-op escalate method.
    public func escalate(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?) async {
        // No-op
    }
}

/// A reusable, theme-aware loading spinner for asynchronous operations,
/// with audit/analytics and accessibility support.
struct LoadingSpinnerView: View {
    /// The diameter of the spinner.
    var size: CGFloat = AppTheme.Spacing.xLarge ?? 48
    
    /// The color of the spinner's stroke. Defaults to the app's primary theme color.
    var color: Color = AppTheme.Colors.primary
    
    /// The thickness of the spinner's stroke.
    var lineWidth: CGFloat = AppTheme.Spacing.small ?? 5

    /// Optional custom accessibility label.
    var accessibilityLabel: String = NSLocalizedString("Loading", comment: "Loading spinner accessibility label")
    
    /// Analytics logger (preview/test/QA/BI/Trust Center).
    var analyticsLogger: SpinnerAnalyticsLogger = NullSpinnerAnalyticsLogger()
    
    /// Internal storage for last 20 analytics audit events for diagnostics or admin UI.
    @State private var lastEvents: [SpinnerAuditEvent] = []
    
    // Animation duration (tokenized, safe fallback)
    private let animationDuration: Double = AppTheme.Animation.spinnerDuration ?? 0.8

    @State private var isAnimating = false

    var body: some View {
        // Wrap spinner in a container for accessibility live region (announce loading state)
        ZStack {
            Circle()
                .trim(from: 0.1, to: 1.0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .onAppear {
                    Task {
                        let eventName = NSLocalizedString("spinner_appear", comment: "Spinner appear analytics event")
                        let escalateFlag = size > 64 || color == AppTheme.Colors.warning
                        await analyticsLogger.log(event: eventName, size: size, color: color, role: SpinnerAuditContext.role, staffID: SpinnerAuditContext.staffID, context: SpinnerAuditContext.context, escalate: escalateFlag)
                        addEvent(
                            SpinnerAuditEvent(
                                event: eventName,
                                size: size,
                                color: color,
                                role: SpinnerAuditContext.role,
                                staffID: SpinnerAuditContext.staffID,
                                context: SpinnerAuditContext.context,
                                escalate: escalateFlag,
                                timestamp: Date()
                            )
                        )
                    }
                    withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityAddTraits(.isImage)
                .accessibilityHint(Text(NSLocalizedString("Activity in progress", comment: "Spinner accessibility hint")))
        }
        // Mark the spinner as a live region for VoiceOver
        .accessibilityLiveRegion(.polite)
        .accessibilityRole(.progressIndicator)
    }
    
    /// Adds a new audit event to the internal lastEvents array, keeping only the last 20 events.
    /// - Parameter event: The SpinnerAuditEvent to add.
    private func addEvent(_ event: SpinnerAuditEvent) {
        DispatchQueue.main.async {
            lastEvents.append(event)
            if lastEvents.count > 20 {
                lastEvents.removeFirst(lastEvents.count - 20)
            }
        }
    }
    
    /// Public async method to fetch the last 20 analytics audit events for diagnostics or admin UI.
    /// - Returns: An array of the last 20 logged SpinnerAuditEvent.
    public func fetchLastAnalyticsEvents() async -> [SpinnerAuditEvent] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume(returning: lastEvents)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingSpinnerView_Previews: PreviewProvider {
    struct SpyLogger: SpinnerAnalyticsLogger {
        let testMode: Bool = true
        private var storedEvents = [SpinnerAuditEvent]()
        
        func log(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[SpinnerAnalytics] \(NSLocalizedString(event, comment: "Spinner event")) size:\(size) color:\(color) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
            // In a real implementation, store or send event to analytics backend
        }
        
        func fetchRecentEvents(count: Int) async -> [SpinnerAuditEvent] {
            // Return empty or stored events for preview/testing
            return []
        }
        
        func escalate(event: String, size: CGFloat, color: Color, role: String?, staffID: String?, context: String?) async {
            print("[SpinnerAnalytics - Escalate] \(event) size:\(size) color:\(color) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil")")
        }
    }
    static var previews: some View {
        VStack(spacing: 40) {
            Text("Standard Spinner")
            LoadingSpinnerView(
                analyticsLogger: SpyLogger()
            )
            
            Text("Large Green Spinner")
                .font(AppTheme.Fonts.headline)
            LoadingSpinnerView(
                size: 80,
                color: AppTheme.Colors.success,
                lineWidth: 8,
                analyticsLogger: SpyLogger()
            )
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif

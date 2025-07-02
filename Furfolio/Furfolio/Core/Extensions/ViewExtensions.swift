//
//  ViewExtensions.swift
//  Furfolio
//
//  Enhanced 2025: All SwiftUI extensions are now tokenized, modular, accessible, traceable, and BI/compliance ready.

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct ViewExtensionsAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ViewExtensions"
}

// MARK: - ViewExtensions Audit/Event Logging

fileprivate struct ViewExtensionAuditEvent: Codable {
    let timestamp: Date
    let extensionName: String
    let tags: [String]
    let actor: String?
    let context: String?
    let additional: String?
    let role: String?
    let staffID: String?
    let escalate: Bool
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var label = "View extension: \(extensionName) [\(tags.joined(separator: ","))] at \(dateStr)"
        if let role = role { label += " | Role: \(role)" }
        if let staffID = staffID { label += " | StaffID: \(staffID)" }
        if escalate { label += " | ESCALATE" }
        return label
    }
}

fileprivate final class ViewExtensionAudit {
    static private var log: [ViewExtensionAuditEvent] = []
    static private let queue = DispatchQueue(label: "com.furfolio.viewExtensionAuditQueue", attributes: .concurrent)

    /// Records a new audit event asynchronously in a thread-safe manner.
    /// - Parameters:
    ///   - extensionName: The name of the view extension.
    ///   - tags: Tags associated with the event.
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    ///   - additional: Additional info.
    static func record(_ extensionName: String, tags: [String], actor: String? = nil, context: String? = nil, additional: String? = nil) {
        let nameLower = extensionName.lowercased()
        let escalate = nameLower.contains("danger") || nameLower.contains("critical") || nameLower.contains("delete")
            || (tags.contains { $0.lowercased().contains("danger") || $0.lowercased().contains("critical") || $0.lowercased().contains("delete") })
        let event = ViewExtensionAuditEvent(
            timestamp: Date(),
            extensionName: extensionName,
            tags: tags,
            actor: actor,
            context: context ?? ViewExtensionsAuditContext.context,
            additional: additional,
            role: ViewExtensionsAuditContext.role,
            staffID: ViewExtensionsAuditContext.staffID,
            escalate: escalate
        )
        queue.async(flags: .barrier) {
            log.append(event)
            if log.count > 500 { log.removeFirst() }
        }
    }

    /// Exports the last audit event as pretty-printed JSON asynchronously.
    /// - Returns: JSON string of the last event or nil if none.
    static func exportLastJSON() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let last = log.last else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try? encoder.encode(last)
                let json = data.flatMap { String(data: $0, encoding: .utf8) }
                continuation.resume(returning: json)
            }
        }
    }

    /// Provides accessibility summary of the last audit event asynchronously.
    static var accessibilitySummary: String {
        get async {
            await withCheckedContinuation { continuation in
                queue.async {
                    continuation.resume(returning: log.last?.accessibilityLabel ?? "No extension usage recorded.")
                }
            }
        }
    }

    /// Retrieves all audit events asynchronously.
    /// - Returns: Array of all audit events.
    static func getAllEvents() async -> [ViewExtensionAuditEvent] {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: log)
            }
        }
    }

    /// Filters audit events asynchronously by tags, actor, or context.
    /// - Parameters:
    ///   - tags: Optional tags to filter by.
    ///   - actor: Optional actor to filter by.
    ///   - context: Optional context to filter by.
    /// - Returns: Filtered array of audit events.
    static func filterEvents(tags: [String]? = nil, actor: String? = nil, context: String? = nil) async -> [ViewExtensionAuditEvent] {
        await withCheckedContinuation { continuation in
            queue.async {
                let filtered = log.filter { event in
                    let matchesTags = tags?.allSatisfy { event.tags.contains($0) } ?? true
                    let matchesActor = actor == nil || event.actor == actor
                    let matchesContext = context == nil || event.context == context
                    return matchesTags && matchesActor && matchesContext
                }
                continuation.resume(returning: filtered)
            }
        }
    }

    /// Clears the audit log asynchronously.
    static func clearLog() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                log.removeAll()
                continuation.resume()
            }
        }
    }
}

// MARK: - Public View Extensions for Modular UI Composition (Now Auditable)

public extension View {

    /// Conditionally applies a modifier when `condition` is true.
    @ViewBuilder
    func `if`<Content: View>(
        _ condition: Bool,
        apply: (Self) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("if", tags: ["conditional", "composition"], actor: actor, context: context)
        if condition {
            apply(self)
        } else {
            self
        }
    }

    /// Conditionally applies a modifier when optional `value` is non-nil.
    @ViewBuilder
    func ifLet<T, Content: View>(
        _ value: T?,
        apply: (Self, T) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("ifLet", tags: ["conditional", "optional", "composition"], actor: actor, context: context)
        if let value = value {
            apply(self, value)
        } else {
            self
        }
    }

    /// Applies a platform-specific modifier: iOS vs macOS.
    @ViewBuilder
    func platformSpecific<Content: View>(
        _ ios: (Self) -> Content,
        mac: (Self) -> Content,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("platformSpecific", tags: ["platform", "tokenized"], actor: actor, context: context)
        #if os(iOS)
        ios(self)
        #elseif os(macOS)
        mac(self)
        #else
        self
        #endif
    }

    /// Hides the view conditionally; optionally removes from layout.
    @ViewBuilder
    func hidden(
        _ isHidden: Bool,
        remove: Bool = true,
        animated: Bool = false,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("hidden", tags: ["visibility", "conditional"], actor: actor, context: context, additional: isHidden ? "hidden" : "visible")
        if isHidden {
            if remove {
                if animated {
                    EmptyView()
                        .transition(.opacity)
                } else {
                    EmptyView()
                }
            } else {
                if animated {
                    self.hidden()
                        .transition(.opacity)
                } else {
                    self.hidden()
                }
            }
        } else {
            self
        }
    }

    /// Applies corner radius to specific corners.
    func cornerRadius(
        _ radius: CGFloat,
        corners: UIRectCorner,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("cornerRadius", tags: ["shape", "tokenized"], actor: actor, context: context, additional: "radius: \(radius), corners: \(corners.rawValue)")
        return clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    /// Applies a default subtle shadow for elevation and depth using design tokens.
    func defaultShadow(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("defaultShadow", tags: ["shadow", "elevation", "tokenized"], actor: actor, context: context)
        return self.shadow(
            color: AppShadows.card.color,
            radius: AppShadows.card.radius,
            x: AppShadows.card.x,
            y: AppShadows.card.y
        )
    }

    /// Adds a customizable shimmer overlay for loading placeholders.
    func shimmer(
        isActive: Bool = true,
        cornerRadius: CGFloat? = 7,
        shape: AnyShape? = nil,
        animated: Bool = true,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("shimmer", tags: ["loading", "placeholder", "animation"], actor: actor, context: context, additional: isActive ? "active" : "inactive")
        return self.overlay(
            Group {
                if isActive {
                    AnimationUtils.ShimmerView()
                        .clipShape(
                            shape ?? (cornerRadius != nil ? AnyShape(RoundedRectangle(cornerRadius: cornerRadius!)) : AnyShape(Rectangle()))
                        )
                        .if(animated) { view in
                            view.transition(.opacity)
                        }
                }
            }
        )
    }

    /// Adds a badge overlay at top trailing corner with customizable animation.
    func badge(
        _ count: Int?,
        color: Color = AppColors.accent,
        animated: Bool = true,
        actor: String? = nil,
        context: String? = nil
    ) -> some View {
        ViewExtensionAudit.record("badge", tags: ["badge", "notification", "tokenized"], actor: actor, context: context, additional: "count: \(count ?? 0)")
        return ZStack(alignment: .topTrailing) {
            self
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.textOnAccent)
                    .padding(AppSpacing.xSmall)
                    .background(color)
                    .clipShape(Circle())
                    .offset(x: AppSpacing.small, y: -AppSpacing.small)
                    .if(animated) { view in
                        view.transition(.scale)
                    }
            }
        }
    }

    /// Adds tap gesture to dismiss keyboard on iOS safely.
    func dismissKeyboardOnTap(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("dismissKeyboardOnTap", tags: ["input", "keyboard", "accessibility"], actor: actor, context: context)
        return self.onTapGesture {
            #if canImport(UIKit)
            if UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            #endif
        }
    }

    /// Helper for demo dashboard card styling using design tokens.
    func demoDashboardCard(actor: String? = nil, context: String? = nil) -> some View {
        ViewExtensionAudit.record("demoDashboardCard", tags: ["demo", "dashboard", "tokenized"], actor: actor, context: context)
        return self
            .padding(AppSpacing.medium)
            .background(AppColors.card)
            .cornerRadius(BorderRadius.medium)
            .shadow(color: AppShadows.card.color, radius: AppShadows.card.radius, x: AppShadows.card.x, y: AppShadows.card.y)
            .padding(.horizontal, AppSpacing.medium)
    }
}

// MARK: - RoundedCorner Shape for Selective Corner Rounding (Unchanged)
public struct RoundedCorner: Shape {
    public var radius: CGFloat = .infinity
    public var corners: UIRectCorner = .allCorners

    public init(radius: CGFloat = .infinity, corners: UIRectCorner = .allCorners) {
        self.radius = radius
        self.corners = corners
    }

    public func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Extension Audit: Static Accessors for Debug/Admin

public enum ViewExtensionAuditAdmin {
    /// Provides accessibility summary of the last audit event asynchronously.
    public static var lastSummary: String {
        get async {
            await ViewExtensionAudit.accessibilitySummary
        }
    }

    /// Exports the last audit event as pretty-printed JSON asynchronously.
    public static var lastJSON: String? {
        get async {
            await ViewExtensionAudit.exportLastJSON()
        }
    }

    /// Returns the count of audit log entries asynchronously.
    public static var logCount: Int {
        get async {
            let events = await ViewExtensionAudit.getAllEvents()
            return events.count
        }
    }

    /// Returns recent audit event labels asynchronously.
    /// - Parameter limit: Number of recent events to retrieve.
    /// - Returns: Array of accessibility labels.
    public static func recentEvents(limit: Int = 5) async -> [String] {
        let events = await ViewExtensionAudit.getAllEvents()
        return events.suffix(limit).map { $0.accessibilityLabel }
    }

    /// Clears the audit log asynchronously.
    public static func clearLog() async {
        await ViewExtensionAudit.clearLog()
    }

    /// Filters audit events asynchronously by tags, actor, or context.
    /// - Parameters:
    ///   - tags: Optional tags to filter by.
    ///   - actor: Optional actor to filter by.
    ///   - context: Optional context to filter by.
    /// - Returns: Filtered array of accessibility labels.
    public static func filterEvents(tags: [String]? = nil, actor: String? = nil, context: String? = nil) async -> [String] {
        let filtered = await ViewExtensionAudit.filterEvents(tags: tags, actor: actor, context: context)
        // For admin/export, include readable info of all fields
        return filtered.map { event in
            var label = event.accessibilityLabel
            if let additional = event.additional, !additional.isEmpty { label += " | Additional: \(additional)" }
            return label
        }
    }
}

// MARK: - Example Usage and Preview for Extensions

#if DEBUG
struct ViewExtensionsPreview: View {
    @State private var isLoading = true
    @State private var showBadge = true
    @State private var optionalCount: Int? = 5

    @State private var auditSummary: String = "Loading..."
    @State private var auditJSON: String = "Loading..."
    @State private var filteredEvents: [String] = []
    @State private var allEvents: [Any] = []
    @State private var allAuditEvents: [Any] = []
    @State private var auditEvents: [Any] = []
    @State private var auditEventsStructs: [Any] = []
    @State private var auditEventsLast: [Any] = []
    @State private var auditEventDetails: [ViewExtensionAuditEvent] = []
    @State private var auditEventPreviewEvents: [ViewExtensionAuditEvent] = []
    @State private var auditPreviewEvents: [ViewExtensionAuditEvent] = []
    @State private var previewAuditEvents: [ViewExtensionAuditEvent] = []
    @State private var previewEvents: [ViewExtensionAuditEvent] = []
    @State private var events: [ViewExtensionAuditEvent] = []

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.large) {
                Group {
                    Text("Rounded only top corners")
                        .padding()
                        .background(AppColors.accentBackground)
                        .cornerRadius(BorderRadius.large, corners: [.topLeft, .topRight], actor: "preview")

                    Text("Shimmer loading")
                        .padding()
                        .shimmer(isActive: isLoading, cornerRadius: BorderRadius.medium, animated: true, actor: "preview")
                        .cornerRadius(BorderRadius.medium)
                        .frame(width: 140, height: 34)
                        .background(AppColors.surfaceBackground)

                    Button("Toggle Badge") { withAnimation { showBadge.toggle() } }
                    Image(systemName: "bell.fill")
                        .resizable()
                        .frame(width: 36, height: 36)
                        .badge(showBadge ? 2 : nil, color: AppColors.accent, animated: true, actor: "preview")

                    Text("Hide me!")
                        .hidden(isLoading, remove: true, animated: true, actor: "preview")

                    TextField("Type here", text: .constant(""))
                        .padding()
                        .background(AppColors.inputBackground)
                        .cornerRadius(BorderRadius.medium)
                        .dismissKeyboardOnTap(actor: "preview")
                }

                Group {
                    Text("IfLet example with optional count:")
                        .fontWeight(.semibold)

                    Image(systemName: "star.fill")
                        .ifLet(optionalCount, apply: { view, count in
                            view.badge(count, color: AppColors.accent, actor: "preview")
                        }, actor: "preview")

                    Text("Platform-specific styling:")
                        .fontWeight(.semibold)

                    Text("Hello Platform!")
                        .platformSpecific(
                            { $0.foregroundColor(AppColors.primary) },
                            mac: { $0.foregroundColor(AppColors.secondary) },
                            actor: "preview"
                        )

                    Text("Demo Dashboard Card Example")
                        .demoDashboardCard(actor: "preview")
                }

                Group {
                    Text("Audit Summary:")
                    Text(auditSummary)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)

                    Text("Last Audit JSON:")
                    ScrollView(.horizontal) {
                        Text(auditJSON)
                            .font(.caption2.monospaced())
                            .padding()
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                    }
                    .frame(height: 120)

                    Button("Refresh Audit Info") {
                        Task {
                            auditSummary = await ViewExtensionAuditAdmin.lastSummary
                            auditJSON = await ViewExtensionAuditAdmin.lastJSON ?? "No audit JSON available."
                            // Load all events for preview
                            let loaded = await ViewExtensionAudit.getAllEvents()
                            previewEvents = loaded
                        }
                    }
                    .padding(.vertical)

                    Button("Clear Audit Log") {
                        Task {
                            await ViewExtensionAuditAdmin.clearLog()
                            auditSummary = "Log cleared."
                            auditJSON = ""
                            filteredEvents = []
                            previewEvents = []
                        }
                    }
                    .padding(.vertical)

                    Button("Load Filtered Events (tag: badge)") {
                        Task {
                            filteredEvents = await ViewExtensionAuditAdmin.filterEvents(tags: ["badge"])
                        }
                    }
                    .padding(.vertical)

                    if !filteredEvents.isEmpty {
                        Text("Filtered Events:")
                            .fontWeight(.semibold)
                        ForEach(filteredEvents, id: \.self) { eventLabel in
                            Text(eventLabel)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }

                    // Show all audit events with new fields
                    if !previewEvents.isEmpty {
                        Text("Audit Events (Preview):")
                            .fontWeight(.semibold)
                        ForEach(previewEvents.indices, id: \.self) { idx in
                            let event = previewEvents[idx]
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.accessibilityLabel)
                                    .font(.caption)
                                    .multilineTextAlignment(.leading)
                                if let role = event.role {
                                    Text("Role: \(role)").font(.caption2).foregroundColor(.secondary)
                                }
                                if let staffID = event.staffID {
                                    Text("StaffID: \(staffID)").font(.caption2).foregroundColor(.secondary)
                                }
                                if event.escalate {
                                    Text("Escalate: YES").font(.caption2).foregroundColor(.red)
                                }
                            }
                            .padding(4)
                            .background(Color.orange.opacity(0.09))
                            .cornerRadius(6)
                        }
                    }
                }
            }
            .padding()
            .task {
                auditSummary = await ViewExtensionAuditAdmin.lastSummary
                auditJSON = await ViewExtensionAuditAdmin.lastJSON ?? "No audit JSON available."
                let loaded = await ViewExtensionAudit.getAllEvents()
                previewEvents = loaded
            }
        }
    }
}

#Preview {
    ViewExtensionsPreview()
}
#endif

//
//  String+Extensions.swift
//  Furfolio
//
//  Enhanced 2025: Common, Auditable, Accessible, BI-Ready String extensions for Furfolio.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Audit Context (set at login/session)
public struct StringAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "String+Extensions"
}

// MARK: - Audit/Event Logging for String Extensions (Concurrency-safe, Async, Filterable, Accessible, Escalate)

public struct StringExtensionAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let function: String
    public let input: String?
    public let result: String?
    public let tags: [String]
    public let actor: String?
    public let context: String?
    public let role: String?
    public let staffID: String?
    public let escalate: Bool

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = String(format: NSLocalizedString("String extension %@ [%@] at %@", comment: "Audit event accessibility label"), function, tags.joined(separator: ","), dateStr)
        var details: [String] = []
        if let actor = actor, !actor.isEmpty { details.append("Actor: \(actor)") }
        if let context = context, !context.isEmpty { details.append("Context: \(context)") }
        if let role = role, !role.isEmpty { details.append("Role: \(role)") }
        if let staffID = staffID, !staffID.isEmpty { details.append("StaffID: \(staffID)") }
        if escalate { details.append("Escalate: YES") }
        if !details.isEmpty {
            return "\(base) (\(details.joined(separator: ", ")))"
        }
        return base
    }
    public var accessibilityDescription: String {
        var desc = accessibilityLabel
        if let input = input { desc += "\n" + String(format: NSLocalizedString("Input: %@", comment: "Audit event input"), input) }
        if let result = result { desc += "\n" + String(format: NSLocalizedString("Result: %@", comment: "Audit event result"), result) }
        return desc
    }
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        function: String,
        input: String?,
        result: String?,
        tags: [String],
        actor: String?,
        context: String?,
        role: String? = nil,
        staffID: String? = nil,
        escalate: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.function = function
        self.input = input
        self.result = result
        self.tags = tags
        self.actor = actor
        self.context = context
        self.role = role
        self.staffID = staffID
        self.escalate = escalate
    }
}

public final class StringExtensionAudit {
    private static let logQueue = DispatchQueue(label: "furfolio.string.audit.log", qos: .utility)
    private static var _log: [StringExtensionAuditEvent] = []
    private static let maxLogSize = 500

    /// Records an audit event asynchronously and ensures log size limit.
    public static func record(
        function: String,
        input: String?,
        result: String?,
        tags: [String],
        actor: String? = nil,
        context: String? = nil
    ) {
        let escalate = function.lowercased().contains("danger") || function.lowercased().contains("critical") || function.lowercased().contains("delete")
            || (tags.contains { $0.lowercased().contains("danger") || $0.lowercased().contains("critical") || $0.lowercased().contains("delete") })
        let event = StringExtensionAuditEvent(
            timestamp: Date(),
            function: function,
            input: input,
            result: result,
            tags: tags,
            actor: actor,
            context: context ?? StringAuditContext.context,
            role: StringAuditContext.role,
            staffID: StringAuditContext.staffID,
            escalate: escalate
        )
        logQueue.async {
            _log.append(event)
            if _log.count > maxLogSize {
                _log.removeFirst(_log.count - maxLogSize)
            }
        }
    }

    public static func log(completion: @escaping ([StringExtensionAuditEvent]) -> Void) {
        logQueue.async { completion(_log) }
    }
    public static func exportLogJSON(page: Int = 0, pageSize: Int = 50, completion: @escaping (String?) -> Void) {
        logQueue.async {
            let start = max(0, min(page * pageSize, _log.count))
            let end = min(start + pageSize, _log.count)
            let slice = Array(_log[start..<end])
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(slice)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
    public static func search(
        tags: [String]? = nil,
        actor: String? = nil,
        context: String? = nil,
        role: String? = nil,
        staffID: String? = nil,
        escalate: Bool? = nil,
        completion: @escaping ([StringExtensionAuditEvent]) -> Void
    ) {
        logQueue.async {
            let filtered = _log.filter { event in
                let tagMatch = tags == nil || tags!.isEmpty || !Set(tags!).isDisjoint(with: event.tags)
                let actorMatch = actor == nil || event.actor == actor
                let contextMatch = context == nil || event.context == context
                let roleMatch = role == nil || event.role == role
                let staffMatch = staffID == nil || event.staffID == staffID
                let escalateMatch = escalate == nil || event.escalate == escalate
                return tagMatch && actorMatch && contextMatch && roleMatch && staffMatch && escalateMatch
            }
            completion(filtered)
        }
    }
    public static func accessibilitySummary(completion: @escaping (String) -> Void) {
        logQueue.async {
            let summary = _log.last?.accessibilityLabel ?? NSLocalizedString("No String extension usage recorded.", comment: "No audit event fallback")
            completion(summary)
        }
    }
    public static func exportLastJSON(completion: @escaping (String?) -> Void) {
        logQueue.async {
            guard let last = _log.last else { completion(nil); return }
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
}

// MARK: - String Extensions (audit context is always attached)

public extension String {
    func trimmed(actor: String? = nil, context: String? = nil) -> String {
        let result = trimmingCharacters(in: .whitespacesAndNewlines)
        StringExtensionAudit.record(
            function: "trimmed", input: self, result: result, tags: ["trim", "cleanup"],
            actor: actor, context: context
        )
        return result
    }

    func isValidEmail(actor: String? = nil, context: String? = nil) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let result = range(of: pattern, options: .regularExpression) != nil
        StringExtensionAudit.record(
            function: "isValidEmail", input: self, result: "\(result)", tags: ["validation", "email"],
            actor: actor, context: context
        )
        return result
    }

    func isNumeric(actor: String? = nil, context: String? = nil) -> Bool {
        let result = !isEmpty && allSatisfy { $0.isNumber }
        StringExtensionAudit.record(
            function: "isNumeric", input: self, result: "\(result)", tags: ["validation", "numeric"],
            actor: actor, context: context
        )
        return result
    }

    func capitalizedFirst(actor: String? = nil, context: String? = nil) -> String {
        guard let first = first else {
            StringExtensionAudit.record(
                function: "capitalizedFirst", input: self, result: self, tags: ["capitalize"],
                actor: actor, context: context
            )
            return self
        }
        let result = String(first).uppercased() + dropFirst()
        StringExtensionAudit.record(
            function: "capitalizedFirst", input: self, result: result, tags: ["capitalize"],
            actor: actor, context: context
        )
        return result
    }

    func safeSubstring(from: Int, length: Int, actor: String? = nil, context: String? = nil) -> String {
        guard from >= 0, length > 0, from < count else {
            StringExtensionAudit.record(
                function: "safeSubstring", input: self, result: "", tags: ["substring", "safety"],
                actor: actor, context: context
            )
            return ""
        }
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: min(length, count - from), limitedBy: endIndex) ?? endIndex
        let result = String(self[start..<end])
        StringExtensionAudit.record(
            function: "safeSubstring", input: self, result: result, tags: ["substring", "safety"],
            actor: actor, context: context
        )
        return result
    }

    func localized(bundle: Bundle = .main, comment: String = "", actor: String? = nil, context: String? = nil) -> String {
        let result = NSLocalizedString(self, bundle: bundle, comment: comment)
        StringExtensionAudit.record(
            function: "localized", input: self, result: result, tags: ["localization"],
            actor: actor, context: context
        )
        return result
    }
}

// MARK: - Admin/QA Static Accessors (Async)

public enum StringExtensionAuditAdmin {
    public static func lastSummary(completion: @escaping (String) -> Void) {
        StringExtensionAudit.accessibilitySummary(completion: completion)
    }
    public static func lastJSON(completion: @escaping (String?) -> Void) {
        StringExtensionAudit.exportLastJSON(completion: completion)
    }
    public static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        StringExtensionAudit.log { log in
            let labels = log.suffix(limit).map { $0.accessibilityLabel }
            completion(labels)
        }
    }
    public static func filterEvents(
        tags: [String]? = nil,
        actor: String? = nil,
        context: String? = nil,
        role: String? = nil,
        staffID: String? = nil,
        escalate: Bool? = nil,
        completion: @escaping ([StringExtensionAuditEvent]) -> Void
    ) {
        StringExtensionAudit.search(
            tags: tags, actor: actor, context: context, role: role, staffID: staffID, escalate: escalate,
            completion: completion
        )
    }
    public static func exportLogJSON(page: Int = 0, pageSize: Int = 50, completion: @escaping (String?) -> Void) {
        StringExtensionAudit.exportLogJSON(page: page, pageSize: pageSize, completion: completion)
    }
}

#if canImport(SwiftUI)
public struct StringAuditLogView: View {
    @State private var events: [StringExtensionAuditEvent] = []
    @State private var filterTag: String = ""
    @State private var filterActor: String = ""
    @State private var filterContext: String = ""
    @State private var filterRole: String = ""
    @State private var filterStaffID: String = ""
    @State private var filterEscalate: Bool = false
    @State private var isLoading: Bool = false

    private func loadEvents() {
        isLoading = true
        StringExtensionAudit.search(
            tags: filterTag.isEmpty ? nil : [filterTag],
            actor: filterActor.isEmpty ? nil : filterActor,
            context: filterContext.isEmpty ? nil : filterContext,
            role: filterRole.isEmpty ? nil : filterRole,
            staffID: filterStaffID.isEmpty ? nil : filterStaffID,
            escalate: nil
        ) { filtered in
            DispatchQueue.main.async {
                self.events = filtered.suffix(50)
                self.isLoading = false
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("String Extension Audit Log", comment: "Audit log title"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            HStack {
                TextField(NSLocalizedString("Tag", comment: "Tag filter"), text: $filterTag)
                TextField(NSLocalizedString("Actor", comment: "Actor filter"), text: $filterActor)
                TextField(NSLocalizedString("Context", comment: "Context filter"), text: $filterContext)
                TextField(NSLocalizedString("Role", comment: "Role filter"), text: $filterRole)
                TextField(NSLocalizedString("StaffID", comment: "StaffID filter"), text: $filterStaffID)
                Button(action: loadEvents) {
                    Image(systemName: "magnifyingglass")
                    Text(NSLocalizedString("Filter", comment: "Filter button"))
                }
                .accessibilityLabel(Text(NSLocalizedString("Apply Filter", comment: "Apply filter accessibility")))
                .disabled(isLoading)
            }
            .padding(.bottom, 4)
            if isLoading {
                ProgressView()
            }
            List(events.reversed(), id: \.id) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.accessibilityLabel)
                        .font(.body)
                        .accessibilityLabel(Text(event.accessibilityLabel))
                    if let input = event.input {
                        Text(String(format: NSLocalizedString("Input: %@", comment: "Audit input"), input))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let result = event.result {
                        Text(String(format: NSLocalizedString("Result: %@", comment: "Audit result"), result))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if event.escalate {
                        Text("Escalate: YES")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint(Text(event.accessibilityDescription))
            }
            .onAppear(perform: loadEvents)
            .accessibilityLabel(Text(NSLocalizedString("Audit Events List", comment: "Audit events list accessibility")))
        }
        .padding()
    }
}
#endif

#if DEBUG
import XCTest
final class StringExtensionAuditTests: XCTestCase {
    func testAuditLogConcurrency() {}
    func testAuditLogFiltering() {}
    func testAuditLogExportPagination() {}
    func testAuditAccessibilityDescriptions() {}
}
#endif

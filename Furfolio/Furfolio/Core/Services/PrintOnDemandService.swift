//
//  PrintOnDemandService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


import Foundation
import UIKit
import SwiftUI

/**
 PrintOnDemandService
 --------------------
 A centralized service for generating and sending documents to AirPrint or PDF in Furfolio, with async analytics and audit logging.

 - **Purpose**: Renders printable views and dispatches print jobs or PDF exports.
 - **Architecture**: Singleton `ObservableObject` service using UIKit `UIPrintInteractionController`.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: User-facing messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol PrintOnDemandAnalyticsLogger {
    /// Log a print event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol PrintOnDemandAuditLogger {
    /// Record a print audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullPrintOnDemandAnalyticsLogger: PrintOnDemandAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullPrintOnDemandAuditLogger: PrintOnDemandAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a print-on-demand audit event.
public struct PrintOnDemandAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging print-on-demand events.
public actor PrintOnDemandAuditManager {
    private var buffer: [PrintOnDemandAuditEntry] = []
    private let maxEntries = 100
    public static let shared = PrintOnDemandAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: PrintOnDemandAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [PrintOnDemandAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as pretty-printed JSON.
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

// MARK: - Service

@MainActor
public final class PrintOnDemandService: ObservableObject {
    public static let shared = PrintOnDemandService(
        analytics: NullPrintOnDemandAnalyticsLogger(),
        audit: NullPrintOnDemandAuditLogger()
    )

    private let analytics: PrintOnDemandAnalyticsLogger
    private let audit: PrintOnDemandAuditLogger

    private init(
        analytics: PrintOnDemandAnalyticsLogger,
        audit: PrintOnDemandAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Generates a printable PDF from the given SwiftUI view.
    public func generatePDF<V: View>(from view: V, size: CGSize) async -> Data? {
        Task {
            await analytics.log(event: "pdf_generation_start", metadata: nil)
            await audit.record("PDF generation started", metadata: nil)
            await PrintOnDemandAuditManager.shared.add(
                PrintOnDemandAuditEntry(event: "pdf_start", detail: nil)
            )
        }
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        guard let uiImage = renderer.uiImage else { return nil }
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(origin: .zero, size: size), nil)
        UIGraphicsBeginPDFPage()
        uiImage.draw(in: CGRect(origin: .zero, size: size))
        UIGraphicsEndPDFContext()
        Task {
            await analytics.log(event: "pdf_generation_complete", metadata: nil)
            await audit.record("PDF generation completed", metadata: nil)
            await PrintOnDemandAuditManager.shared.add(
                PrintOnDemandAuditEntry(event: "pdf_complete", detail: nil)
            )
        }
        return pdfData as Data
    }

    /// Presents the iOS print interaction for the given PDF data.
    public func presentPrintInteraction(with pdfData: Data, from viewController: UIViewController) async {
        Task {
            await analytics.log(event: "print_interaction_start", metadata: nil)
            await audit.record("Print interaction started", metadata: nil)
            await PrintOnDemandAuditManager.shared.add(
                PrintOnDemandAuditEntry(event: "print_start", detail: nil)
            )
        }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.showsNumberOfCopies = true
        printController.printingItem = pdfData
        await withCheckedContinuation { continuation in
            printController.present(animated: true) { _, completed, error in
                Task {
                    if let error = error {
                        await analytics.log(event: "print_interaction_error", metadata: ["error": error.localizedDescription])
                        await audit.record("Print interaction error", metadata: ["error": error.localizedDescription])
                        await PrintOnDemandAuditManager.shared.add(
                            PrintOnDemandAuditEntry(event: "print_error", detail: error.localizedDescription)
                        )
                    } else if completed {
                        await analytics.log(event: "print_interaction_complete", metadata: nil)
                        await audit.record("Print interaction completed", metadata: nil)
                        await PrintOnDemandAuditManager.shared.add(
                            PrintOnDemandAuditEntry(event: "print_complete", detail: nil)
                        )
                    }
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Diagnostics

public extension PrintOnDemandService {
    /// Fetch recent print-on-demand audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [PrintOnDemandAuditEntry] {
        await PrintOnDemandAuditManager.shared.recent(limit: limit)
    }

    /// Export print-on-demand audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await PrintOnDemandAuditManager.shared.exportJSON()
    }
}

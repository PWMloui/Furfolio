//
//  QRCodeGeneratorService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/**
 QRCodeGeneratorService
 ----------------------
 A centralized service for generating QR codes in Furfolio, with async analytics and audit logging.

 - **Purpose**: Encodes strings into QR code images for shareable and scannable content.
 - **Architecture**: Singleton `ObservableObject` service using CoreImage.
 - **Concurrency & Async Logging**: All generation methods are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol QRCodeAnalyticsLogger {
    /// Log a QR code generation event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol QRCodeAuditLogger {
    /// Record a QR code audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullQRCodeAnalyticsLogger: QRCodeAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullQRCodeAuditLogger: QRCodeAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a QR code generation audit event.
public struct QRCodeAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging QR code events.
public actor QRCodeAuditManager {
    private var buffer: [QRCodeAuditEntry] = []
    private let maxEntries = 100
    public static let shared = QRCodeAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: QRCodeAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [QRCodeAuditEntry] {
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
public final class QRCodeGeneratorService: ObservableObject {
    public static let shared = QRCodeGeneratorService(
        analytics: NullQRCodeAnalyticsLogger(),
        audit: NullQRCodeAuditLogger()
    )

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private let analytics: QRCodeAnalyticsLogger
    private let audit: QRCodeAuditLogger

    private init(
        analytics: QRCodeAnalyticsLogger,
        audit: QRCodeAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Generates a SwiftUI Image representing the QR code for the given string.
    public func generateImage(from string: String, size: CGSize = CGSize(width: 200, height: 200)) async -> Image? {
        Task {
            await analytics.log(event: "generate_start", metadata: ["string": string])
            await audit.record("QR generation started", metadata: ["string": String(string.prefix(16))])
            await QRCodeAuditManager.shared.add(
                QRCodeAuditEntry(event: "generate_start", detail: String(string.prefix(16)))
            )
        }

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: size.width / outputImage.extent.width,
                                                                     y: size.height / outputImage.extent.height))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)

        Task {
            await analytics.log(event: "generate_complete", metadata: nil)
            await audit.record("QR generation completed", metadata: nil)
            await QRCodeAuditManager.shared.add(
                QRCodeAuditEntry(event: "generate_complete", detail: nil)
            )
        }

        return Image(uiImage: uiImage)
    }
}

// MARK: - Diagnostics

public extension QRCodeGeneratorService {
    /// Fetch recent QR code audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [QRCodeAuditEntry] {
        await QRCodeAuditManager.shared.recent(limit: limit)
    }

    /// Export QR code audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await QRCodeAuditManager.shared.exportJSON()
    }
}

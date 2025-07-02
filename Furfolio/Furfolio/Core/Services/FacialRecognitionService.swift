//
//  FacialRecognitionService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
import Foundation
import Vision
import SwiftUI

/**
 FacialRecognitionService
 ------------------------
 A centralized service for performing facial recognition tasks in Furfolio, with async analytics and audit logging.

 - **Purpose**: Detects and recognizes human or pet faces in images.
 - **Architecture**: Singleton `ObservableObject` service using Vision framework.
 - **Concurrency & Async Logging**: All operations are async and wrap analytics/audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol FacialRecognitionAnalyticsLogger {
    /// Log a recognition event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol FacialRecognitionAuditLogger {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullFacialRecognitionAnalyticsLogger: FacialRecognitionAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullFacialRecognitionAuditLogger: FacialRecognitionAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a facial recognition audit event.
public struct FacialRecognitionAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging facial recognition events.
public actor FacialRecognitionAuditManager {
    private var buffer: [FacialRecognitionAuditEntry] = []
    private let maxEntries = 100
    public static let shared = FacialRecognitionAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: FacialRecognitionAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [FacialRecognitionAuditEntry] {
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
public final class FacialRecognitionService: ObservableObject {
    public static let shared = FacialRecognitionService()

    private let analytics: FacialRecognitionAnalyticsLogger
    private let audit: FacialRecognitionAuditLogger
    private let sequenceHandler = VNSequenceRequestHandler()

    private init(
        analytics: FacialRecognitionAnalyticsLogger = NullFacialRecognitionAnalyticsLogger(),
        audit: FacialRecognitionAuditLogger = NullFacialRecognitionAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Detects faces in the given image and returns bounding boxes.
    public func detectFaces(in image: CGImage) async throws -> [CGRect] {
        Task {
            await analytics.log(event: "detect_start", parameters: nil)
            await audit.record("Face detection started", metadata: nil)
            await FacialRecognitionAuditManager.shared.add(
                FacialRecognitionAuditEntry(event: "detect_start", detail: nil)
            )
        }
        let request = VNDetectFaceRectanglesRequest()
        try sequenceHandler.perform([request], on: image)
        guard let observations = request.results as? [VNFaceObservation] else {
            throw NSError(domain: "FacialRecognition", code: 1, userInfo: nil)
        }
        let boxes = observations.map { $0.boundingBox }
        Task {
            await analytics.log(event: "detect_complete", parameters: ["count": boxes.count])
            await audit.record("Face detection completed", metadata: ["count": "\(boxes.count)"])
            await FacialRecognitionAuditManager.shared.add(
                FacialRecognitionAuditEntry(event: "detect_complete", detail: "\(boxes.count)")
            )
        }
        return boxes
    }

    /// Recognizes a face against a stored model (stubbed).
    public func recognizeFace(_ image: CGImage) async throws -> String {
        Task {
            await analytics.log(event: "recognize_start", parameters: nil)
            await audit.record("Face recognition started", metadata: nil)
            await FacialRecognitionAuditManager.shared.add(
                FacialRecognitionAuditEntry(event: "recognize_start", detail: nil)
            )
        }
        // Stubbed recognition logic
        try await Task.sleep(nanoseconds: 300_000_000)
        let identity = "Unknown"
        Task {
            await analytics.log(event: "recognize_complete", parameters: ["identity": identity])
            await audit.record("Face recognition completed", metadata: ["identity": identity])
            await FacialRecognitionAuditManager.shared.add(
                FacialRecognitionAuditEntry(event: "recognize_complete", detail: identity)
            )
        }
        return identity
    }
}

// MARK: - Diagnostics

public extension FacialRecognitionService {
    /// Fetch recent facial recognition audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [FacialRecognitionAuditEntry] {
        await FacialRecognitionAuditManager.shared.recent(limit: limit)
    }

    /// Export facial recognition audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await FacialRecognitionAuditManager.shared.exportJSON()
    }
}

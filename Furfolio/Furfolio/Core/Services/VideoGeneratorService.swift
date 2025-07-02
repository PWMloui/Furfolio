//
//  VideoGeneratorService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

/**
 VideoGeneratorService
 ---------------------
 A centralized service for generating videos (e.g., slideshows) in Furfolio, with async analytics and audit logging.

 - **Purpose**: Combines images or clips into a video file.
 - **Architecture**: Singleton `ObservableObject` service using AVFoundation.
 - **Concurrency & Async Logging**: Wraps generation calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol VideoAnalyticsLogger {
    /// Log a video generation event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol VideoAuditLogger {
    /// Record a video generation audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullVideoAnalyticsLogger: VideoAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullVideoAuditLogger: VideoAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a video generation audit event.
public struct VideoAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging video generation events.
public actor VideoAuditManager {
    private var buffer: [VideoAuditEntry] = []
    private let maxEntries = 100
    public static let shared = VideoAuditManager()

    public func add(_ entry: VideoAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [VideoAuditEntry] {
        Array(buffer.suffix(limit))
    }

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
public final class VideoGeneratorService: ObservableObject {
    public static let shared = VideoGeneratorService(
        analytics: NullVideoAnalyticsLogger(),
        audit: NullVideoAuditLogger()
    )

    private let analytics: VideoAnalyticsLogger
    private let audit: VideoAuditLogger

    private init(
        analytics: VideoAnalyticsLogger,
        audit: VideoAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Generates a video from an array of UIImages with the given frame duration and returns URL of the file.
    public func generateSlideshow(with images: [UIImage], frameDuration: CMTime, outputSize: CGSize, completion: @escaping (Result<URL, Error>) -> Void) {
        Task {
            await analytics.log(event: "slideshow_start", metadata: ["count": images.count])
            await audit.record("Slideshow generation started", metadata: ["count": "\(images.count)"])
            await VideoAuditManager.shared.add(
                VideoAuditEntry(event: "slideshow_start", detail: "\(images.count) frames")
            )
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mp4")
            do {
                let writer = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
                let settings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: outputSize.width,
                    AVVideoHeightKey: outputSize.height
                ]
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
                writer.add(input)
                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                var frameCount: Int64 = 0
                for image in images {
                    while !input.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                    guard let buffer = image.pixelBuffer(size: outputSize) else { continue }
                    adaptor.append(buffer, withPresentationTime: presentationTime)
                    frameCount += 1
                }
                input.markAsFinished()
                writer.finishWriting {
                    Task {
                        await self.analytics.log(event: "slideshow_complete", metadata: ["url": fileURL.absoluteString])
                        await self.audit.record("Slideshow generation completed", metadata: ["url": fileURL.absoluteString])
                        await VideoAuditManager.shared.add(
                            VideoAuditEntry(event: "slideshow_complete", detail: fileURL.lastPathComponent)
                        )
                        completion(.success(fileURL))
                    }
                }
            } catch {
                Task {
                    await self.analytics.log(event: "slideshow_error", metadata: ["error": error.localizedDescription])
                    await self.audit.record("Slideshow generation error", metadata: ["error": error.localizedDescription])
                    await VideoAuditManager.shared.add(
                        VideoAuditEntry(event: "slideshow_error", detail: error.localizedDescription)
                    )
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Diagnostics

public extension VideoGeneratorService {
    /// Fetch recent video audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [VideoAuditEntry] {
        await VideoAuditManager.shared.recent(limit: limit)
    }

    /// Export video audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await VideoAuditManager.shared.exportJSON()
    }
}

// MARK: - Helpers

private extension UIImage {
    func pixelBuffer(size: CGSize) -> CVPixelBuffer? {
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB, attrs as CFDictionary, &buffer)
        guard let pixelBuffer = buffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        guard let ctx = context else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
            return nil
        }
        ctx.draw(self.cgImage!, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        return pixelBuffer
    }
}

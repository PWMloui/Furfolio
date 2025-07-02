//
//  PermissionsManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import UserNotifications
import AVFoundation
import PhotosUI
import SwiftData

/// Types of permissions managed.
public enum PermissionType: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case notification, camera, photoLibrary
}

/// Records an audit event for a permission request.
@Model public struct PermissionAuditEvent: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var type: PermissionType
    public var granted: Bool

    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        let status = granted ? NSLocalizedString("granted", comment: "") : NSLocalizedString("denied", comment: "")
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(type.rawValue.capitalized) permission \(status) at \(dateStr)."
    }
}

/// Manages runtime permission requests and status checks for various features.
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) public var auditEvents: [PermissionAuditEvent]

    // MARK: - Notification Permission

    /// Checks current notification authorization status.
    public func notificationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    /// Requests notification authorization.
    /// - Returns: `true` if granted, `false` otherwise.
    public func requestNotificationPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        modelContext.insert(PermissionAuditEvent(type: .notification, granted: granted ?? false))
        return granted ?? false
    }

    // MARK: - Camera Permission

    /// Returns current camera authorization status.
    public var cameraStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Requests camera access.
    /// - Returns: `true` if granted, `false` otherwise.
    public func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
                modelContext.insert(PermissionAuditEvent(type: .camera, granted: granted))
            }
        }
    }

    // MARK: - Photo Library Permission

    /// Returns current photo library authorization status.
    public var photoLibraryStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    /// Requests photo library access.
    /// - Returns: `true` if granted, `false` otherwise.
    public func requestPhotoLibraryPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status == .authorized || status == .limited)
                modelContext.insert(PermissionAuditEvent(type: .photoLibrary, granted: status == .authorized || status == .limited))
            }
        }
    }

    /// Exports the last permission audit event as a pretty-printed JSON string.
    public func exportLastPermissionAuditJSON() async -> String? {
        guard let last = auditEvents.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Clears all permission audit events.
    public func clearAllPermissionAuditEvents() async {
        auditEvents.forEach { modelContext.delete($0) }
    }

    /// Accessibility summary for the last permission audit event.
    public var permissionAuditAccessibilitySummary: String {
        get async {
            return auditEvents.last?.accessibilityLabel
                ?? NSLocalizedString("No permission audit events recorded.", comment: "")
        }
    }
}

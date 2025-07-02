//
//  AnimatedPhotoGallery.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, modular, accessible, preview/testable, enterprise-grade.
//
//  MARK: - AnimatedPhotoGallery Architecture and Extensibility
//
//  AnimatedPhotoGallery is a modular SwiftUI component designed for displaying a swipeable, zoomable photo gallery with rich accessibility support and comprehensive analytics hooks.
//
//  Architecture:
//  - Uses SwiftUI's TabView for paging with matched geometry effects for smooth transitions.
//  - ZoomableImage subview supports pinch-to-zoom, drag-to-pan, and double-tap to reset gestures.
//  - Design tokens provide fallback styling for easy theming and compliance with design systems.
//
//  Extensibility:
//  - Analytics integration via the PhotoGalleryAnalyticsLogger protocol, supporting async event logging and test mode console logging.
//  - Public API to fetch recent analytics events for diagnostics or admin UI.
//  - Customizable image titles and tap callbacks for flexible usage.
//
//  Analytics/Audit/Trust Center Hooks:
//  - All user interactions (taps, swipes, page dot taps, gallery appearance) are logged asynchronously.
//  - AnalyticsLogger supports testMode for QA and preview logging.
//  - Event strings and accessibility labels are localized to ensure compliance and internationalization.
//
//  Diagnostics:
//  - Public method to retrieve the last 20 analytics events for auditing or admin interfaces.
//
//  Localization:
//  - All user-facing strings and logged event keys are wrapped with NSLocalizedString with descriptive keys and comments.
//
//  Accessibility:
//  - Accessibility labels and hints are provided for all interactive elements, supporting VoiceOver and other assistive technologies.
//
//  Compliance:
//  - Uses design tokens and localized strings to meet enterprise-grade compliance and branding standards.
//
//  Preview/Testability:
//  - Includes a SpyLogger for preview and debug builds to print analytics events in console.
//  - Supports testMode logging for QA and automated testing scenarios.
//


import SwiftUI

// MARK: - Audit Context (set at login/session)
/// Global audit context for trust center, compliance, and admin diagnostics.
public struct PhotoGalleryAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AnimatedPhotoGallery"
}

// MARK: - Analytics/Audit Logger Protocol

/// Protocol for logging photo gallery analytics events asynchronously, trust center, compliance, and admin diagnostics.
/// Implementers can enable testMode to log events only to console for QA and preview purposes.
public protocol PhotoGalleryAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    
    /// Asynchronously logs an analytics/audit event with the event name, image index, image title, and audit context.
    /// - Parameters:
    ///   - event: The event name key for localization and analytics.
    ///   - imageIndex: The index of the image related to the event.
    ///   - imageTitle: Optional title of the image related to the event.
    ///   - role: The user's role for audit/trust center.
    ///   - staffID: The user's staff ID for audit/compliance.
    ///   - context: The application context for diagnostics.
    ///   - escalate: True if the event should be escalated for compliance/alerting.
    func log(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    
    /// Fetch the most recent N analytics/audit events for diagnostics or admin UI.
    func fetchRecentEvents(count: Int) async -> [PhotoGalleryAnalyticsEvent]
    
    /// Escalate a specific event for compliance/alerting.
    func escalate(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?) async
}

/// No-op logger implementation that performs no logging.
public struct NullPhotoGalleryAnalyticsLogger: PhotoGalleryAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func fetchRecentEvents(count: Int) async -> [PhotoGalleryAnalyticsEvent] { return [] }
    public func escalate(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?) async {}
}

// MARK: - Analytics Event Record

/// Represents a single analytics event record for diagnostics or admin UI.
public struct PhotoGalleryAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let imageIndex: Int
    public let imageTitle: String?
}

// MARK: - AnimatedPhotoGallery

/// A SwiftUI view that displays an animated, zoomable photo gallery with swipe navigation, accessibility, and analytics/audit/trust center support.
struct AnimatedPhotoGallery: View {
    let images: [UIImage]
    var imageTitles: [String]? = nil
    var onImageTapped: ((Int) -> Void)? = nil
    var analyticsLogger: PhotoGalleryAnalyticsLogger = NullPhotoGalleryAnalyticsLogger()
    
    @State private var currentIndex: Int = 0
    @Namespace private var animation
    
    /// Internal storage of recent analytics events for diagnostics or admin UI.
    @State private var recentAnalyticsEvents: [PhotoGalleryAnalyticsEvent] = []
    
    // MARK: - Design Tokens (with fallback)
    private enum Style {
        static let galleryHeight: CGFloat = AppSpacing.galleryHeight ?? 320
        static let cornerRadius: CGFloat = AppRadius.large ?? 14
        static let shadowRadius: CGFloat = AppRadius.medium ?? 6
        static let paddingHorizontal: CGFloat = AppSpacing.large ?? 12
        static let spacing: CGFloat = AppSpacing.medium ?? 8
        static let pageDotActive: CGFloat = 12
        static let pageDotInactive: CGFloat = 7
        static let pageDotSpacing: CGFloat = 6
        static let titleFont: Font = AppFonts.caption ?? .caption
        static let titleColor: Color = AppColors.textSecondary ?? .secondary
        static let placeholderBg: Color = AppColors.emptyStateBg ?? Color.gray.opacity(0.15)
        static let placeholderIcon: Color = AppColors.textSecondary ?? .gray
    }
    
    var body: some View {
        VStack(spacing: Style.spacing) {
            if images.isEmpty {
                placeholder
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { idx in
                        ZoomableImage(image: images[idx])
                            .cornerRadius(Style.cornerRadius)
                            .matchedGeometryEffect(id: idx, in: animation)
                            .shadow(radius: Style.shadowRadius)
                            .padding(.horizontal, Style.paddingHorizontal)
                            .tag(idx)
                            .onTapGesture {
                                Task {
                                    await logEvent(
                                        eventKey: "image_tapped",
                                        index: idx,
                                        title: imageTitles?[idx]
                                    )
                                    onImageTapped?(idx)
                                }
                            }
                            .accessibilityLabel(
                                NSLocalizedString(
                                    imageTitles?[idx] ?? String(format: NSLocalizedString("Photo %d", comment: "Accessibility label for photo number"), idx + 1),
                                    comment: "Accessibility label for photo"
                                )
                            )
                            .accessibilityHint(NSLocalizedString("Tap to enlarge or interact", comment: "Accessibility hint for image tap"))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: Style.galleryHeight)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
                .onChange(of: currentIndex) { newIndex in
                    Task {
                        await logEvent(
                            eventKey: "image_swiped",
                            index: newIndex,
                            title: imageTitles?[newIndex]
                        )
                    }
                }
                .onAppear {
                    if !images.isEmpty {
                        Task {
                            await logEvent(
                                eventKey: "gallery_appeared",
                                index: currentIndex,
                                title: imageTitles?[currentIndex]
                            )
                        }
                    }
                }
            }
            
            if let titles = imageTitles, images.indices.contains(currentIndex) {
                Text(titles[currentIndex])
                    .font(Style.titleFont)
                    .foregroundColor(Style.titleColor)
                    .padding(.top, 2)
                    .accessibilityHint(NSLocalizedString("Image title", comment: "Accessibility hint for image title"))
            }
            
            if images.count > 1 {
                HStack(spacing: Style.pageDotSpacing) {
                    ForEach(images.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex ? Color.accentColor : Color.gray.opacity(0.36))
                            .frame(width: idx == currentIndex ? Style.pageDotActive : Style.pageDotInactive,
                                   height: idx == currentIndex ? Style.pageDotActive : Style.pageDotInactive)
                            .onTapGesture {
                                withAnimation { currentIndex = idx }
                                Task {
                                    await logEvent(
                                        eventKey: "page_dot_tapped",
                                        index: idx,
                                        title: imageTitles?[idx]
                                    )
                                }
                            }
                            .accessibilityLabel(
                                String(
                                    format: NSLocalizedString("Go to photo %d", comment: "Accessibility label for page dot tap"),
                                    idx + 1
                                )
                            )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
    
    /// Logs an analytics/audit event asynchronously and stores it in recent events.
    /// - Parameters:
    ///   - eventKey: The event key string for localization and analytics.
    ///   - index: The image index related to the event.
    ///   - title: Optional image title related to the event.
    /// Trust Center/Compliance: All calls include audit context and escalate flag.
    private func logEvent(eventKey: String, index: Int, title: String?) async {
        let localizedEvent = NSLocalizedString(eventKey, comment: "Analytics event key")
        let role = PhotoGalleryAuditContext.role
        let staffID = PhotoGalleryAuditContext.staffID
        let context = PhotoGalleryAuditContext.context
        // Escalate if gallery_appeared and title contains "Critical" or "Sensitive"
        var escalate = false
        if eventKey == "gallery_appeared", let t = title?.lowercased() {
            if t.contains("critical") || t.contains("sensitive") {
                escalate = true
            }
        }
        await analyticsLogger.log(
            event: localizedEvent,
            imageIndex: index,
            imageTitle: title,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        if escalate {
            await analyticsLogger.escalate(
                event: localizedEvent,
                imageIndex: index,
                imageTitle: title,
                role: role,
                staffID: staffID,
                context: context
            )
        }
        // Append to recent events on main thread for UI safety
        await MainActor.run {
            let eventRecord = PhotoGalleryAnalyticsEvent(
                timestamp: Date(),
                event: localizedEvent,
                imageIndex: index,
                imageTitle: title
            )
            recentAnalyticsEvents.append(eventRecord)
            // Keep only last 20 events
            if recentAnalyticsEvents.count > 20 {
                recentAnalyticsEvents.removeFirst(recentAnalyticsEvents.count - 20)
            }
        }
    }
    
    /// Public API to fetch the last 20 analytics events for diagnostics or admin UI.
    /// - Returns: An array of the most recent PhotoGalleryAnalyticsEvent records.
    public func fetchRecentAnalyticsEvents() -> [PhotoGalleryAnalyticsEvent] {
        return recentAnalyticsEvents
    }
    
    /// Static API to fetch the last N audit events from the analytics logger for admin/trust center diagnostics.
    public static func fetchLastAuditEvents(count: Int = 20, using logger: PhotoGalleryAnalyticsLogger) async -> [PhotoGalleryAnalyticsEvent] {
        return await logger.fetchRecentEvents(count: count)
    }
    
    /// Placeholder view shown when there are no images.
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Style.placeholderBg)
            .frame(height: 240)
            .overlay(
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 54))
                        .foregroundColor(Style.placeholderIcon)
                    Text(NSLocalizedString("No Photos", comment: "Placeholder text when no photos are available"))
                        .foregroundColor(Style.placeholderIcon)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(NSLocalizedString("No photos available", comment: "Accessibility label for empty photo gallery"))
            )
    }
}

// MARK: - ZoomableImage

/// A zoomable, draggable image view with double-tap to reset.
/// Supports pinch-to-zoom, drag-to-pan, and double-tap gestures.
/// Accessibility labels and hints included.
struct ZoomableImage: View {
    let image: UIImage
    
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero
    
    private let maxZoom: CGFloat = 3.5
    private let minZoom: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoomScale)
                .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = min(max(minZoom, value), maxZoom)
                            }
                            .onEnded { _ in
                                if zoomScale < 1.05 {
                                    withAnimation { zoomScale = 1.0 }
                                    offset = .zero
                                }
                            },
                        DragGesture()
                            .updating($gestureOffset) { value, state, _ in
                                if zoomScale > 1.01 {
                                    state = value.translation
                                }
                            }
                            .onEnded { value in
                                if zoomScale > 1.01 {
                                    offset.width += value.translation.width
                                    offset.height += value.translation.height
                                } else {
                                    withAnimation { offset = .zero }
                                }
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if zoomScale > 1.1 {
                            zoomScale = 1.0
                            offset = .zero
                        } else {
                            zoomScale = 2.4
                        }
                    }
                }
                .accessibilityLabel(NSLocalizedString("Zoomable image", comment: "Accessibility label for zoomable image"))
                .accessibilityHint(NSLocalizedString("Pinch to zoom, drag to pan, double-tap to reset", comment: "Accessibility hint for zoomable image gestures"))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedPhotoGallery_Previews: PreviewProvider {
    class SpyLogger: PhotoGalleryAnalyticsLogger {
        let testMode: Bool = true
        private var events: [PhotoGalleryAnalyticsEvent] = []
        func log(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            if testMode {
                print("GalleryAnalytics: \(event) @\(imageIndex) [\(imageTitle ?? "-")] role=\(role ?? "-") staffID=\(staffID ?? "-") context=\(context ?? "-") escalate=\(escalate)")
            }
            let record = PhotoGalleryAnalyticsEvent(timestamp: Date(), event: event, imageIndex: imageIndex, imageTitle: imageTitle)
            events.append(record)
            if events.count > 50 { events.removeFirst(events.count - 50) }
        }
        func fetchRecentEvents(count: Int) async -> [PhotoGalleryAnalyticsEvent] {
            return Array(events.suffix(count))
        }
        func escalate(event: String, imageIndex: Int, imageTitle: String?, role: String?, staffID: String?, context: String?) async {
            if testMode {
                print("!!ESCALATE!! \(event) @\(imageIndex) [\(imageTitle ?? "-")] role=\(role ?? "-") staffID=\(staffID ?? "-") context=\(context ?? "-")")
            }
        }
    }
    static var previews: some View {
        let sampleImages: [UIImage] = [
            UIImage(systemName: "pawprint.fill")!.withTintColor(.systemPink, renderingMode: .alwaysOriginal),
            UIImage(systemName: "scissors")!.withTintColor(.systemTeal, renderingMode: .alwaysOriginal),
            UIImage(systemName: "star.circle.fill")!.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        ]
        let titles = [
            NSLocalizedString("Bella After Groom", comment: "Sample image title"),
            NSLocalizedString("Clipping In Progress", comment: "Sample image title"),
            NSLocalizedString("Loyalty Badge!", comment: "Sample image title")
        ]
        return AnimatedPhotoGallery(
            images: sampleImages,
            imageTitles: titles,
            analyticsLogger: SpyLogger()
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

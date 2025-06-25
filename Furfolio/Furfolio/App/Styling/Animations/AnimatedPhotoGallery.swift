//
//  AnimatedPhotoGallery.swift
//  Furfolio
//
//  Enhanced: analytics/audit-ready, token-compliant, modular, accessible, preview/testable, enterprise-grade.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol PhotoGalleryAnalyticsLogger {
    func log(event: String, imageIndex: Int, imageTitle: String?)
}
public struct NullPhotoGalleryAnalyticsLogger: PhotoGalleryAnalyticsLogger {
    public init() {}
    public func log(event: String, imageIndex: Int, imageTitle: String?) {}
}

// MARK: - AnimatedPhotoGallery

struct AnimatedPhotoGallery: View {
    let images: [UIImage]
    var imageTitles: [String]? = nil
    var onImageTapped: ((Int) -> Void)? = nil
    var analyticsLogger: PhotoGalleryAnalyticsLogger = NullPhotoGalleryAnalyticsLogger()

    @State private var currentIndex: Int = 0
    @Namespace private var animation

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
                                analyticsLogger.log(event: "image_tapped", imageIndex: idx, imageTitle: imageTitles?[idx])
                                onImageTapped?(idx)
                            }
                            .accessibilityLabel(imageTitles?[idx] ?? "Photo \(idx + 1)")
                            .accessibilityHint("Tap to enlarge or interact")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: Style.galleryHeight)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
                .onChange(of: currentIndex) { newIndex in
                    analyticsLogger.log(event: "image_swiped", imageIndex: newIndex, imageTitle: imageTitles?[newIndex])
                }
                .onAppear {
                    if !images.isEmpty {
                        analyticsLogger.log(event: "gallery_appeared", imageIndex: currentIndex, imageTitle: imageTitles?[currentIndex])
                    }
                }
            }

            if let titles = imageTitles, images.indices.contains(currentIndex) {
                Text(titles[currentIndex])
                    .font(Style.titleFont)
                    .foregroundColor(Style.titleColor)
                    .padding(.top, 2)
                    .accessibilityHint("Image title")
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
                                analyticsLogger.log(event: "page_dot_tapped", imageIndex: idx, imageTitle: imageTitles?[idx])
                            }
                            .accessibilityLabel("Go to photo \(idx + 1)")
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Style.placeholderBg)
            .frame(height: 240)
            .overlay(
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 54))
                        .foregroundColor(Style.placeholderIcon)
                    Text("No Photos")
                        .foregroundColor(Style.placeholderIcon)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No photos available")
            )
    }
}

// MARK: - ZoomableImage

/// A zoomable, draggable image view with double-tap to reset.
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
                .accessibilityLabel("Zoomable image")
                .accessibilityHint("Pinch to zoom, drag to pan, double-tap to reset")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedPhotoGallery_Previews: PreviewProvider {
    struct SpyLogger: PhotoGalleryAnalyticsLogger {
        func log(event: String, imageIndex: Int, imageTitle: String?) {
            print("GalleryAnalytics: \(event) @\(imageIndex) [\(imageTitle ?? "-")]")
        }
    }
    static var previews: some View {
        let sampleImages: [UIImage] = [
            UIImage(systemName: "pawprint.fill")!.withTintColor(.systemPink, renderingMode: .alwaysOriginal),
            UIImage(systemName: "scissors")!.withTintColor(.systemTeal, renderingMode: .alwaysOriginal),
            UIImage(systemName: "star.circle.fill")!.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        ]
        let titles = ["Bella After Groom", "Clipping In Progress", "Loyalty Badge!"]
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

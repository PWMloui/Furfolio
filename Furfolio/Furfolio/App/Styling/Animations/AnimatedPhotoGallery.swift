//
//  AnimatedPhotoGallery.swift
//  Furfolio
//
//  Created by mac on 6/20/25.
//

import SwiftUI

/// Animated, interactive photo gallery with paging and transitions.
/// Use for dog profiles, before/after galleries, or business highlights.
/// An animated, swipeable photo gallery with zoom and paging support.
/// Used for pet profiles, service showcases, or before/after views.
struct AnimatedPhotoGallery: View {
    let images: [UIImage]
    var imageTitles: [String]? = nil
    var onImageTapped: ((Int) -> Void)? = nil

    @State private var currentIndex: Int = 0
    @Namespace private var animation

    var body: some View {
        VStack(spacing: 8) {
            if images.isEmpty {
                placeholder
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(images.indices, id: \.self) { idx in
                        ZoomableImage(image: images[idx])
                            .cornerRadius(14)
                            .matchedGeometryEffect(id: idx, in: animation)
                            .shadow(radius: 6)
                            .padding(.horizontal, 12)
                            .tag(idx)
                            .onTapGesture {
                                onImageTapped?(idx)
                            }
                            .accessibilityLabel(imageTitles?[idx] ?? "Photo \(idx + 1)")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 320)
                .animation(.spring(response: 0.4, dampingFraction: 0.9), value: currentIndex)
            }

            if let titles = imageTitles, images.indices.contains(currentIndex) {
                Text(titles[currentIndex])
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                    .accessibilityHint("Image title")
            }

            if images.count > 1 {
                HStack(spacing: 6) {
                    ForEach(images.indices, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex ? Color.accentColor : Color.gray.opacity(0.36))
                            .frame(width: idx == currentIndex ? 12 : 7, height: idx == currentIndex ? 12 : 7)
                            .onTapGesture {
                                withAnimation { currentIndex = idx }
                            }
                            .accessibilityLabel("Go to photo \(idx + 1)")
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.bottom, 8)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.gray.opacity(0.15))
            .frame(height: 240)
            .overlay(
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 54))
                        .foregroundColor(.gray)
                    Text("No Photos")
                        .foregroundColor(.gray)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No photos available")
            )
    }
}
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
                            .onEnded { value in
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
                                    withAnimation {
                                        offset = .zero
                                    }
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
        }
    }
}
// MARK: - Preview

#if DEBUG
struct AnimatedPhotoGallery_Previews: PreviewProvider {
    static var previews: some View {
        let sampleImages: [UIImage] = [
            UIImage(systemName: "pawprint.fill")!.withTintColor(.systemPink, renderingMode: .alwaysOriginal),
            UIImage(systemName: "scissors")!.withTintColor(.systemTeal, renderingMode: .alwaysOriginal),
            UIImage(systemName: "star.circle.fill")!.withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
        ]
        let titles = ["Bella After Groom", "Clipping In Progress", "Loyalty Badge!"]
        return AnimatedPhotoGallery(images: sampleImages, imageTitles: titles)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

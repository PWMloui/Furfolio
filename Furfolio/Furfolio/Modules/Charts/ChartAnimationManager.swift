import Foundation
import Combine

/// Manages chart animation state toggling in a periodic cycle.
final class ChartAnimationManager: ObservableObject {
    @Published var isAnimating: Bool = false

    private var animationTimer: Timer?
    private let cycleDuration: TimeInterval
    private let animationDelay: TimeInterval

    /// Initializes the manager.
    /// - Parameters:
    ///   - duration: Duration of one toggle cycle. Default is 1.2s.
    ///   - delay: Delay before the first animation cycle starts. Default is 0s.
    init(duration: TimeInterval = 1.2, delay: TimeInterval = 0.0) {
        self.cycleDuration = duration
        self.animationDelay = delay
    }

    /// Starts the animation cycle.
    func startAnimation() {
        stopAnimation()

        DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) { [weak self] in
            guard let self = self else { return }
            self.isAnimating = true
            self.animationTimer = Timer.scheduledTimer(withTimeInterval: self.cycleDuration * 2,
                                                       repeats: true) { [weak self] _ in
                self?.isAnimating.toggle()
            }

            // Add to common RunLoop to prevent blocking UI updates
            if let timer = self.animationTimer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    /// Stops the animation and clears the timer.
    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }
}

// MARK: - Demo & Preview

#if DEBUG
import SwiftUI

struct ChartAnimationManagerDemoView: View {
    @StateObject private var animationManager = ChartAnimationManager()

    var body: some View {
        VStack(spacing: 20) {
            Text("Chart Animation State: \(animationManager.isAnimating ? "Animating" : "Stopped")")
                .font(.headline)

            Button(animationManager.isAnimating ? "Stop Animation" : "Start Animation") {
                animationManager.isAnimating ? animationManager.stopAnimation() : animationManager.startAnimation()
            }
            .padding()
            .background(animationManager.isAnimating ? Color.red : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding()
    }
}

struct ChartAnimationManager_Previews: PreviewProvider {
    static var previews: some View {
        ChartAnimationManagerDemoView()
    }
}
#endif

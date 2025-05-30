//
//  ProgressRingViewModel.swift
//  Furfolio
//
//  Created by mac on 5/29/25.
//

import Foundation
import Combine
import os
import FirebaseRemoteConfigService

@MainActor
final class ProgressRingViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var isComplete: Bool = false

    private var completionCallback: (() -> Void)?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ProgressRingViewModel")

    /// Remote-configurable completion threshold (0.0…1.0).
    private static var completionThreshold: Double {
        FirebaseRemoteConfigService.shared.configValue(forKey: .progressCompletionThreshold)
    }

    private var cancellables = Set<AnyCancellable>()

    /// Initializes with an optional starting value and completion handler.
    init(initialProgress: Double = 0, onComplete: (() -> Void)? = nil) {
        self.progress = initialProgress
        self.completionCallback = onComplete
        logger.log("Initialized ProgressRingViewModel with initialProgress: \(initialProgress)")
        
        // Watch for when progress reaches or exceeds 1.0
        $progress
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.logger.log("Progress updated to: \(newValue)")
                if newValue >= Self.completionThreshold && !self.isComplete {
                    self.isComplete = true
                    self.logger.log("Progress complete, invoking callback")
                    self.completionCallback?()
                }
            }
            .store(in: &cancellables)
    }

    /// Increments the progress by the specified amount (0…1).
    func increment(by amount: Double) {
        let old = progress
        progress = min(max(progress + amount, 0), 1)
        logger.log("increment(by: \(amount)) → progress changed from \(old) to \(progress)")
    }

    /// Resets the progress back to zero.
    func reset() {
        logger.log("Progress reset (was \(progress))")
        progress = 0
        isComplete = false
    }

    deinit {
        logger.log("Deinitialized ProgressRingViewModel")
    }
}

//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//


import SwiftUI
import Combine
import os
import FirebaseRemoteConfigService

final class OnboardingFlowManager: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "OnboardingFlow")
    private var loadingTask: Task<Void, Never>?
    /// Loading delay configured via Remote Config (in seconds).
    private var loadingDelay: TimeInterval {
        FirebaseRemoteConfigService.shared.configValue(forKey: .onboardingLoadingDelay)
    }
    static let shared = OnboardingFlowManager()
    @AppStorage("OnboardingFlowManager.hasCompleted") private var hasCompletedStorage: Bool = false
    @AppStorage("OnboardingFlowManager.hasSkippedTutorial") private var hasSkippedTutorial: Bool = false
    @Published var isPresenting: Bool = false
    @Published var currentStep: Step = .welcome
    private var cancellables = Set<AnyCancellable>()
    private init() {
        isPresenting = !hasCompletedStorage
        currentStep = isPresenting ? .loading : .completed
        if isPresenting {
            loadingTask = Task {
                let delayNs = UInt64(loadingDelay * 1_000_000_000)
                try await Task.sleep(nanoseconds: delayNs)
                await MainActor.run { 
                    logger.log("Onboarding loading complete, advancing to welcome")
                    self.advance() 
                }
            }
        }
        $currentStep
            .filter { $0 == .completed }
            .sink { [weak self] _ in
                self?.completeOnboarding()
            }
            .store(in: &cancellables)
    }
    enum Step: CaseIterable {
        case loading
        case welcome
        case permissions
        case tutorial
        case completed
        func next() -> Step {
            let all = Self.allCases
            guard let idx = all.firstIndex(of: self), idx + 1 < all.count else {
                return .completed
            }
            return all[idx + 1]
        }
    }
    func advance() {
        logger.log("Advancing onboarding from \(currentStep) to \(currentStep.next())")
        currentStep = currentStep.next()
    }
    func skip() {
        loadingTask?.cancel()
        logger.log("Onboarding skipped by user")
        hasSkippedTutorial = true
        currentStep = .completed
    }
    private func completeOnboarding() {
        logger.log("Onboarding completed")
        hasCompletedStorage = true
        isPresenting = false
    }
    func reset() {
        loadingTask?.cancel()
        logger.log("Onboarding reset to start")
        hasCompletedStorage = false
        currentStep = .welcome
        isPresenting = true
    }
}

extension OnboardingFlowManager.Step: Identifiable {
    var id: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

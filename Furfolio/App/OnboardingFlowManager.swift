//
//  OnboardingFlowManager.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//


import SwiftUI
import Combine

final class OnboardingFlowManager: ObservableObject {
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
            Task {
                try await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { self.advance() }
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
            let all: [Step] = [.loading, .welcome, .permissions, .tutorial, .completed]
            guard let idx = all.firstIndex(of: self), idx + 1 < all.count else {
                return .completed
            }
            return all[idx + 1]
        }
    }
    func advance() {
        currentStep = currentStep.next()
    }
    func skip() {
        hasSkippedTutorial = true
        currentStep = .completed
    }
    private func completeOnboarding() {
        hasCompletedStorage = true
        isPresenting = false
    }
    func reset() {
        hasCompletedStorage = false
        currentStep = .welcome
        isPresenting = true
    }
}

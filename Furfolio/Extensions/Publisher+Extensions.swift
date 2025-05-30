//
//  Publisher+Extensions.swift
//  Furfolio
//
//  Created by mac on 5/26/25.

import Combine
import Foundation
import os
private let publisherLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Publisher+Extensions")

public extension Publisher {
    /// Replaces any failure from this publisher with the provided default output,
    /// then erases to `AnyPublisher`.
    func replaceError(with output: Output) -> AnyPublisher<Output, Never> {
        return self
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("replaceError: subscribed") },
                receiveOutput: { output in publisherLogger.log("replaceError: output \\(String(describing: output))") },
                receiveCompletion: { completion in publisherLogger.log("replaceError: completed \\(String(describing: completion))") }
            )
            .catch { _ in Just(output) }
            .eraseToAnyPublisher()
    }

    /// Ensures subscription and value handling occur on the main thread.
    /// Returns an `AnyCancellable` for lifecycle management.
    func sinkOnMain(
        receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void) = { _ in },
        receiveValue: @escaping ((Output) -> Void)
    ) -> AnyCancellable {
        publisherLogger.log("sinkOnMain: subscribing on main thread")
        return receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
    }

    /// Debounces values on the main thread.
    func debounceOnMain(
        for dueTime: DispatchQueue.SchedulerTimeType.Stride
    ) -> AnyPublisher<Output, Failure> {
        publisherLogger.log("debounceOnMain: invoked")
        return debounce(for: dueTime, scheduler: DispatchQueue.main)
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("debounceOnMain: subscribed") }
            )
            .eraseToAnyPublisher()
    }

    /// Retries the publisher up to `retries` times, ensuring all retries happen on the main thread.
    func retryOnMain(_ retries: Int) -> AnyPublisher<Output, Failure> {
        publisherLogger.log("retryOnMain: invoked")
        return receive(on: DispatchQueue.main)
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("retryOnMain: subscribed") }
            )
            .retry(retries)
            .eraseToAnyPublisher()
    }

    /// Converts any failure into a successful output using the provided transform.
    func mapErrorToOutput(
        _ transform: @escaping (Failure) -> Output
    ) -> AnyPublisher<Output, Never> {
        publisherLogger.log("mapErrorToOutput: invoked")
        return self
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("mapErrorToOutput: subscribed") }
            )
            .catch { error in Just(transform(error)) }
            .eraseToAnyPublisher()
    }
}

public extension Publisher where Failure == Never {
    /// Collects all emitted values into an array, applies a transform, and publishes the transformed output.
    func collectAndMap<T>(_ transform: @escaping ([Output]) -> T) -> AnyPublisher<T, Never> {
        publisherLogger.log("collectAndMap: invoked")
        return self
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("collectAndMap: subscribed") }
            )
            .collect()
            .map(transform)
            .eraseToAnyPublisher()
    }

    /// Debounces values on the main thread, then transforms the collected array.
    func debounceAndMap<T>(
        for dueTime: DispatchQueue.SchedulerTimeType.Stride,
        _ transform: @escaping ([Output]) -> T
    ) -> AnyPublisher<T, Never> {
        publisherLogger.log("debounceAndMap: invoked")
        return debounce(for: dueTime, scheduler: DispatchQueue.main)
            .handleEvents(
                receiveSubscription: { _ in publisherLogger.log("debounceAndMap: subscribed") }
            )
            .collect()
            .map(transform)
            .eraseToAnyPublisher()
    }
}

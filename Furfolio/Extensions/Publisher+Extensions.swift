//
//  Publisher+Extensions.swift
//  Furfolio
//
//  Created by mac on 5/26/25.

import Combine
import Foundation

public extension Publisher {
    /// Replaces any failure from this publisher with the provided default output,
    /// then erases to `AnyPublisher`.
    func replaceError(with output: Output) -> AnyPublisher<Output, Never> {
        return self.catch { _ in Just(output) }
            .eraseToAnyPublisher()
    }

    /// Ensures subscription and value handling occur on the main thread.
    /// Returns an `AnyCancellable` for lifecycle management.
    func sinkOnMain(
        receiveCompletion: @escaping ((Subscribers.Completion<Failure>) -> Void) = { _ in },
        receiveValue: @escaping ((Output) -> Void)
    ) -> AnyCancellable {
        receive(on: DispatchQueue.main)
            .sink(receiveCompletion: receiveCompletion, receiveValue: receiveValue)
    }
}

public extension Publisher where Failure == Never {
    /// Collects all emitted values into an array, applies a transform, and publishes the transformed output.
    func collectAndMap<T>(_ transform: @escaping ([Output]) -> T) -> AnyPublisher<T, Never> {
        collect()
            .map(transform)
            .eraseToAnyPublisher()
    }
}

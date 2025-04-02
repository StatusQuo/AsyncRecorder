// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  AsyncRecorder.swift
//  combineTesting
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//

import Foundation
import Combine
import Testing

public final class AsyncRecorder<Output, Failure> {
    private var subscription: AnyCancellable?
    private let publisher: any Publisher<Output, Failure>
    private var stream: AsyncStream<RecorderValue>!
    private var iterator: AsyncStream<RecorderValue>.Iterator!
    private let timeout: RunLoop.SchedulerTimeType.Stride

    enum RecorderValue {
        case value(Output)
        case finished
        case timeout
        case failure(Failure)

        func isFinished() -> Bool {
            switch self {
            case .finished:
                return true
            case .timeout, .value(_), .failure(_):
                return false
            }
        }
    }

    init(publisher: any Publisher<Output, Failure>, timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) where Failure: Error {
        self.timeout = timeout
        self.publisher = publisher
        let pub = publisherToSubscribe()
        subscribe(to: pub)
    }

    init(publisher: any Publisher<Output, Failure>, timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) where Failure == Never {
        self.timeout = timeout
        self.publisher = publisher
        let pub = publisherToSubscribe()
        subscribe(to: pub)
    }

    enum RecorderError: Error {
        case timeout
        case unexpected(Failure)
    }

    private func subscribe(to publisher: AnyPublisher<Output, RecorderError>) {
        var handler: ((Output) -> Void)!
        var completion: ((RecorderError?) -> Void)!

        stream = AsyncStream { continuation in
            handler = { output in
                continuation.yield(RecorderValue.value(output))
            }
            completion = { error in
                if let error {
                    switch error {
                    case .unexpected(let failure):
                        continuation.yield(.failure(failure))
                    case .timeout:
                        continuation.yield(.timeout)
                    }
                } else {
                    continuation.yield(.finished)
                }
                continuation.finish()
                self.subscription = nil
            }
        }

        subscription = publisher
            .sink { result in
                switch result {
                case .failure(let error):
                    completion(error)
                case .finished:
                    completion(nil)
                }
                self.subscription = nil
            } receiveValue: { value in
                handler(value)
            }

        iterator = stream.makeAsyncIterator()
    }

    private func publisherToSubscribe() -> AnyPublisher<Output, RecorderError> where Failure: Error {
        publisher
            .eraseToAnyPublisher()
            .mapError { RecorderError.unexpected($0) }
            .timeout(timeout, scheduler: RunLoop.main) {
                RecorderError.timeout
            }
            .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
            .eraseToAnyPublisher()
    }

    private func publisherToSubscribe() -> AnyPublisher<Output, RecorderError> where Failure == Never {
        publisher
            .eraseToAnyPublisher()
            .assertNoFailure()
            .setFailureType(to: RecorderError.self)
            .timeout(timeout, scheduler: RunLoop.main) {
                RecorderError.timeout
            }
            .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
            .eraseToAnyPublisher()
    }

    public func next(sourceLocation: SourceLocation = #_sourceLocation) async -> Output? {
        let value = await iterator.next()
        switch value {
        case .value(let result):
            return result
        case .timeout:
            #expect(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
        case .finished, .none:
            #expect(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
        case .failure(_):
            #expect(Bool(false), "Error not handled", sourceLocation: sourceLocation)
        }
        return nil
    }
}

public extension AsyncRecorder {
    func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async {
        let value = await iterator.next()
        #expect(value!.isFinished(), sourceLocation: sourceLocation)
    }
}

public extension AsyncRecorder where Output: Equatable {
    /// Compare values collected by `TestIterator` to an list of expected elements
    ///
    ///  Usage:
    ///
    ///     let recorder = sut.$isLoading.record()
    ///     await sut.startLoading()
    ///     await recorder.expect(false, true, false)
    /// - Parameters:
    ///   - values: List of values in order that the publisher is expected to produce
    @discardableResult func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        var fetchedValues: [Output] = []
        for _ in 1...values.count {
            if let value = await next(sourceLocation: sourceLocation) {
                fetchedValues.append(value)
            }
        }
        #expect(fetchedValues == values, sourceLocation: sourceLocation)
        return self
    }
}

public extension AsyncRecorder where Failure: Error {
    func expectError(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let value = await iterator.next()
        if case .failure(let failure) = value {
            throw failure
        }
    }
}

public extension AsyncRecorder where Output == Void {
    @discardableResult func expectInvocation(_ invocations:Int = 1, sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        var counter = 0
        for _ in 1...invocations {
            if await next(sourceLocation: sourceLocation) != nil {
                counter += 1
            }
        }
        #expect(counter == invocations, sourceLocation: sourceLocation)
        return self
    }
}

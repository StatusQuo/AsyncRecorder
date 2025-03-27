// The Swift Programming Language
// https://docs.swift.org/swift-book

//
//  AsyncThrowingRecorder.swift
//  combineTesting
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//

import Foundation
import Combine
import Testing

public final class AsyncThrowingRecorder<Output, Failure> where Failure: Error, Output: Equatable {
    private var subscription: AnyCancellable?
    private let publisher: any Publisher<Output, Failure>
    private var stream: AsyncStream<RecorderValue>!
    private var iterator: AsyncStream<RecorderValue>.Iterator!
    private let timeout: RunLoop.SchedulerTimeType.Stride

    enum RecorderValue: Equatable {
        static func == (lhs: RecorderValue, rhs: RecorderValue) -> Bool {
            switch (lhs, rhs) {
            case (.value(let vl), .value(let vr)):
                return vl == vr
            case (.finished, .finished):
                return true
            case (.timeout, .timeout):
                return true
            case (.failure(let lhsError), .failure(let rhsError)):
                return lhsError.localizedDescription == rhsError.localizedDescription
            default:
                return false
            }
        }

        case value(Output)
        case finished
        case timeout
        case failure(Failure)
    }

    init(publisher: any Publisher<Output, Failure>, timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) {
        self.timeout = timeout
        self.publisher = publisher
        subscribe()
    }

    enum RecorderError: Error {
        case timeout
        case unexpected(Failure)
    }

    private func subscribe() {
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
            .eraseToAnyPublisher()
            .mapError({ error in
                RecorderError.unexpected(error)
            })
            .timeout(timeout, scheduler: RunLoop.main, customError: {
                return RecorderError.timeout
            })
            .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
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

    public func next(sourceLocation: SourceLocation = #_sourceLocation) async throws(Failure) -> Output? {
        let value = await iterator.next()
        switch value {
        case .value(let result):
            return result
        case .timeout:
            #expect(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
        case .finished, .none:
            #expect(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
        case .failure(let error):
            throw error
        }
        return nil
    }

    /// Compare values collected by `TestIterator` to an list of expected elements
    ///
    ///     let recorder = sut.$isLoading.record()
    ///     await sut.startLoading()
    ///     try await recorder.expect(false, true, false)
    /// - Parameters:
    ///   - values: List of values in order that the publisher is expected to produce
    public func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async throws(Failure) where Output:Equatable {
        var fetchedValues: [Output] = []
        for _ in 1...values.count {
            if let value = try await next(sourceLocation: sourceLocation) {
                fetchedValues.append(value)
            }
        }
        #expect(fetchedValues == values, sourceLocation: sourceLocation)
    }

    public func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async throws(Failure) {
        let value = await iterator.next()
        #expect(value! == .finished, sourceLocation: sourceLocation)
    }
}

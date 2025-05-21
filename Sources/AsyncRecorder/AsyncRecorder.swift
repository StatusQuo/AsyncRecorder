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

public final class AsyncRecorder<Output, Failure> where Failure: Sendable, Output: Sendable {
    private var subscription: AnyCancellable?
    private let publisher: any Publisher<Output, Failure>
    private var stream: AsyncStream<RecorderValue>!
    private let timeout: RunLoop.SchedulerTimeType.Stride
    private var skipping: Bool = false
    var iterator: AsyncStream<RecorderValue>.Iterator!

    enum RecorderValue: Sendable {
        case value(Output)
        case finished
        case timeout
        case failure(Failure)

        func isFinished() -> Bool {
            if case .finished = self {
                return true
            }
            return false
        }
    }

    enum RecorderError: Error {
        case timeout
        case unexpected(Failure)
    }

    init(publisher: any Publisher<Output, Failure>, timeout: RunLoop.SchedulerTimeType.Stride) where Failure: Error {
        self.timeout = timeout
        self.publisher = publisher
        let pub = publisherToSubscribe()
        subscribe(to: pub)
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
}

// MARK: - Next

public extension AsyncRecorder {
    func next(sourceLocation: SourceLocation = #_sourceLocation) async -> Output? {
        let value = await iterator.next()
        switch value {
        case .value(let result):
            return result
        case .timeout:
            Issue.record("Timeout reached", sourceLocation: sourceLocation)
           // #expect(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
        case .finished, .none:

            Issue.record("End of stream reached", sourceLocation: sourceLocation)
            //#expect(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
        case .failure(_):
            Issue.record("Error not handled", sourceLocation: sourceLocation)
            //#expect(Bool(false), "Error not handled", sourceLocation: sourceLocation)
        }
        return nil
    }
}

// MARK: - Expect values

extension AsyncRecorder where Output: Equatable {
    /// Collects elements of `AsyncRecorder`and compares it to an list of expected elements
    ///
    ///  Usage:
    ///
    ///     let recorder = sut.$isLoading.record()
    ///     await sut.startLoading()
    ///     await recorder.expect(false, true, false)
    /// - Parameters:
    ///   - values: List of values in order that the publisher is expected to produce
    @discardableResult public func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        await expect(values, sourceLocation: sourceLocation)
        return self
    }

    /// Collects elements of `AsyncRecorder`and compares it to an list of expected elements
    ///
    ///  Usage:
    ///
    ///     let recorder = sut.$isLoading.record()
    ///     await sut.startLoading()
    ///     await recorder.expect(false, true, false)
    /// - Parameters:
    ///   - values: List of values in order that the publisher is expected to produce
    @discardableResult func expect(_ values: [Output], sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        var fetchedValues: [Output] = []
        for _ in 1...values.count {
            if let value = await next(sourceLocation: sourceLocation) {
                fetchedValues.append(value)
            }
        }
        if skipping {
            if fetchedValues != values {
                while let value = await next(sourceLocation: sourceLocation) {
                    fetchedValues.append(value)
                    if fetchedValues.contains(values) {
                        break
                    }
                }
            }
        }
        if skipping {
            #expect(fetchedValues.contains(values), sourceLocation: sourceLocation)
        } else {
            #expect(fetchedValues == values, sourceLocation: sourceLocation)
        }
        skipping = false
        return self
    }
}

// MARK: - Finished

public extension AsyncRecorder {
    /// Expect that the `Publisher`will complete with `.finish` with the next event
    ///
    /// expectation will fail when `Publisher` continues to produce values
    func expectFinished(sourceLocation: SourceLocation = #_sourceLocation) async {
        var value: RecorderValue?
        if skipping {
            while let val = await iterator.next() {
                value = val
                if val.isFinished() == true {
                    break
                }
            }
        } else {
            value = await iterator.next()
        }
        skipping = false
        #expect(value?.isFinished() == true, sourceLocation: sourceLocation)
    }
}

// MARK: - Failure

public extension AsyncRecorder where Failure: Error {
    /// Expect that the `Publisher`will complete with `.failure` with the next event.
    ///  The error will be thrown by this function and can be handled by `#expect(throws:)`
    func expectFailure(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        var value: RecorderValue?
        if skipping {
            while let val = await iterator.next() {
                value = val
                if case .failure(_) = val {
                    break
                }
            }
        } else {
            value = await iterator.next()
        }
        skipping = false

        if case .failure(let failure) = value {
            throw failure
        } else {
            Issue.record("No failure found", sourceLocation: sourceLocation)
        }
    }
}

// MARK: - Invocation

public extension AsyncRecorder where Output == Void {
    /// Expect that the `Publisher`will publish a specific amount of times `Void`
    /// - Parameters:
    ///   - invocations: number of invocations default is one
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

// MARK: - Times

public extension AsyncRecorder where Output: Equatable {
    /// expect a specific value for an amount of time
    /// - Parameters:
    ///   - value: value to be compared with
    ///   - times: how often do you expect to see the value
    @discardableResult func expect(_ value: Output, times: Int, sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        let result: [Output] = .init(repeating: value, count: times)
        await expect(result, sourceLocation: sourceLocation)
        return self
    }
}

// MARK: - Skipping

public extension AsyncRecorder where Output: Equatable {
    /// Skip to the next value that is `expect` also works for `expectFinished` and `expectFailure`
    @discardableResult func skipping(sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        skipping = true
        return self
    }
}

// MARK: - Expect with condition

public extension AsyncRecorder {
    /// expect next value to met the condition
    ///
    /// - Parameters:
    ///   - condition: the condition to be met
    @discardableResult func expect(_ condition: (Output?) -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async -> Self {
        var lastValue: Output?
        if let value = await next(sourceLocation: sourceLocation) {
            lastValue = value
        }
        if skipping {
            if !condition(lastValue) {
                while let value = await next(sourceLocation: sourceLocation) {
                    lastValue = value
                    if condition(lastValue) {
                        break
                    }
                }
            }
        }
        skipping = false
        #expect(condition(lastValue), sourceLocation: sourceLocation)
        return self
    }
}

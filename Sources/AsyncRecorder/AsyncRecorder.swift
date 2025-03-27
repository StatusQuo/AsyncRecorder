//
//  Recorder.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//
import Foundation
import Combine
import Testing

public final class AsyncRecorder<Output, Failure> where Output: Equatable, Failure == Never {
    private var subscription: AnyCancellable?
    private let publisher: any Publisher<Output, Failure>
    private var stream: AsyncStream<RecorderValue>!
    private var iterator: AsyncStream<RecorderValue>.Iterator!
    private let timeout: RunLoop.SchedulerTimeType.Stride

    enum RecorderValue {
        static func == (lhs: RecorderValue, rhs: RecorderValue) -> Bool {
            switch (lhs, rhs) {
            case (.value(let vl), .value(let vr)):
                return vl == vr
            case (.finished, .finished):
                return true
            case (.timeout, .timeout):
                return true
            default:
                return false
            }
        }

        case value(Output)
        case finished
        case timeout
    }

    init(publisher: any Publisher<Output, Failure>, timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) {
        self.timeout = timeout
        self.publisher = publisher
        subscribe()
    }

    enum RecorderError: Error {
        case timeout
    }

    private func subscribe() {
        var handler: ((Output) -> Void)!
        var completion: ((RecorderError?) -> Void)!

        stream = AsyncStream { continuation in
            handler = { output in
                continuation.yield(RecorderValue.value(output))
            }
            completion = { error in
                if error != nil {
                    continuation.yield(RecorderValue.timeout)
                } else {
                    continuation.yield(RecorderValue.finished)
                }
                continuation.finish()
                self.subscription = nil
            }
        }

        subscription = publisher
            .eraseToAnyPublisher()
            .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
            .assertNoFailure()
            .setFailureType(to: RecorderError.self)
            .timeout(timeout, scheduler: RunLoop.main, customError: {
                return .timeout
            })
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

    public func next(sourceLocation: SourceLocation = #_sourceLocation) async -> Output? {
        let value = await iterator.next()
        switch value {
        case .value(let result):
            return result
        case .timeout:
            #expect(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
        case .finished, .none:
            #expect(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
        }
        return nil
    }

    public func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async {
        var fetchedValues: [Output] = []
        for _ in 1...values.count {
            if let value = await next(sourceLocation: sourceLocation) {
                fetchedValues.append(value)
            }
        }
        #expect(fetchedValues == values, sourceLocation: sourceLocation)
    }

    public func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async {
        let value = await iterator.next()
        #expect(value != nil)
        #expect(value! == .finished, sourceLocation: sourceLocation)
    }
}

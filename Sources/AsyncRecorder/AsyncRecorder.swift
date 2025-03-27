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

extension Publisher {
    func record() -> AsyncThrowingRecorder<Output, Failure> where Output: Equatable, Failure: Error {
        .init(publisher: self)
    }
//
//    func record() -> AsyncRecorder<Output, Failure> where Output: Equatable, Failure == Never {
//        .init(publisher: self)
//    }
}

class AsyncThrowingRecorder<Output, Failure> where Failure: Error, Output: Equatable & Sendable {
    private var subscription: AnyCancellable?
    private let publisher: any Publisher<Output, Failure>
    private var stream: AsyncStream<RecorderValue>!
    private var iterator: AsyncStream<RecorderValue>.Iterator!
    private let timeout: RunLoop.SchedulerTimeType.Stride

    enum RecorderValue: Sendable {
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

    func next(sourceLocation: SourceLocation = #_sourceLocation) async throws -> Output {
        let value = await iterator.next()
        try #require(value != nil, sourceLocation: sourceLocation)
        switch value {
        case .value(let result):
            return result
        case .timeout:
            try #require(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
        case .finished, .none:
            try #require(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
        case .failure(let error):
            throw error
        }
        fatalError("This line will never be reached while testing")
    }

    func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async throws where Output:Equatable {
        var fetchedValues: [Output] = []
        for _ in 1...values.count {
            let value = try await next(sourceLocation: sourceLocation)
            fetchedValues.append(value)
        }
        #expect(fetchedValues == values, sourceLocation: sourceLocation)
    }

    func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let value = await iterator.next()
        try #require(value != nil)
        #expect(value! == .finished, sourceLocation: sourceLocation)
    }
}


//
//class AsyncRecorder<Output, Never> where Output: Equatable {
//    private var subscription: AnyCancellable?
//    private let publisher: any Publisher<Output, Never>
//    private var stream: AsyncStream<RecorderValue>!
//    private var iterator: AsyncStream<RecorderValue>.Iterator!
//    private let timeout: RunLoop.SchedulerTimeType.Stride
//
//    enum RecorderValue {
//        static func == (lhs: RecorderValue, rhs: RecorderValue) -> Bool {
//            switch (lhs, rhs) {
//            case (.value(let vl), .value(let vr)):
//                return vl == vr
//            case (.finished, .finished):
//                return true
//            case (.timeout, .timeout):
//                return true
//            default:
//                return false
//            }
//        }
//
//        case value(Output)
//        case finished
//        case timeout
//    }
//
//    init(publisher: any Publisher<Output, Never>, timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) {
//        self.timeout = timeout
//        self.publisher = publisher
//        subscribe()
//    }
//
//    enum RecorderError: Error {
//        case timeout
//    }
//
//    private func subscribe() {
//        var handler: ((Output) -> Void)!
//        var completion: ((RecorderError?) -> Void)!
//
//        stream = AsyncStream { continuation in
//            handler = { output in
//                continuation.yield(RecorderValue.value(output))
//            }
//            completion = { error in
//                if let error {
//                    continuation.yield(.timeout)
//                } else {
//                    continuation.yield(.finished)
//                }
//                continuation.finish()
//                self.subscription = nil
//            }
//        }
//
//        subscription = publisher
//            .eraseToAnyPublisher()
//            .assertNoFailure()
//            .setFailureType(to: RecorderError.self)
//            .timeout(timeout, scheduler: RunLoop.main, customError: {
//                return RecorderError.timeout
//            })
//            .buffer(size: .max, prefetch: .byRequest, whenFull: .dropOldest)
//            .sink { result in
//                switch result {
//                case .failure(let error):
//                    completion(error)
//                case .finished:
//                    completion(nil)
//                }
//                self.subscription = nil
//            } receiveValue: { value in
//                handler(value)
//            }
//
//        iterator = stream.makeAsyncIterator()
//    }
//
//    func next(sourceLocation: SourceLocation = #_sourceLocation) async -> Output {
//        let value = await iterator.next()
//        #expect(value != nil, sourceLocation: sourceLocation)
//        switch value {
//        case .value(let result):
//            return result
//        case .timeout:
//            #expect(Bool(false), "Timeout reached", sourceLocation: sourceLocation)
//        case .finished, .none:
//            #expect(Bool(false), "End of stream reached", sourceLocation: sourceLocation)
//        }
//        fatalError("...")
//    }
//
//    func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async {
//        var fetchedValues: [Output] = []
//        for _ in 1...values.count {
//            let value = await next()
//            fetchedValues.append(value)
//        }
//        #expect(fetchedValues == values, sourceLocation: sourceLocation)
//    }
//
//    func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async {
//        let value = await iterator.next()
//        #expect(value != nil)
//        #expect(value! == .finished, sourceLocation: sourceLocation)
//    }
//}

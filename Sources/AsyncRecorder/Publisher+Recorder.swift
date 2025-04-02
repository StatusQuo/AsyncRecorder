//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//
import Combine
import Testing

public extension Publisher {
    func record() -> AsyncRecorder<Output, Failure> {
        .init(publisher: self)
    }
}

//public final class AsyncRecorder<Output, Failure> {
//    let publisher: any Publisher<Output, Failure>
//    init(publisher: any Publisher<Output, Failure>) {
//        self.publisher = publisher
//    }
//
//    public func expect(_ values: Output..., sourceLocation: SourceLocation = #_sourceLocation) async {
//
//    }
//
//    public func next(sourceLocation: SourceLocation = #_sourceLocation) async -> Output? {
//        nil
//    }
//
//    public func expectCompletion(sourceLocation: SourceLocation = #_sourceLocation) async {
//        
//    }
//
//    public func expectInvocation(_ invocations: Int = 1, sourceLocation: SourceLocation = #_sourceLocation) async {
//
//    }
//}

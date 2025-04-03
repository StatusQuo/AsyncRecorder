//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//
import Combine
import Foundation

public extension Publisher {
    
    /// Create a `AsyncRecorder` for a given `Publisher`
    /// - Parameter timeout: timeout to wait for an expected event since the last value was published. default: 1 second
    /// - Returns: a new `AsyncRecorder`
    func record(timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) -> AsyncRecorder<Output, Failure> {
        .init(publisher: self, timeout: timeout)
    }
}

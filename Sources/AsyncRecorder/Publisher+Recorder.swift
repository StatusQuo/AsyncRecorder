//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//
import Combine
import Foundation

public extension Publisher {
    func record(timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) -> AsyncRecorder<Output, Failure> {
        .init(publisher: self, timeout: timeout)
    }
}

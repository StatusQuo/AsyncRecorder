//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by hus1fr on 27.03.25.
//
import Combine
import Foundation

public extension Publisher {
    func record(timeout: RunLoop.SchedulerTimeType.Stride = .seconds(1)) -> AsyncRecorder<Output, Failure> {
        .init(publisher: self, timeout: timeout)
    }
}

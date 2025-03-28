//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by hus1fr on 27.03.25.
//
import Combine

public extension Publisher {
    func record() -> AsyncThrowingRecorder<Output, Failure> where Output: Equatable, Failure: Error {
        .init(publisher: self)
    }

    func record() -> AsyncRecorder<Output, Failure> where Output: Equatable, Failure == Never {
        .init(publisher: self)
    }
}

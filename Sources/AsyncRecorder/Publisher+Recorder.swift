//
//  Publisher+Recorder.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//
import Combine

public extension Publisher {
    func record() -> AsyncThrowingRecorder<Output, Failure> where Failure: Error {
        .init(publisher: self)
    }

    func record() -> AsyncRecorder<Output, Failure> where Failure == Never {
        .init(publisher: self)
    }

    func record() -> AsyncRecorder<Output, Failure> where Output: Equatable, Failure == Never {
        .init(publisher: self)
    }
}

//
//  AsyncRecorder+Times.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 07.04.25.
//
import Testing

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

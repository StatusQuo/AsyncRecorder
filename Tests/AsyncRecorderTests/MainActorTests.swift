//
//  Test.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//

import Testing
import Combine
@testable import AsyncRecorder

@MainActor
struct MainActorTests {

    @Test func testSubject() async throws {
        let subject = PassthroughSubject<Int, Never>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .finished)

        await recorder.expect(0, 1)
    }

    @Test
    func publisherRunsIntoError() async throws {
        let subject = PassthroughSubject<Int, TestError>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .failure(.random))

        await #expect(throws: TestError.random) {
            try await recorder.expect(0, 1, 2)
        }
    }

}

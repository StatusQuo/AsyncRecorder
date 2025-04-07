//
//  Test.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 02.04.25.
//

import Testing
@testable import AsyncRecorder
import Combine

struct CurrentValueSubjectTests {
    let subject = CurrentValueSubject<Int, Never>(0)

    @Test
    func testForValues() async throws {
        let recorder = subject.record()

        subject.send(1)
        subject.send(2)
        subject.send(3)

        await recorder.expect(0, 1, 2, 3)
    }

    @Test
    func testMultipleExpects() async throws {
        let recorder = subject.record()

        subject.send(1)
        subject.send(2)
        subject.send(3)

        await recorder
            .expect(0, 1)
            .expect(2, 3)
    }

    @Test
    func testUsingNext() async throws {
        let recorder = subject.record()

        subject.send(1)
        subject.send(2)
        subject.send(3)

        await #expect(recorder.next() == 0)
    }

    @Test
    func testForTimeoutToManyValues() async throws {
        await withKnownIssue {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder.expect(0, 1, 2, 3, 4)
        }
    }

    @Test
    func testForTimeoutNeverFinish() async throws {
        await withKnownIssue {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .expect(0, 1)
                .expectFinished()
        }
    }

    @Test
    func testForTimeoutNeverFails() async throws {
        await withKnownIssue {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            try await recorder
                .expect(0, 1)
                .expectFailure()
        }
    }
}

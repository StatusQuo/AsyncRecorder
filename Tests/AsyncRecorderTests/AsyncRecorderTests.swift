//
//  Test.swift
//  AsyncRecorder
//
//  Created by Sebastian Humann-Nehrke on 27.03.25.
//

import Testing
import Combine
@testable import AsyncRecorder

struct AsyncRecorderTests {
    @Test
    func testPublisherWithoutError() async throws {
        let subject = CurrentValueSubject<Int, Never>(0)
        let recorder = subject.record()

        subject.send(1)

        await recorder.expect(0, 1)
    }

    @Test
    func testPublisherTimeout() async throws {
        await withKnownIssue {
            let subject = CurrentValueSubject<Int, Never>(0)
            let recorder = subject.record()

            subject.send(1)

            await recorder.expect(0, 1, 2)
        }
    }

    @Test
    func testPublisherTimeoutOnCompletion() async throws {
        await withKnownIssue {
            let subject = PassthroughSubject<Int, Never>()
            let recorder = subject.record()

            subject.send(1)

            await recorder.expect(1)
            await recorder.expectCompletion()
        }
    }

    @Test func testPassthroughSubject() async throws {
        let subject = PassthroughSubject<Int, Never>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .finished)

        await recorder.expect(0, 1)
    }

    @Test func testPassthroughSubjectFinished() async throws {
        await withKnownIssue {
            let subject = PassthroughSubject<Int, Never>()
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)

            await recorder.expect(0, 1)
            await recorder.expect(2)
        }
    }

    @Test func testAsyncRecorder() async throws {
        let subject = CurrentValueSubject<Int, Never>(0)
        let recorder = subject.record()

        subject.send(1)

        await recorder.expect(0, 1)
    }
}

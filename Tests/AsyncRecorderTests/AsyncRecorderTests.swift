import Testing
import Combine
import Foundation
@testable import AsyncRecorder

struct AsyncRecorderTests {
    enum TestError:Error {
        case random
    }

    @Test func testPassthroughSubject() async throws {
        let subject = PassthroughSubject<Int, Never>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .finished)

        try await recorder.expect(0, 1)
    }

    @Test func publisherRunsIntoError() async throws {
        let subject = PassthroughSubject<Int, TestError>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .failure(.random))

        await #expect(throws: TestError.random) {
            try await recorder.expect(0, 1, 2)
        }
    }

    @Test
    func testPublisherWithoutError() async throws {
        let subject = CurrentValueSubject<Int, Never>(0)
        let recorder = subject.record()

        subject.send(1)

        try await recorder.expect(0, 1)
    }

    @Test func example11() async throws {
        let subject = PassthroughSubject<Int, Error>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)

        #expect(try await recorder.next() == 0)
        #expect(try await recorder.next() >= 0)
        #expect(try await recorder.next() >= 0)
        try await recorder.expectCompletion()

    }
}

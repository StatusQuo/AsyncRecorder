import Testing
import Combine
import Foundation
@testable import AsyncRecorder

struct AsyncThrowningRecorderTests {
    @Test func publisherRunsIntoError() async throws {
        let subject = PassthroughSubject<Int, TestError>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(completion: .failure(.random))

        await recorder.expect(0, 1)
    }

    @Test
    func testPublisherUnexpectedFailure() async throws {
        await withKnownIssue {
            let subject = CurrentValueSubject<Int, TestError>(0)
            let recorder = subject.record()

            subject.send(1)
            subject.send(completion: .failure(.random))

            await recorder.expect(0, 1, 2)
        }
    }

    @Test func example11() async throws {
        let subject = PassthroughSubject<Int, Error>()
        let recorder = subject.record()

        subject.send(0)
        subject.send(1)
        subject.send(2)
        subject.send(completion: .finished)

        #expect(await recorder.next() == 0)
        #expect(await recorder.next()! >= 0)
        #expect(await recorder.next()! >= 0)
        await recorder.expectCompletion()
    }
}

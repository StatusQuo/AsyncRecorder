//
//  Test.swift
//  AsyncRecorder
//
//  Created by hus1fr on 21.05.25.
//

import Testing
import Combine
@testable import AsyncRecorder

struct SkippingTests {
    struct CurrentValueSubjectTests {
        let subject = CurrentValueSubject<Int, Never>(0)

        @Test func testSkipToValue() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect(2)
        }

        @Test func testSkipToSequence() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect(2, 3)

        }

        @Test func testSkipToComplexSequence() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(2)
            subject.send(3)
            subject.send(4)

            await recorder
                .skipping()
                .expect(2, 3, 4)
        }

        @Test func testSkipAutoDisable() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(1)
                subject.send(2)
                subject.send(3)

                await recorder
                    .skipping()
                    .expect(1)
                    .expect(3)
            }
        }

        @Test func testMultiSkip() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect(1)
                .skipping()
                .expect(3)
        }
    }

    struct PassthroughSubjectTests {
        let subject = PassthroughSubject<Int, TestError>()

        @Test func testSkipToValue() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect(2)
        }

        @Test func testSkipToSequence() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect(2, 3)

        }

        @Test func testSkipToValueGotFinished() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(1)
                subject.send(completion: .finished)

                await recorder
                    .skipping()
                    .expect(2, 3)
            }
        }

        @Test func testSkipToFinished() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(completion: .finished)

            await recorder
                .skipping()
                .expectFinished()
        }

        @Test func testSkipToFinishedGotError() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(1)
                subject.send(2)
                subject.send(3)
                subject.send(completion: .failure(.random))

                await recorder
                    .skipping()
                    .expectFinished()
            }
        }

        @Test func testSkipToFailure() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)
            subject.send(completion: .failure(.random))

            await #expect(throws: TestError.random) {
                try await recorder
                     .skipping()
                     .expectFailure()
            }
        }
    }
}

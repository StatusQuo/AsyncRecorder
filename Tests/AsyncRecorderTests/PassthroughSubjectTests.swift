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
struct PassthroughSubjectTests {
    struct WithoutErrors {
        let subject = PassthroughSubject<Int, Never>()

        @Test func testExpectValues() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await recorder.expect(0, 1)
        }

        @Test func testExpectCompletion() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await recorder
                .expect(0, 1)
                .expectCompletion()
        }

        @Test func testTimeoutOnValues() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)
                subject.send(completion: .finished)

                await recorder
                    .expect(0, 1, 2)
                    .expectCompletion()
            }
        }

        @Test func testTimeoutOnCompletion() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)

                await recorder
                    .expect(0, 1)
                    .expectCompletion()
            }
        }

        @Test func testTimeoutOnError() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)
                subject.send(completion: .finished)

                await #expect(throws: TestError.random) {
                    try await recorder
                        .expect(0, 1)
                        .expectError()
                }
            }
        }

        @Test func testUsingNext() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await #expect(recorder.next() == 0)
        }
    }

    struct WithError {
        let subject = PassthroughSubject<Int, TestError>()

        @Test func testExpectValues() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await recorder.expect(0, 1)
        }

        @Test func testExpectCompletion() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await recorder
                .expect(0, 1)
                .expectCompletion()
        }

        @Test func testExpectError() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .failure(.random))

            await #expect(throws: TestError.random) {
                try await recorder
                    .expect(0, 1)
                    .expectError()
            }
        }

        @Test func testTimeoutOnValues() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)
                subject.send(completion: .finished)

                await recorder
                    .expect(0, 1, 2)
                    .expectCompletion()
            }
        }

        @Test func testTimeoutOnCompletion() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)

                await recorder
                    .expect(0, 1)
                    .expectCompletion()
            }
        }

        @Test func testTimeoutOnError() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)
                subject.send(completion: .finished)

                await #expect(throws: TestError.random) {
                    try await recorder
                        .expect(0, 1)
                        .expectError()
                }
            }
        }

        @Test func testUsingNext() async throws {
            let recorder = subject.record()

            subject.send(0)
            subject.send(1)
            subject.send(completion: .finished)

            await #expect(recorder.next() == 0)
        }

        @Test
        func testPublisherUnexpectedFailure() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(1)
                subject.send(completion: .failure(.random))

                await recorder.expect(0, 1, 2)
            }
        }

        @Test func testPassthroughSubjectFinished() async throws {
            await withKnownIssue {
                let recorder = subject.record()

                subject.send(0)
                subject.send(1)
                subject.send(completion: .finished)

                await recorder.expect(0, 1)
                await recorder.expect(2)
            }
        }
    }

    struct WithVoidType {
        let subject = PassthroughSubject<Void, Never>()
        @Test
        func testExpect() async throws {
            let recorder = subject.record()

            subject.send(())

            await #expect(recorder.next()! == ())
        }

        @Test
        func testExpectInvocation() async throws {
            let recorder = subject.record()

            subject.send(())
            subject.send(())
            subject.send(())

            await recorder.expectInvocation(3)
        }


    }
}

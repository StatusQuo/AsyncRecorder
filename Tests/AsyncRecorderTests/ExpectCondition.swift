//
//  Test.swift
//  AsyncRecorder
//
//  Created by hus1fr on 21.05.25.
//

import Testing
import Combine
@testable import AsyncRecorder

struct ExpectConditionTests {
    struct CurrentValueSubjectTests {
        let subject = CurrentValueSubject<Int, Never>(0)

        @Test func ExpectConditionTest() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .expect(0)
                .expect {
                $0! > 0
            }
        }

        @Test func ExpectConditionTestSkipping() async throws {
            let recorder = subject.record()

            subject.send(1)
            subject.send(2)
            subject.send(3)

            await recorder
                .skipping()
                .expect {
                $0! > 0
            }
        }

    }
}

//
//  Created by Sebastian Humann-Nehrke on 07.04.25.
//

import Testing
import Combine

struct TimesTests {
    let subject = CurrentValueSubject<Int, Never>(0)

    @Test func testTimes() async throws {
        let recorder = subject.record()

        subject.send(1)
        subject.send(1)
        subject.send(1)
        subject.send(2)
        subject.send(2)
        subject.send(2)
        subject.send(2)

        await recorder
            .expect(0)
            .expect(1, times: 3)
            .expect(2, times: 4)
    }

    @Test func testTimesWithSkipping() async throws {
        let recorder = subject.record()

        subject.send(1)
        subject.send(1)
        subject.send(1)
        subject.send(2)
        subject.send(2)
        subject.send(2)
        subject.send(2)

        await recorder
            .expect(0)
            .skipping()
            .expect(2, times: 4)
    }

    @Test func testTimesFails() async throws {
        await withKnownIssue {
            let recorder = subject.record()

            subject.send(1)
            subject.send(1)
            subject.send(1)
            subject.send(1)
            subject.send(2)
            subject.send(2)
            subject.send(2)

            await recorder
                .expect(0)
                .expect(1, times: 3)
                .expect(2, times: 4)
        }
    }
}

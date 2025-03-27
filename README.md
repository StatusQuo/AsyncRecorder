# AsyncRecorder
AsyncRecorder enables testing combine publishers using await.

```swift
@Test
func testPublisherWithoutError() async throws {
    let subject = CurrentValueSubject<Int, Never>(0)
    let recorder = subject.record() //Create new AsyncRecorder

    subject.send(1)

    await recorder.expect(0, 1) //Expect a sequence of values
}
```

# AsyncRecorder  

**AsyncRecorder** enables testing of Combine publishers using `await`.  

## Installation  

Add AsyncRecorder as a dependency in your `Package.swift` file:  

```swift
dependencies: [
    .package(url: "https://github.com/StatusQuo/AsyncRecorder", from: "1.0.0")
]
```

## Usage  

Import AsyncRecorder in your test files:  

```swift
import AsyncRecorder
```

Use `record()` on a Combine publisher to create an `AsyncRecorder`, and use `await` for asynchronous testing:  

```swift
import Testing
import Combine
import AsyncRecorder

struct PublisherTests {
    @Test
    func test() async throws {
        let subject = CurrentValueSubject<Int, Never>(0)
        let recorder = subject.record() //Create new AsyncRecorder

        subject.send(1)

        await recorder.expect(0, 1) //Expect a sequence of values
    }
}
```

## Documentation

### Test Completion of Publishers

We can also `await` the completion of a `Publisher`

```swift
@Test func testExpectCompletion() async throws {
    let subject = PassthroughSubject<Int, Never>()
    let recorder = subject.record()

    subject.send(0)
    subject.send(1)
    subject.send(completion: .finished)

    await recorder
        .expect(0, 1)
        .expectCompletion()
}
```

### Test Failure of Publishers

We can also `await` the error of a `Publisher`

```swift
@Test func testExpectError() async throws {
    let subject = PassthroughSubject<Int, Never>()
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
```

### Test Void Publishers

With `expectInvocation` is handy to expect Void Publishers.

```swift
@Test
func testExpectInvocation() async throws {
    let subject = PassthroughSubject<Void, Never>()
    let recorder = subject.record()

    subject.send(())
    subject.send(())
    subject.send(())

    await recorder.expectInvocation(3)
}
```

### Use manual `next()` for more complex Types

```swift
@Test
func testExpectInvocation() async throws {
    let subject = PassthroughSubject<ViewUpdate, Never>()
    let recorder = subject.record()

    subject.send(.init(progress: 40, callback: nil))
    
    await #expect(recorder.next()?.progress == 40)
}
```

## Credits

This library is based on "ST K"s stackoverflow answer: https://stackoverflow.com/a/78506360

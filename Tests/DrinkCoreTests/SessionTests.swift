import XCTest
@testable import DrinkCore

final class SessionTests: XCTestCase {
    private final class FakeAssertion: SleepAssertion {
        var isRunning = false
        var terminationStatus: Int32 = 0
        var duration: Int?
        var screen: Bool?
        var stopCount = 0
        var failOnStart = false

        func start(duration: Int, screen: Bool) throws {
            if failOnStart { throw CommandError("Launch failed") }
            self.duration = duration
            self.screen = screen
            isRunning = true
        }

        func stop() {
            stopCount += 1
            isRunning = false
        }
    }

    func testCaffeinateArgumentsTrackOnlyTheParentAndRequestedModes() {
        XCTAssertEqual(CaffeinateProcess.arguments(duration: 1_800, screen: false, parentPID: 321), ["-i", "-t", "1800", "-w", "321"])
        XCTAssertEqual(CaffeinateProcess.arguments(duration: 60, screen: true, parentPID: 123), ["-i", "-d", "-t", "60", "-w", "123"])
    }

    func testCountdownAndTimerCompletion() throws {
        let process = FakeAssertion()
        let session = CoffeeSession(seconds: 60, screen: true, assertion: process)
        try session.start(at: 100)
        XCTAssertEqual(process.duration, 60)
        XCTAssertEqual(process.screen, true)
        XCTAssertEqual(session.state(at: 100), .active(remaining: 60))
        XCTAssertEqual(session.state(at: 100.5), .active(remaining: 60))
        XCTAssertEqual(session.state(at: 159.1), .active(remaining: 1))
        XCTAssertEqual(session.state(at: 160), .finished)
        session.stop()
        session.stop()
        XCTAssertEqual(process.stopCount, 1)
    }

    func testUnexpectedEarlyExitIncludingZeroStatusIsAnError() throws {
        let process = FakeAssertion()
        let session = CoffeeSession(seconds: 60, assertion: process)
        try session.start(at: 100)
        process.isRunning = false
        XCTAssertEqual(session.state(at: 110), .failed(exitCode: 0))
        process.terminationStatus = 9
        XCTAssertEqual(session.state(at: 111), .failed(exitCode: 9))
        XCTAssertEqual(session.state(at: 160), .finished)
    }

    func testDemoRunsWithoutLaunchingAnAssertion() throws {
        let session = CoffeeSession(seconds: 15, assertion: nil)
        try session.start(at: 100)
        XCTAssertEqual(session.state(at: 101), .active(remaining: 14))
        XCTAssertEqual(session.state(at: 115), .finished)
    }

    func testSessionReleasesItsOwnedProcess() throws {
        let process = FakeAssertion()
        var session: CoffeeSession? = CoffeeSession(seconds: 60, assertion: process)
        try session?.start(at: 100)
        session = nil
        XCTAssertEqual(process.stopCount, 1)
        XCTAssertFalse(process.isRunning)
    }

    func testLaunchErrorIsPropagated() {
        let process = FakeAssertion()
        process.failOnStart = true
        let session = CoffeeSession(seconds: 60, assertion: process)
        XCTAssertThrowsError(try session.start(at: 100))
        session.stop()
        XCTAssertEqual(process.stopCount, 0)
    }
}

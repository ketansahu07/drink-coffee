import Darwin
import Foundation

public protocol SleepAssertion: AnyObject {
    var isRunning: Bool { get }
    var terminationStatus: Int32 { get }
    func start(duration: Int, screen: Bool) throws
    func stop()
}

public final class CaffeinateProcess: SleepAssertion {
    private let process = Process()
    private var started = false

    public init() {}

    public static func arguments(duration: Int, screen: Bool, parentPID: Int32) -> [String] {
        var arguments = ["-i"]
        if screen { arguments.append("-d") }
        arguments += ["-t", String(duration), "-w", String(parentPID)]
        return arguments
    }

    public var isRunning: Bool { started && process.isRunning }
    public var terminationStatus: Int32 { process.terminationStatus }

    public func start(duration: Int, screen: Bool) throws {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = Self.arguments(duration: duration, screen: screen, parentPID: getpid())
        try process.run()
        started = true
    }

    public func stop() {
        guard started else { return }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        started = false
    }

    deinit { stop() }
}

public enum CoffeeSessionState: Equatable {
    case active(remaining: Int)
    case finished
    case failed(exitCode: Int32)
}

public final class CoffeeSession {
    private let seconds: Int
    private let screen: Bool
    private let assertion: SleepAssertion?
    private var startedAt: Double?
    private var stopped = false

    public init(seconds: Int, screen: Bool = false, assertion: SleepAssertion?) {
        precondition(seconds > 0 && seconds <= CoffeeDuration.maximumSeconds)
        self.seconds = seconds
        self.screen = screen
        self.assertion = assertion
    }

    public func start(at time: Double) throws {
        precondition(startedAt == nil)
        try assertion?.start(duration: seconds, screen: screen)
        startedAt = time
    }

    public func state(at time: Double) -> CoffeeSessionState {
        guard let startedAt else { preconditionFailure("Start the session before checking its state.") }
        let elapsed = max(0, time - startedAt)
        if stopped || elapsed >= Double(seconds) { return .finished }
        if let assertion, !assertion.isRunning {
            return .failed(exitCode: assertion.terminationStatus)
        }
        return .active(remaining: Int(ceil(Double(seconds) - elapsed)))
    }

    public func stop() {
        guard startedAt != nil, !stopped else { return }
        assertion?.stop()
        stopped = true
    }

    deinit { stop() }
}

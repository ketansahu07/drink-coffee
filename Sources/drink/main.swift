import Darwin
import DrinkCore
import Foundation

private var caughtSignal: sig_atomic_t = 0

private func recordSignal(_ value: Int32) {
    caughtSignal = value
}

private let help = """
Usage: drink coffee [for] [duration] [options]

Offer your Mac a coffee. It stays awake while a little computer takes a sip.

  drink coffee 30m         Stay awake for 30 minutes
  drink coffee             A 30-minute coffee break
  drink coffee 1h          Stay awake for an hour
  drink coffee 1h30m       Stay awake for 90 minutes
  drink coffee for 2h 30m  Stay awake for 2 hours and 30 minutes
  drink coffee 45s --demo  Preview the animation without changing sleep behavior

Duration: 30m, 1h30m, or 1h 30m; greater than zero and at most 7 days.

Options:
  --screen        Keep the display awake too
  --no-animation  Keep awake without the animation
  --demo          Animation only (defaults to 15 seconds)
  --help          Show this help
  --version       Show the version

Press Ctrl+C to end your coffee break early. Keep the lid open.
"""

private func writeOutput(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

private func writeError(_ text: String) {
    FileHandle.standardError.write(Data(text.utf8))
}

private func terminalSize() -> (columns: Int, rows: Int) {
    var size = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0, size.ws_row > 0 {
        return (Int(size.ws_col), Int(size.ws_row))
    }
    return (80, 24)
}

private func run(_ options: CoffeeOptions) throws -> (code: Int32, message: String) {
    signal(SIGINT, recordSignal)
    signal(SIGTERM, recordSignal)
    signal(SIGHUP, recordSignal)

    let environment = ProcessInfo.processInfo.environment
    let animated = !options.noAnimation && isatty(STDOUT_FILENO) == 1 && environment["TERM"] != "dumb"
    let color = environment["NO_COLOR"] == nil
    let assertion: SleepAssertion? = options.demo ? nil : CaffeinateProcess()
    let session = CoffeeSession(seconds: options.seconds, screen: options.screen, assertion: assertion)
    let start = ProcessInfo.processInfo.systemUptime
    try session.start(at: start)
    defer { session.stop() }

    if animated {
        writeOutput("\u{1B}[?1049h\u{1B}[?25l\u{1B}[2J\u{1B}[H")
    } else {
        let action = options.demo ? "Coffee demo" : "Keeping your Mac\(options.screen ? " and display" : "") awake"
        writeOutput("\(action) for \(CoffeeDuration.describe(options.seconds)). Press Ctrl+C to stop.\n")
    }
    defer {
        if animated { writeOutput((color ? "\u{1B}[0m" : "") + "\u{1B}[?25h\u{1B}[?1049l") }
    }

    let renderer = CoffeeRenderer()
    let interval = animated ? 1.0 / 12.0 : 0.1
    var previousSize = (columns: 0, rows: 0)
    while true {
        if caughtSignal != 0 {
            return (128 + caughtSignal, options.demo ? "Demo ended." : "Coffee break ended early. Normal sleep settings restored.")
        }
        let now = ProcessInfo.processInfo.systemUptime
        switch session.state(at: now) {
        case .finished:
            return (0, options.demo ? "Demo finished." : "Coffee finished. Normal sleep settings restored.")
        case .failed(let status):
            throw CommandError("caffeinate stopped unexpectedly (exit \(status)). Your Mac is no longer being kept awake.")
        case .active(let remaining):
            if animated {
                let size = terminalSize()
                if size.columns != previousSize.columns || size.rows != previousSize.rows {
                    writeOutput("\u{1B}[2J")
                    previousSize = size
                }
                let frame = renderer.frame(elapsed: now - start, columns: size.columns, rows: size.rows, remaining: remaining, color: color)
                let clearedLines = frame.replacingOccurrences(of: "\n", with: "\u{1B}[K\n")
                writeOutput("\u{1B}[H" + clearedLines + "\u{1B}[K\u{1B}[J")
            }
        }
        let nextFrame = now + interval
        Thread.sleep(forTimeInterval: max(0, min(nextFrame, start + Double(options.seconds)) - ProcessInfo.processInfo.systemUptime))
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
    writeOutput(help + "\n")
    exit(0)
}
if arguments == ["--version"] || arguments == ["coffee", "--version"] {
    writeOutput("drink 0.1.0\n")
    exit(0)
}

let options: CoffeeOptions
do {
    options = try CoffeeOptions.parse(arguments)
} catch {
    writeError("drink: \(error.localizedDescription)\n")
    exit(64)
}

do {
    let result = try run(options)
    writeOutput(result.message + "\n")
    exit(result.code)
} catch {
    writeError("drink: \(error.localizedDescription)\n")
    exit(1)
}

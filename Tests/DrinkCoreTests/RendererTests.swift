import XCTest
@testable import DrinkCore

final class RendererTests: XCTestCase {
    func testFramesFitTerminalAndContainNoEscapesWithoutColor() {
        let renderer = CoffeeRenderer()
        for (width, height) in [(1, 1), (20, 10), (30, 16), (80, 24), (110, 44), (400, 200)] {
            let frame = renderer.frame(elapsed: 5, columns: width, rows: height, remaining: 1498, color: false)
            let lines = frame.components(separatedBy: "\n")
            XCTAssertLessThanOrEqual(lines.count, min(height, 60))
            XCTAssertTrue(lines.allSatisfy { $0.count <= min(width, 160) })
            XCTAssertFalse(frame.contains("\u{1B}"))
        }
    }

    func testSipMovesAndBothComputerAndMugHaveTheirOwnColors() {
        let renderer = CoffeeRenderer()
        let resting = renderer.frame(elapsed: 0, columns: 110, rows: 44, remaining: 1500, color: true)
        let sipping = renderer.frame(elapsed: 5, columns: 110, rows: 44, remaining: 1495, color: true)
        XCTAssertNotEqual(resting, sipping)
        XCTAssertTrue(sipping.contains("\u{1B}[38;2;159;247;250m"), "The computer's face is cyan.")
        XCTAssertTrue(sipping.contains("\u{1B}[38;2;255;220;139m"), "The mug's rim is gold.")
        XCTAssertTrue(sipping.contains("24:55"))
        XCTAssertTrue(sipping.contains("Ctrl+C"))
    }

    func testFinishedAndUnusualTimeInputsRenderSafely() {
        let renderer = CoffeeRenderer()
        for elapsed in [Double.nan, .infinity, -.infinity, -2, 1e200] {
            let frame = renderer.frame(elapsed: elapsed, columns: 80, rows: 24, remaining: -1, color: false)
            XCTAssertTrue(frame.contains("COFFEE FINISHED"))
        }
        let longSession = renderer.frame(elapsed: 1, columns: 100, rows: 40, remaining: 7201, color: false)
        XCTAssertTrue(longSession.contains("2:00:01"))
    }
}

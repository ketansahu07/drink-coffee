import XCTest
@testable import DrinkCore

final class DurationTests: XCTestCase {
    func testCompactDurationsAndBoundaries() throws {
        for (text, expected) in [("30m", 1_800), ("1h", 3_600), ("1h30m", 5_400), ("1s", 1), ("7d", 604_800), ("0h30m", 1_800), ("6d23h59m59s", 604_799)] {
            XCTAssertEqual(try CoffeeDuration.parse(text), expected, text)
        }
    }

    func testRejectsAmbiguousInvalidAndExcessiveDurations() {
        for text in ["", "0s", "0h0m", "30", "m", "-1m", "+1h", "1.5h", "1 h", "1hour", "1H", "coffee", "1m1m", "7d1s", "8d", "999999999999999999999999999999999999999999s"] {
            XCTAssertThrowsError(try CoffeeDuration.parse(text), text)
        }
    }

    func testCommandDefaultsAndOptions() throws {
        XCTAssertEqual(try CoffeeOptions.parse(["coffee"]).seconds, 1_800)
        let options = try CoffeeOptions.parse(["coffee", "--screen", "1h30m", "--no-animation"])
        XCTAssertEqual(options.seconds, 5_400)
        XCTAssertTrue(options.screen)
        XCTAssertTrue(options.noAnimation)
        XCTAssertFalse(options.demo)
        XCTAssertEqual(try CoffeeOptions.parse(["coffee", "--demo"]).seconds, 15)
        XCTAssertEqual(try CoffeeOptions.parse(["coffee", "3s", "--demo"]).seconds, 3)
    }

    func testSpacedAndCombinedDurationsWithOptionalFor() throws {
        for arguments in [["coffee", "for", "2h", "30m", "15s"], ["coffee", "2h", "30m", "15s"], ["coffee", "2h30m15s"]] {
            XCTAssertEqual(try CoffeeOptions.parse(arguments).seconds, 9_015)
        }
        XCTAssertEqual(try CoffeeOptions.parse(["coffee", "for", "30m", "--screen"]).seconds, 1_800)
    }

    func testRejectsUnknownCommandsOptionsAndInvalidDurationTokens() {
        for arguments in [["tea"], ["coffee", "--unknown"], ["coffee", "30m", "10m"], ["coffee", "-1m"], ["coffee", "for"], ["coffee", "for", "--screen"], ["coffee", "3", "0m"], ["coffee", "30m", "garbage"]] {
            XCTAssertThrowsError(try CoffeeOptions.parse(arguments))
        }
    }

    func testFormatsHumanReadableDurations() {
        XCTAssertEqual(CoffeeDuration.describe(5_401), "1h30m1s")
        XCTAssertEqual(CoffeeDuration.describe(1_800), "30m")
    }
}

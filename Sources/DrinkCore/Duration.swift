import Foundation

public enum CoffeeDuration {
    public static let maximumSeconds = 7 * 24 * 60 * 60
    public static let defaultSeconds = 30 * 60

    public static func parse(_ text: String) throws -> Int {
        let bytes = Array(text.utf8)
        var index = 0
        var total = 0
        var units = Set<UInt8>()

        while index < bytes.count {
            var amount = 0
            let start = index
            while index < bytes.count, (48...57).contains(bytes[index]) {
                let digit = Int(bytes[index] - 48)
                guard amount <= (maximumSeconds - digit) / 10 else {
                    throw DurationError.tooLong
                }
                amount = amount * 10 + digit
                index += 1
            }
            guard index > start, index < bytes.count else {
                throw DurationError.invalidFormat
            }

            let unit = bytes[index]
            let multiplier: Int
            switch unit {
            case 115: multiplier = 1
            case 109: multiplier = 60
            case 104: multiplier = 60 * 60
            case 100: multiplier = 24 * 60 * 60
            default: throw DurationError.invalidFormat
            }
            guard units.insert(unit).inserted else {
                throw DurationError.repeatedUnit
            }
            guard amount <= (maximumSeconds - total) / multiplier else {
                throw DurationError.tooLong
            }
            total += amount * multiplier
            index += 1
        }

        guard total > 0 else { throw DurationError.notPositive }
        return total
    }

    public static func describe(_ seconds: Int) -> String {
        var remainder = seconds
        var parts: [String] = []
        for (unit, divisor) in [("d", 86_400), ("h", 3_600), ("m", 60), ("s", 1)] {
            let amount = remainder / divisor
            if amount > 0 { parts.append("\(amount)\(unit)") }
            remainder %= divisor
        }
        return parts.isEmpty ? "0s" : parts.joined()
    }
}

public enum DurationError: Error, LocalizedError, Equatable {
    case invalidFormat
    case notPositive
    case tooLong
    case repeatedUnit

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Use a duration such as 30m, 1h, 1h30m, or 45s."
        case .notPositive: return "Duration must be greater than zero."
        case .tooLong: return "Duration cannot exceed 7 days."
        case .repeatedUnit: return "Use each duration unit only once, such as 1h30m."
        }
    }
}

public struct CoffeeOptions: Equatable {
    public var seconds = CoffeeDuration.defaultSeconds
    public var noAnimation = false
    public var screen = false
    public var demo = false

    public init() {}

    public static func parse(_ arguments: [String]) throws -> CoffeeOptions {
        guard arguments.first == "coffee" else {
            throw CommandError("Try 'drink coffee 30m'. Run 'drink --help' for more options.")
        }
        var options = CoffeeOptions()
        var remaining = Array(arguments.dropFirst())
        let hasFor = remaining.first == "for"
        if hasFor { remaining.removeFirst() }
        var durationParts: [String] = []
        for argument in remaining {
            switch argument {
            case "--no-animation": options.noAnimation = true
            case "--screen": options.screen = true
            case "--demo": options.demo = true
            default:
                guard !argument.hasPrefix("-") else {
                    throw CommandError("Unknown option '\(argument)'. Run 'drink --help' for options.")
                }
                guard let last = argument.utf8.last, [UInt8(100), 104, 109, 115].contains(last) else {
                    throw DurationError.invalidFormat
                }
                durationParts.append(argument)
            }
        }
        if !durationParts.isEmpty {
            options.seconds = try CoffeeDuration.parse(durationParts.joined())
        } else if hasFor {
            throw CommandError("Add a duration after 'for', such as 'drink coffee for 30m'.")
        } else if options.demo {
            options.seconds = 15
        }
        return options
    }
}

public struct CommandError: Error, LocalizedError {
    public let message: String

    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

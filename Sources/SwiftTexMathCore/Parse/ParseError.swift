import Foundation

/// Typed LaTeX math parse failure.
public struct ParseError: Error, Sendable, Equatable, CustomStringConvertible {
    public enum Code: Int, Sendable, Equatable {
        case mismatchedBraces = 1
        case invalidCommand
        case characterNotFound
        case missingDelimiter
        case invalidDelimiter
        case missingRight
        case missingLeft
        case invalidEnvironment
        case missingEnvironment
        case missingBegin
        case missingEnd
        case invalidNumberOfColumns
        case invalidLimits
        case unexpectedEnd
        case nestingTooDeep
        case internalError
    }

    public var code: Code
    public var message: String

    public init(code: Code, message: String) {
        self.code = code
        self.message = message
    }

    public var description: String {
        "\(code): \(message)"
    }
}

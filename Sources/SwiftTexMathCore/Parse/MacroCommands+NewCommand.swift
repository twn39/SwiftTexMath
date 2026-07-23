import Foundation

/// Simple TeX-style user macros: `\newcommand`, `\renewcommand`, `\providecommand`, `\def`.
///
/// Supported forms (math-mode subset):
/// - `\newcommand{\foo}{body}`
/// - `\newcommand{\foo}[n]{body}` with `n` in 1…9, parameters `#1`…`#n` (`##` → `#`)
/// - `\renewcommand` always overwrites; `\providecommand` only if undefined
/// - `\def\foo{body}` / `\def\foo#1#2{body}` (parameter tokens before `{`, no optional `[n]`)
///
/// Expansion re-parses the substituted body with the same macro table (depth-capped).
extension MacroCommands {
    static func handleDefinition(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws -> Bool {
        switch command {
        case "newcommand":
            try defineMacro(parser: &parser, mode: .new)
        case "renewcommand":
            try defineMacro(parser: &parser, mode: .renew)
        case "providecommand":
            try defineMacro(parser: &parser, mode: .provide)
        case "def":
            try defineDef(parser: &parser)
        default:
            return false
        }
        // Definitions produce no atoms.
        _ = list
        _ = prev
        return true
    }

    private enum DefineMode {
        case new
        case renew
        case provide
    }

    private static func defineMacro(parser: inout MathParser, mode: DefineMode) throws {
        let name = try parser.readMacroControlSequenceName()
        let paramCount = try parser.readOptionalMacroParameterCount()
        let body = try parser.readBracedRaw()
        try install(
            name: name,
            macro: MathParser.UserMacro(parameterCount: paramCount, replacement: body),
            parser: &parser,
            mode: mode
        )
    }

    /// `\def\csname#1#2{body}` — parameter markers are literal `#1`… before the body brace.
    private static func defineDef(parser: inout MathParser) throws {
        parser.skipSpaces()
        guard parser.peek() == "\\" else {
            throw ParseError(code: .invalidCommand, message: "\\def expects a control sequence")
        }
        _ = parser.nextCharacter()
        let name = parser.readCommandName()
        guard !name.isEmpty else {
            throw ParseError(code: .invalidCommand, message: "\\def missing control sequence name")
        }
        var paramCount = 0
        parser.skipSpaces()
        while parser.peek() == "#" {
            _ = parser.nextCharacter()
            guard let ch = parser.peek(), let digit = ch.wholeNumberValue, digit >= 1, digit <= 9 else {
                throw ParseError(code: .invalidCommand, message: "\\def parameter must be #1…#9")
            }
            _ = parser.nextCharacter()
            if digit != paramCount + 1 {
                throw ParseError(
                    code: .invalidCommand,
                    message: "\\def parameters must be consecutive starting at #1"
                )
            }
            paramCount = digit
            parser.skipSpaces()
        }
        let body = try parser.readBracedRaw()
        try install(
            name: name,
            macro: MathParser.UserMacro(parameterCount: paramCount, replacement: body),
            parser: &parser,
            mode: .renew
        )
    }

    private static func install(
        name: String,
        macro: MathParser.UserMacro,
        parser: inout MathParser,
        mode: DefineMode
    ) throws {
        precondition(!name.isEmpty)
        let exists = parser.userMacros[name] != nil
        switch mode {
        case .new:
            if exists {
                throw ParseError(
                    code: .invalidCommand,
                    message: "\\newcommand{\\\(name)}: command already defined"
                )
            }
            parser.userMacros[name] = macro
        case .renew:
            parser.userMacros[name] = macro
        case .provide:
            if !exists {
                parser.userMacros[name] = macro
            }
        }
    }
}

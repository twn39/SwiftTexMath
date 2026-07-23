import Foundation

extension MathParser {
    enum AppendOutcome {
        case appended
        case infixFraction(hasRule: Bool, leftDelimiter: String, rightDelimiter: String)
    }

    @discardableResult
    mutating func appendCommand(
        into list: inout MathList,
        prev: inout MathAtom?,
        oneCharArgument: Bool = false
    ) throws -> AppendOutcome {
        let command = readCommandName()
        guard !command.isEmpty else {
            throw ParseError(code: .invalidCommand, message: "Missing command name")
        }

        switch try CommandHandlers.dispatch(
            command,
            parser: &self,
            list: &list,
            prev: &prev,
            oneCharArgument: oneCharArgument
        ) {
        case .handled:
            return .appended
        case .infixFraction(let hasRule, let left, let right):
            return .infixFraction(hasRule: hasRule, leftDelimiter: left, rightDelimiter: right)
        case .notHandled:
            break
        }

        if let accentNucleus = AtomFactory.accents[command] {
            let base = try readArgument()
            let atom = MathAtom(
                kind: .accent,
                nucleus: accentNucleus,
                payload: .accent(.init(accent: accentNucleus, base: base))
            )
            list.append(atom)
            prev = atom
            return .appended
        }

        guard let atom = AtomFactory.atom(forCommand: command) else {
            throw ParseError(code: .invalidCommand, message: "Unknown command \\\(command)")
        }
        list.append(atom)
        prev = atom
        return .appended
    }
}

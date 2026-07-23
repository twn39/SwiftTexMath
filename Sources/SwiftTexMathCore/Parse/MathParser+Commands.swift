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

        // `\accent{mark}{base}` / `\underaccent{mark}{base}` (accents package style).
        if command == "accent" || command == "underaccent" || command == "overaccent" {
            let mark = try readAccentMarkArgument()
            let base = try readArgument()
            let isBelow = command == "underaccent"
            let atom = Self.makeGeneralAccent(mark: mark, base: base, isBelow: isBelow)
            list.append(atom)
            prev = atom
            return .appended
        }

        if let accentNucleus = AtomFactory.accents[command] {
            let isBelow = AtomFactory.belowAccents.contains(command)
            // Stretch: `\wide*` above, and below marks that have horizontal variants / wide bases.
            let stretchable =
                command.hasPrefix("wide")
                || (isBelow && (command == "utilde" || command == "underbar" || command.contains("arrow")))
            // Bare accent name (no base): `\underaccent{\tilde}{x}` — next token is `}` or EOF.
            // Also accept an explicit empty group `\tilde{}` as a bare mark.
            if isBareAccentBaseAhead() {
                if peek() == "{" {
                    _ = try readArgument() // empty `{}`
                }
                let atom = MathAtom(
                    kind: .accent,
                    nucleus: accentNucleus,
                    payload: .accent(
                        .init(
                            accent: accentNucleus,
                            base: MathList(),
                            stretchable: stretchable,
                            isBelow: isBelow
                        )
                    )
                )
                list.append(atom)
                prev = atom
                return .appended
            }
            let base = try readArgument()
            let atom = MathAtom(
                kind: .accent,
                nucleus: accentNucleus,
                payload: .accent(
                    .init(
                        accent: accentNucleus,
                        base: base,
                        stretchable: stretchable,
                        isBelow: isBelow
                    )
                )
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

    /// Build an accent atom from a free-form mark list (`\underaccent{\ast}{x}`).
    private static func makeGeneralAccent(
        mark: MathList,
        base: MathList,
        isBelow: Bool
    ) -> MathAtom {
        // Prefer single-glyph path when the mark is one known accent command / character.
        if mark.atoms.count == 1, let only = mark.atoms.first {
            if case .accent(let nested) = only.payload {
                // Bare `\tilde` / `\tilde{}` as mark: reuse nucleus; outer forces above/below.
                return MathAtom(
                    kind: .accent,
                    nucleus: nested.accent,
                    payload: .accent(
                        .init(
                            accent: nested.accent,
                            base: base,
                            // Outer `\underaccent` forces below; wide* stays stretchable.
                            // `\tilde` under → stretch like utilde when the base is wide.
                            stretchable: nested.stretchable
                                || (isBelow && (nested.accent == "\u{0303}" || nested.accent == "\u{0330}")),
                            isBelow: isBelow,
                            mark: nil
                        )
                    )
                )
            }
            if !only.nucleus.isEmpty, only.superscript == nil, only.subscript == nil {
                let stretchable = AtomFactory.accents.first(where: {
                    $0.value == only.nucleus && $0.key.hasPrefix("wide")
                }) != nil
                    || (isBelow && (only.nucleus == "\u{0303}" || only.nucleus == "\u{0330}"))
                return MathAtom(
                    kind: .accent,
                    nucleus: only.nucleus,
                    payload: .accent(
                        .init(
                            accent: only.nucleus,
                            base: base,
                            stretchable: stretchable,
                            isBelow: isBelow,
                            mark: nil
                        )
                    )
                )
            }
        }
        let nucleus = mark.atoms.first?.nucleus ?? ""
        return MathAtom(
            kind: .accent,
            nucleus: nucleus,
            payload: .accent(
                .init(
                    accent: nucleus,
                    base: base,
                    stretchable: false,
                    isBelow: isBelow,
                    mark: mark
                )
            )
        )
    }
}

// MARK: - Accent mark argument helpers

extension MathParser {
    /// True when an accent command has no base: EOF, `}`, or empty `{}`.
    fileprivate mutating func isBareAccentBaseAhead() -> Bool {
        skipSpaces()
        guard hasCharacters else { return true }
        if peek() == "}" { return true }
        if peek() == "{" {
            // Look ahead for empty group `{}` / `{ }`.
            let saved = index
            _ = nextCharacter()
            skipSpaces()
            let empty = peek() == "}"
            index = saved
            return empty
        }
        return false
    }

    /// Mark argument for `\accent` / `\underaccent` / `\overaccent`.
    /// Bare accent commands (`{\tilde}`, `\tilde{}`) are accepted via `isBareAccentBaseAhead`.
    fileprivate mutating func readAccentMarkArgument() throws -> MathList {
        try readArgument()
    }
}

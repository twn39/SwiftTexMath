import Foundation

/// Convenience macros: `\operatorname`, `\pmod`, `\bra` / `\ket` / `\braket`.
enum MacroCommands {
    static func handleLeaf(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws -> Bool {
        switch command {
        case "operatorname":
            try appendOperatorName(parser: &parser, list: &list, prev: &prev, limits: false)
        case "operatorname*":
            try appendOperatorName(parser: &parser, list: &list, prev: &prev, limits: true)
        case "pmod":
            try appendPMod(parser: &parser, list: &list, prev: &prev)
        case "bra":
            try appendBraKet(
                parser: &parser,
                list: &list,
                prev: &prev,
                left: AtomFactory.boundaryNucleus(forDelimiter: "langle") ?? "\u{27E8}",
                right: AtomFactory.boundaryNucleus(forDelimiter: "|") ?? "|"
            )
        case "ket":
            try appendBraKet(
                parser: &parser,
                list: &list,
                prev: &prev,
                left: AtomFactory.boundaryNucleus(forDelimiter: "|") ?? "|",
                right: AtomFactory.boundaryNucleus(forDelimiter: "rangle") ?? "\u{27E9}"
            )
        case "braket":
            try appendBraket(parser: &parser, list: &list, prev: &prev)
        default:
            return false
        }
        return true
    }

    private static func appendOperatorName(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        limits: Bool
    ) throws {
        let contents = try parser.readArgument(allowSpaces: true)
        let name = contents.atoms.map(\.nucleus).joined()
        guard !name.isEmpty else {
            throw ParseError(code: .invalidCommand, message: "Missing operator name for \\operatorname")
        }
        let atom = MathAtom.largeOperator(name, limits: limits)
        list.append(atom)
        prev = atom
    }

    private static func appendPMod(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let argument = try parser.readArgument()
        var inner = MathList()
        if let modAtom = AtomFactory.atom(forCommand: "mod") {
            inner.append(modAtom)
        } else {
            inner.append(MathAtom.largeOperator("mod", limits: false))
        }
        inner.append(MathAtom.space(mu: 6))
        for atom in argument.atoms {
            inner.append(atom)
        }
        let atom = MathAtom(
            kind: .inner,
            payload: .inner(
                .init(
                    leftBoundary: AtomFactory.boundaryNucleus(forDelimiter: "(") ?? "(",
                    rightBoundary: AtomFactory.boundaryNucleus(forDelimiter: ")") ?? ")",
                    contents: inner
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func appendBraKet(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        left: String,
        right: String
    ) throws {
        let contents = try parser.readArgument()
        let atom = MathAtom(
            kind: .inner,
            payload: .inner(.init(leftBoundary: left, rightBoundary: right, contents: contents))
        )
        list.append(atom)
        prev = atom
    }

    private static func appendBraket(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let phi = try parser.readArgument()
        let psi = try parser.readArgument()
        var contents = MathList()
        for atom in phi.atoms { contents.append(atom) }
        contents.append(MathAtom.ordinary("|"))
        for atom in psi.atoms { contents.append(atom) }
        let atom = MathAtom(
            kind: .inner,
            payload: .inner(
                .init(
                    leftBoundary: AtomFactory.boundaryNucleus(forDelimiter: "langle") ?? "\u{27E8}",
                    rightBoundary: AtomFactory.boundaryNucleus(forDelimiter: "rangle") ?? "\u{27E9}",
                    contents: contents
                )
            )
        )
        list.append(atom)
        prev = atom
    }
}

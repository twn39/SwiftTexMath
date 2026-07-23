import Foundation

/// Convenience macros: `\operatorname`, `\pmod` / `\pod` / `\bmod`, `\bra` / `\ket` / `\braket`,
/// `\mathbin` / `\mathop` / `\mathrel`, `\tag`.
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
        case "pod":
            try appendPod(parser: &parser, list: &list, prev: &prev)
        case "bmod":
            try appendBMod(list: &list, prev: &prev)
        case "mathbin":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .binaryOperator)
        case "mathop":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .largeOperator, limits: true)
        case "mathrel":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .relation)
        case "mathord":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .ordinary)
        case "mathopen":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .open)
        case "mathclose":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .close)
        case "mathpunct":
            try appendMathClass(parser: &parser, list: &list, prev: &prev, kind: .punctuation)
        case "tag", "tag*":
            try appendTag(parser: &parser, list: &list, prev: &prev)
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
        let name = flattenOperatorName(contents)
        if name.isEmpty {
            // Complex body (e.g. `\operatorname{\underset{…}{median}}`): keep structure.
            if contents.atoms.count == 1, var atom = contents.atoms.first {
                if atom.kind == .ordinary || atom.kind == .variable {
                    atom.kind = .largeOperator
                    if case .none = atom.payload {
                        atom.payload = .largeOperator(limits: limits)
                    }
                }
                list.append(atom)
                prev = atom
            } else {
                for atom in contents.atoms {
                    list.append(atom)
                }
                prev = list.atoms.last
            }
            return
        }
        let atom = MathAtom.largeOperator(name, limits: limits)
        list.append(atom)
        prev = atom
    }

    /// Flatten simple text out of an `\operatorname` argument; empty if structure is non-textual.
    private static func flattenOperatorName(_ list: MathList) -> String {
        var result = ""
        for atom in list.atoms {
            switch atom.payload {
            case .none, .largeOperator, .space:
                result += atom.nucleus
            case .styled(let styled):
                let inner = flattenOperatorName(styled.contents)
                if inner.isEmpty { return "" }
                result += inner
            case .stack, .fraction, .radical, .inner, .accent, .overline, .underline,
                 .table, .colored, .mathChoice, .box, .style:
                return ""
            }
        }
        return result
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

    /// `\pod{n}` → `(n)` with leading thick space (amsmath).
    private static func appendPod(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let argument = try parser.readArgument()
        list.append(MathAtom.space(mu: 18))
        let atom = MathAtom(
            kind: .inner,
            payload: .inner(
                .init(
                    leftBoundary: AtomFactory.boundaryNucleus(forDelimiter: "(") ?? "(",
                    rightBoundary: AtomFactory.boundaryNucleus(forDelimiter: ")") ?? ")",
                    contents: argument
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    /// `\bmod` → `\;\mathrm{mod}\;` binary operator word.
    private static func appendBMod(list: inout MathList, prev: inout MathAtom?) throws {
        list.append(MathAtom.space(mu: 5))
        let atom = MathAtom(kind: .binaryOperator, nucleus: "mod")
        list.append(atom)
        list.append(MathAtom.space(mu: 5))
        prev = atom
    }

    private static func appendMathClass(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        kind: AtomKind,
        limits: Bool = false
    ) throws {
        let contents = try parser.readArgument()
        if contents.atoms.count == 1, let only = contents.atoms.first {
            var atom = only
            atom.kind = kind
            if kind == .largeOperator, case .none = atom.payload {
                atom.payload = .largeOperator(limits: limits)
            }
            list.append(atom)
            prev = atom
            return
        }
        let atom = MathAtom(
            kind: kind,
            nucleus: "",
            payload: .inner(.init(contents: contents))
        )
        if kind == .largeOperator {
            // Keep as inner-wrapped op via ordinary large-op nucleus from flattened text if possible.
            let flat = flattenOperatorName(contents)
            if !flat.isEmpty {
                let op = MathAtom.largeOperator(flat, limits: limits)
                list.append(op)
                prev = op
                return
            }
        }
        list.append(atom)
        prev = atom
    }

    /// `\tag{…}` / `\tag*{…}` — consume argument; emit a parenthesized tag for layout visibility.
    private static func appendTag(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let contents = try parser.readArgument(allowSpaces: true)
        list.append(MathAtom.space(mu: 18))
        var tagged = MathList()
        tagged.append(MathAtom.ordinary("("))
        for atom in contents.atoms {
            tagged.append(atom)
        }
        tagged.append(MathAtom.ordinary(")"))
        let atom = MathAtom(
            kind: .ordinary,
            payload: .styled(.init(variant: .upright, contents: tagged))
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

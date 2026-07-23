import Foundation

extension MacroCommands {
    static func appendPMod(
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
    static func appendPod(
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
    static func appendBMod(list: inout MathList, prev: inout MathAtom?) throws {
        list.append(MathAtom.space(mu: 5))
        let atom = MathAtom(kind: .binaryOperator, nucleus: "mod")
        list.append(atom)
        list.append(MathAtom.space(mu: 5))
        prev = atom
    }

    /// `\tag{…}` / `\tag*{…}` — consume argument; emit a parenthesized tag for layout visibility.
    static func appendTag(
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
}

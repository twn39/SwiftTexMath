import Foundation

extension MacroCommands {
    static func appendBraKet(
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

    static func appendBraket(
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

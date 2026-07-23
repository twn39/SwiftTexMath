import Foundation

extension MathParser {
    /// Attach one or more primes as a superscript on `prev` (iosMath / TeX `'`).
    mutating func appendPrimes(into list: inout MathList, prev: inout MathAtom?) throws {
        if prev == nil || prev?.superscript != nil || !(prev?.kind.allowsScripts ?? false) {
            let empty = MathAtom.ordinary("")
            list.append(empty)
            prev = empty
        }
        var primes = MathList(atoms: [MathAtom.ordinary("\u{2032}")])
        while peek() == "'" {
            _ = nextCharacter()
            primes.append(MathAtom.ordinary("\u{2032}"))
        }
        // Merge trailing ^: f'^2 → superscript = [′, 2]
        if peek() == "^" {
            _ = nextCharacter()
            let tail = try readScript()
            primes.atoms.append(contentsOf: tail.atoms)
        }
        var base = prev!
        base.superscript = primes
        list.atoms[list.atoms.count - 1] = base
        prev = base
    }

    mutating func readScript() throws -> MathList {
        skipSpaces()
        guard hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "Missing script")
        }
        if peek() == "{" {
            _ = nextCharacter()
            let list = try buildInternal(stop: .character("}"))
            guard hasCharacters, nextCharacter() == "}" else {
                throw ParseError(code: .mismatchedBraces, message: "Missing } after script")
            }
            return list
        }
        var list = MathList()
        var prev: MathAtom?
        try appendOneAtom(into: &list, prev: &prev)
        return list
    }

    mutating func appendOneAtom(into list: inout MathList, prev: inout MathAtom?) throws {
        guard hasCharacters else {
            throw ParseError(code: .unexpectedEnd, message: "Expected atom")
        }
        let ch = nextCharacter()
        if ch == "{" {
            let inner = try buildInternal(stop: .character("}"))
            guard hasCharacters, nextCharacter() == "}" else {
                throw ParseError(code: .mismatchedBraces, message: "Missing }")
            }
            if inner.atoms.count == 1, let only = inner.atoms.first {
                list.append(only)
                prev = only
            } else {
                let atom = MathAtom(kind: .inner, payload: .inner(.init(contents: inner)))
                list.append(atom)
                prev = atom
            }
            return
        }
        if ch == "\\" {
            try appendCommand(into: &list, prev: &prev, oneCharArgument: true)
            return
        }
        if ch == "'" {
            let atom = MathAtom.ordinary("\u{2032}")
            list.append(atom)
            prev = atom
            return
        }
        guard let atom = AtomFactory.atom(forCharacter: ch) else {
            throw ParseError(code: .characterNotFound, message: "Unexpected character \(ch)")
        }
        list.append(atom)
        prev = atom
    }
}

import Foundation

extension MacroCommands {
    static func appendOperatorName(
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
    static func flattenOperatorName(_ list: MathList) -> String {
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

    static func appendMathClass(
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
}

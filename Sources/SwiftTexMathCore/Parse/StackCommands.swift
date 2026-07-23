import Foundation

/// Overset / underset / stretchy stack / substack command handlers.
enum StackCommands {
    /// Stretchy over/under constructions with a single base argument.
    static let stretchyStacks: [String: (over: String?, under: String?)] = [
        "overrightarrow": ("\u{2192}", nil),
        "overleftarrow": ("\u{2190}", nil),
        "overleftrightarrow": ("\u{2194}", nil),
        "underrightarrow": (nil, "\u{2192}"),
        "underleftarrow": (nil, "\u{2190}"),
        "underleftrightarrow": (nil, "\u{2194}"),
        "overbrace": ("\u{23DE}", nil),
        "underbrace": (nil, "\u{23DF}")
    ]

    private enum StackRole { case over, under }

    static func handleLeaf(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws -> Bool {
        switch command {
        case "overset":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .ordinary, inherit: true)
        case "underset":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .under, kind: .ordinary, inherit: true)
        case "stackrel":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .relation, inherit: false)
        case "stackbin":
            try appendStack(parser: &parser, list: &list, prev: &prev, role: .over, kind: .binaryOperator, inherit: false)
        case "substack":
            try appendSubstack(parser: &parser, list: &list, prev: &prev)
        default:
            return false
        }
        return true
    }

    static func appendStretchyStack(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        over: String?,
        under: String?
    ) throws {
        let base = try parser.readArgument()
        let atom = MathAtom(
            kind: .ordinary,
            payload: .stack(
                .init(
                    base: base,
                    displayKind: .ordinary,
                    overNucleus: over,
                    underNucleus: under
                )
            )
        )
        list.append(atom)
        prev = atom
    }

    private static func appendStack(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        role: StackRole,
        kind: AtomKind,
        inherit: Bool
    ) throws {
        let first = try parser.readArgument()
        let base = try parser.readArgument()
        var displayKind = kind
        if inherit, base.atoms.count == 1, let only = base.atoms.first {
            if only.kind == .binaryOperator || only.kind == .relation {
                displayKind = only.kind
            }
        }
        let stack: MathAtom.Stack
        switch role {
        case .over:
            stack = .init(base: base, over: first, displayKind: displayKind)
        case .under:
            stack = .init(base: base, under: first, displayKind: displayKind)
        }
        let atom = MathAtom(kind: displayKind, payload: .stack(stack))
        list.append(atom)
        prev = atom
    }

    private static func appendSubstack(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let table = try parser.parseSubstack()
        let atom = MathAtom(kind: .table, payload: .table(table))
        list.append(atom)
        prev = atom
    }
}

import Foundation

/// Convenience macros dispatcher: `\operatorname`, `\pmod` / `\pod` / `\bmod`,
/// `\bra` / `\ket` / `\braket`, `\mathbin` / `\mathop` / `\mathrel`, `\tag`.
///
/// Implementations live in family extensions (`+OperatorName`, `+BraKet`, `+ModTag`).
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
}

import CoreGraphics
import Foundation

/// Structural LaTeX command dispatcher — catalogs + family modules + fence/env switch.
enum CommandHandlers {
    enum Result {
        case notHandled
        case handled
        /// `\over` / `\atop` / `\choose` / … — replace current list with a fraction.
        case infixFraction(hasRule: Bool, leftDelimiter: String, rightDelimiter: String)
    }

    /// Compatibility aliases for catalogs now owned by family modules.
    static var delimiterSizeMultipliers: [String: CGFloat] { DelimiterCommands.sizeMultipliers }
    static var styleVariants: [String: (MathVariant, Bool)] { StyleCommands.styleVariants }

    static func dispatch(
        _ command: String,
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?,
        oneCharArgument: Bool = false
    ) throws -> Result {
        if let multiplier = DelimiterCommands.sizeMultipliers[command] {
            try DelimiterCommands.appendSizedDelimiter(
                parser: &parser,
                list: &list,
                prev: &prev,
                command: command,
                multiplier: multiplier
            )
            return .handled
        }

        if let (variant, allowSpaces) = StyleCommands.styleVariants[command] {
            try StyleCommands.appendStyled(
                parser: &parser,
                list: &list,
                prev: &prev,
                variant: variant,
                allowSpaces: allowSpaces
            )
            return .handled
        }

        if let frac = FractionCommands.infixFractions[command] {
            if oneCharArgument {
                throw ParseError(
                    code: .invalidCommand,
                    message: "\\\(command) cannot be used in a one-character argument; wrap it in braces"
                )
            }
            return .infixFraction(hasRule: frac.hasRule, leftDelimiter: frac.left, rightDelimiter: frac.right)
        }

        if let allowEm = BoxCommands.spacingCommands[command] {
            try BoxCommands.appendKern(
                parser: &parser,
                list: &list,
                prev: &prev,
                command: command,
                allowEm: allowEm
            )
            return .handled
        }

        if let boxSpec = BoxCommands.boxCommands[command] {
            try BoxCommands.appendBox(parser: &parser, list: &list, prev: &prev, spec: boxSpec)
            return .handled
        }

        if let stretch = StackCommands.stretchyStacks[command] {
            try StackCommands.appendStretchyStack(
                parser: &parser,
                list: &list,
                prev: &prev,
                over: stretch.over,
                under: stretch.under
            )
            return .handled
        }

        // Leaf command families (table-driven catalogs above; switch-based leaves here).
        if try FractionCommands.handleLeaf(command, parser: &parser, list: &list, prev: &prev)
            || StyleCommands.handleLeaf(command, parser: &parser, list: &list, prev: &prev)
            || StackCommands.handleLeaf(command, parser: &parser, list: &list, prev: &prev)
            || MacroCommands.handleLeaf(command, parser: &parser, list: &list, prev: &prev) {
            return .handled
        }

        // Structural commands stay in an explicit switch (not leaf-registered).
        switch command {
        case "left":
            try DelimiterCommands.appendLeftRight(parser: &parser, list: &list, prev: &prev)
        case "right":
            throw ParseError(code: .missingLeft, message: "Missing \\left")
        case "middle":
            try DelimiterCommands.appendMiddle(parser: &parser, list: &list, prev: &prev)
        case "begin":
            try EnvironmentCommands.appendBegin(parser: &parser, list: &list, prev: &prev)
        case "end":
            throw ParseError(code: .missingBegin, message: "Unexpected \\end")
        case "limits", "nolimits":
            try EnvironmentCommands.applyLimits(command: command, list: &list, prev: &prev)
        default:
            return .notHandled
        }
        return .handled
    }
}

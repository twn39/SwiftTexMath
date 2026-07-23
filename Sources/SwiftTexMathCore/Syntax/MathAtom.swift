import CoreGraphics
import Foundation

/// Immutable math atom (TeX noad). Nested content lives in associated payloads.
public struct MathAtom: Sendable, Hashable {
    public var kind: AtomKind
    public var nucleus: String
    public var superscript: MathList?
    public var `subscript`: MathList?
    public var payload: Payload

    public indirect enum Payload: Sendable, Hashable {
        case none
        case largeOperator(limits: Bool)
        case fraction(Fraction)
        case radical(Radical)
        case inner(Inner)
        case space(mu: CGFloat)
        case style(MathStyle)
        case accent(Accent)
        case overline(MathList)
        case underline(MathList)
        case table(Table)
        case styled(Styled)
        case colored(Colored)
        case mathChoice(MathChoice)
        case box(Box)
        case stack(Stack)
    }

    /// Phantom / smash / lap / cancel family (iosMath `MTMathBox`).
    public struct Box: Sendable, Hashable {
        public var contents: MathList
        public var keepWidth: Bool
        public var keepHeight: Bool
        public var keepDepth: Bool
        public var drawChild: Bool
        public var hAlign: HAlign
        public var strike: StrikeStyle

        public enum HAlign: Sendable, Hashable {
            case left, center, right
        }

        public enum StrikeStyle: Sendable, Hashable {
            case none
            case forward
            case backward
            case cross
            case horizontal
        }

        public init(
            contents: MathList,
            keepWidth: Bool = true,
            keepHeight: Bool = true,
            keepDepth: Bool = true,
            drawChild: Bool = true,
            hAlign: HAlign = .left,
            strike: StrikeStyle = .none
        ) {
            self.contents = contents
            self.keepWidth = keepWidth
            self.keepHeight = keepHeight
            self.keepDepth = keepDepth
            self.drawChild = drawChild
            self.hAlign = hAlign
            self.strike = strike
        }
    }

    /// `\overset` / `\underset` / `\stackrel` / stretchy over/under arrows & braces.
    public struct Stack: Sendable, Hashable {
        public var base: MathList
        public var over: MathList?
        public var under: MathList?
        /// Spacing class after layout (relation for `\stackrel`, bin for `\stackbin`).
        public var displayKind: AtomKind
        /// Optional MATH-stretchable nucleus above the base (`\overrightarrow`, `\overbrace`).
        public var overNucleus: String?
        /// Optional MATH-stretchable nucleus below the base.
        public var underNucleus: String?

        public init(
            base: MathList,
            over: MathList? = nil,
            under: MathList? = nil,
            displayKind: AtomKind = .ordinary,
            overNucleus: String? = nil,
            underNucleus: String? = nil
        ) {
            self.base = base
            self.over = over
            self.under = under
            self.displayKind = displayKind
            self.overNucleus = overNucleus
            self.underNucleus = underNucleus
        }
    }

    public struct Fraction: Sendable, Hashable {
        public var numerator: MathList
        public var denominator: MathList
        public var hasRule: Bool
        public var leftDelimiter: String
        public var rightDelimiter: String
        /// When set, overrides the surrounding style for this fraction (`\dfrac` / `\tfrac`).
        public var forcedStyle: MathStyle?

        public init(
            numerator: MathList,
            denominator: MathList,
            hasRule: Bool = true,
            leftDelimiter: String = "",
            rightDelimiter: String = "",
            forcedStyle: MathStyle? = nil
        ) {
            self.numerator = numerator
            self.denominator = denominator
            self.hasRule = hasRule
            self.leftDelimiter = leftDelimiter
            self.rightDelimiter = rightDelimiter
            self.forcedStyle = forcedStyle
        }
    }

    public struct Styled: Sendable, Hashable {
        public var variant: MathVariant
        public var contents: MathList

        public init(variant: MathVariant, contents: MathList) {
            self.variant = variant
            self.contents = contents
        }
    }

    public struct Radical: Sendable, Hashable {
        public var degree: MathList?
        public var radicand: MathList

        public init(degree: MathList? = nil, radicand: MathList) {
            self.degree = degree
            self.radicand = radicand
        }
    }

    public struct Inner: Sendable, Hashable {
        /// Delimiter nucleus (empty means no delimiter).
        public var leftBoundary: String
        public var rightBoundary: String
        public var contents: MathList
        /// When set (from `\big`/`\Big`/…), multiplier × font size is the delimiter height.
        public var delimiterHeight: CGFloat?

        public init(
            leftBoundary: String = "",
            rightBoundary: String = "",
            contents: MathList,
            delimiterHeight: CGFloat? = nil
        ) {
            self.leftBoundary = leftBoundary
            self.rightBoundary = rightBoundary
            self.contents = contents
            self.delimiterHeight = delimiterHeight
        }
    }

    public struct Colored: Sendable, Hashable {
        /// Named color or `#RGB` / `#RRGGBB`.
        public var color: String
        public var contents: MathList
        /// `true` for `\colorbox` (background fill); `false` for `\color` / `\textcolor`.
        public var fillsBackground: Bool

        public init(color: String, contents: MathList, fillsBackground: Bool = false) {
            self.color = color
            self.contents = contents
            self.fillsBackground = fillsBackground
        }
    }

    public struct MathChoice: Sendable, Hashable {
        public var display: MathList
        public var text: MathList
        public var script: MathList
        public var scriptScript: MathList

        public init(display: MathList, text: MathList, script: MathList, scriptScript: MathList) {
            self.display = display
            self.text = text
            self.script = script
            self.scriptScript = scriptScript
        }

        public func list(for style: MathStyle) -> MathList {
            switch style {
            case .display: return display
            case .text: return text
            case .script: return script
            case .scriptScript: return scriptScript
            }
        }
    }

    public struct Accent: Sendable, Hashable {
        public var accent: String
        public var base: MathList

        public init(accent: String, base: MathList) {
            self.accent = accent
            self.base = base
        }
    }

    public struct Table: Sendable, Hashable {
        public var environment: String
        public var rows: [[MathList]]
        public var alignments: [ColumnAlignment]
        /// Inter-column gap in math units (mu).
        public var interColumnSpacing: CGFloat
        /// Extra row gap multiplier (0 = tight matrix; 1 ≈ one line of leading).
        public var interRowAdditionalSpacing: CGFloat
        /// Vertical rule counts before column `i` (length = columnCount + 1; last = after final column).
        public var vlines: [Int]
        /// Horizontal rule counts at each row boundary (length = rowCount + 1; `\hline` in `array`).
        public var hlines: [Int]

        public enum ColumnAlignment: Sendable, Hashable {
            case left, center, right
        }

        public init(
            environment: String,
            rows: [[MathList]],
            alignments: [ColumnAlignment] = [],
            interColumnSpacing: CGFloat = 18,
            interRowAdditionalSpacing: CGFloat = 0,
            vlines: [Int] = [],
            hlines: [Int] = []
        ) {
            self.environment = environment
            self.rows = rows
            self.alignments = alignments
            self.interColumnSpacing = interColumnSpacing
            self.interRowAdditionalSpacing = interRowAdditionalSpacing
            self.vlines = vlines
            self.hlines = hlines
        }
    }

    public init(
        kind: AtomKind,
        nucleus: String = "",
        superscript: MathList? = nil,
        subscript: MathList? = nil,
        payload: Payload = .none
    ) {
        self.kind = kind
        self.nucleus = nucleus
        self.superscript = superscript
        self.subscript = `subscript`
        self.payload = payload
    }

    public static func ordinary(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .ordinary, nucleus: nucleus)
    }

    public static func number(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .number, nucleus: nucleus)
    }

    public static func variable(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .variable, nucleus: nucleus)
    }

    public static func binaryOperator(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .binaryOperator, nucleus: nucleus)
    }

    public static func relation(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .relation, nucleus: nucleus)
    }

    public static func open(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .open, nucleus: nucleus)
    }

    public static func close(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .close, nucleus: nucleus)
    }

    public static func punctuation(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .punctuation, nucleus: nucleus)
    }

    public static func boundary(_ nucleus: String) -> MathAtom {
        MathAtom(kind: .boundary, nucleus: nucleus)
    }

    public static func space(mu: CGFloat) -> MathAtom {
        MathAtom(kind: .space, payload: .space(mu: mu))
    }

    public static func style(_ style: MathStyle) -> MathAtom {
        MathAtom(kind: .style, payload: .style(style))
    }

    public static func largeOperator(_ nucleus: String, limits: Bool) -> MathAtom {
        MathAtom(kind: .largeOperator, nucleus: nucleus, payload: .largeOperator(limits: limits))
    }

    public var limits: Bool {
        if case .largeOperator(let limits) = payload { return limits }
        return false
    }
}

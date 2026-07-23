import CoreGraphics
import Foundation

/// Immutable display tree produced by the typesetter (TeX boxes).
public struct DisplayList: Sendable, Hashable {
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint
    public var children: [DisplayNode]

    public init(
        ascent: CGFloat = 0,
        descent: CGFloat = 0,
        width: CGFloat = 0,
        position: CGPoint = .zero,
        children: [DisplayNode] = []
    ) {
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
        self.children = children
    }

    public var size: CGSize {
        CGSize(width: width, height: ascent + descent)
    }

    public var bounds: CGRect {
        CGRect(x: position.x, y: position.y - descent, width: width, height: ascent + descent)
    }
}

public enum DisplayNode: Sendable, Hashable {
    case list(DisplayList)
    case glyphs(GlyphRun)
    case fraction(FractionDisplay)
    case radical(RadicalDisplay)
    case line(LineDisplay)
    case largeOperator(LargeOperatorDisplay)
    case colored(ColoredDisplay)
    case rule(RuleDisplay)
    case box(BoxDisplay)
    case stack(StackDisplay)

    public var ascent: CGFloat {
        switch self {
        case .list(let n): return n.ascent
        case .glyphs(let n): return n.ascent
        case .fraction(let n): return n.ascent
        case .radical(let n): return n.ascent
        case .line(let n): return n.ascent
        case .largeOperator(let n): return n.ascent
        case .colored(let n): return n.ascent
        case .rule(let n): return n.ascent
        case .box(let n): return n.ascent
        case .stack(let n): return n.ascent
        }
    }

    public var descent: CGFloat {
        switch self {
        case .list(let n): return n.descent
        case .glyphs(let n): return n.descent
        case .fraction(let n): return n.descent
        case .radical(let n): return n.descent
        case .line(let n): return n.descent
        case .largeOperator(let n): return n.descent
        case .colored(let n): return n.descent
        case .rule(let n): return n.descent
        case .box(let n): return n.descent
        case .stack(let n): return n.descent
        }
    }

    public var width: CGFloat {
        switch self {
        case .list(let n): return n.width
        case .glyphs(let n): return n.width
        case .fraction(let n): return n.width
        case .radical(let n): return n.width
        case .line(let n): return n.width
        case .largeOperator(let n): return n.width
        case .colored(let n): return n.width
        case .rule(let n): return n.width
        case .box(let n): return n.width
        case .stack(let n): return n.width
        }
    }

    public var position: CGPoint {
        get {
            switch self {
            case .list(let n): return n.position
            case .glyphs(let n): return n.position
            case .fraction(let n): return n.position
            case .radical(let n): return n.position
            case .line(let n): return n.position
            case .largeOperator(let n): return n.position
            case .colored(let n): return n.position
            case .rule(let n): return n.position
            case .box(let n): return n.position
            case .stack(let n): return n.position
            }
        }
        set {
            switch self {
            case .list(var n):
                n.position = newValue
                self = .list(n)
            case .glyphs(var n):
                n.position = newValue
                self = .glyphs(n)
            case .fraction(var n):
                n.position = newValue
                self = .fraction(n)
            case .radical(var n):
                n.position = newValue
                self = .radical(n)
            case .line(var n):
                n.position = newValue
                self = .line(n)
            case .largeOperator(var n):
                n.position = newValue
                self = .largeOperator(n)
            case .colored(var n):
                n.position = newValue
                self = .colored(n)
            case .rule(var n):
                n.position = newValue
                self = .rule(n)
            case .box(var n):
                n.position = newValue
                self = .box(n)
            case .stack(var n):
                n.position = newValue
                self = .stack(n)
            }
        }
    }
}

public struct GlyphRun: Sendable, Hashable {
    public var text: String
    public var font: MathFont
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint
    /// Explicit glyph IDs for variants / assemblies. Empty → derive from `text`.
    public var glyphIDs: [UInt16]
    /// Per-glyph y offsets for vertical assembly (same count as `glyphIDs`, or empty).
    public var glyphOffsetsY: [CGFloat]
    /// Shift the run down (positive) so a tall delimiter centers on the math axis.
    public var shiftDown: CGFloat
    /// Italic correction of the (last) glyph; used when attaching superscripts.
    public var italicCorrection: CGFloat
    /// PostScript / font name for CJK / missing-glyph fallback (nil = math font / system UI).
    public var fallbackFontName: String?
    /// When true and `fallbackFontName` is nil, draw with the platform UI font.
    public var usesSystemFallback: Bool

    public init(
        text: String,
        font: MathFont,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero,
        glyphIDs: [UInt16] = [],
        glyphOffsetsY: [CGFloat] = [],
        shiftDown: CGFloat = 0,
        italicCorrection: CGFloat = 0,
        fallbackFontName: String? = nil,
        usesSystemFallback: Bool = false
    ) {
        self.text = text
        self.font = font
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
        self.glyphIDs = glyphIDs
        self.glyphOffsetsY = glyphOffsetsY
        self.shiftDown = shiftDown
        self.italicCorrection = italicCorrection
        self.fallbackFontName = fallbackFontName
        self.usesSystemFallback = usesSystemFallback
    }

    static func from(
        sized: SizedGlyph,
        text: String,
        font: MathFont,
        metrics: FontMetrics,
        centerOnAxis: Bool
    ) -> GlyphRun {
        let italic: CGFloat
        if let last = sized.glyphIDs.last {
            italic = metrics.italicCorrection(for: last)
        } else {
            italic = metrics.italicCorrection(forNucleus: text)
        }
        let shift: CGFloat
        if centerOnAxis {
            shift = 0.5 * (sized.ascent - sized.descent) - metrics.axisHeight
        } else {
            shift = 0
        }
        return GlyphRun(
            text: text,
            font: font,
            ascent: sized.ascent,
            descent: sized.descent,
            width: sized.width,
            glyphIDs: sized.glyphIDs.map { UInt16($0) },
            glyphOffsetsY: sized.offsetsY,
            shiftDown: shift,
            italicCorrection: italic
        )
    }
}

public struct FractionDisplay: Sendable, Hashable {
    public var numerator: DisplayList
    public var denominator: DisplayList
    public var ruleThickness: CGFloat
    public var numeratorOffset: CGFloat
    public var denominatorOffset: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        numerator: DisplayList,
        denominator: DisplayList,
        ruleThickness: CGFloat,
        numeratorOffset: CGFloat,
        denominatorOffset: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.numerator = numerator
        self.denominator = denominator
        self.ruleThickness = ruleThickness
        self.numeratorOffset = numeratorOffset
        self.denominatorOffset = denominatorOffset
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

public struct RadicalDisplay: Sendable, Hashable {
    public var radicand: DisplayList
    public var degree: DisplayList?
    public var radicalGlyph: GlyphRun
    public var ruleThickness: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        radicand: DisplayList,
        degree: DisplayList?,
        radicalGlyph: GlyphRun,
        ruleThickness: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.radicand = radicand
        self.degree = degree
        self.radicalGlyph = radicalGlyph
        self.ruleThickness = ruleThickness
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

public struct LineDisplay: Sendable, Hashable {
    public var inner: DisplayList
    public var isOverline: Bool
    public var ruleThickness: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        inner: DisplayList,
        isOverline: Bool,
        ruleThickness: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.inner = inner
        self.isOverline = isOverline
        self.ruleThickness = ruleThickness
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

public struct LargeOperatorDisplay: Sendable, Hashable {
    public var nucleus: GlyphRun
    public var upperLimit: DisplayList?
    public var lowerLimit: DisplayList?
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        nucleus: GlyphRun,
        upperLimit: DisplayList?,
        lowerLimit: DisplayList?,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.nucleus = nucleus
        self.upperLimit = upperLimit
        self.lowerLimit = lowerLimit
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

/// Display subtree drawn with an explicit color (`\color` foreground or `\colorbox` background).
public struct ColoredDisplay: Sendable, Hashable {
    public var inner: DisplayList
    /// sRGB components 0…1.
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat
    /// When `true`, fill the inner bounds with this color and draw children in the ambient foreground.
    public var fillsBackground: Bool
    public var position: CGPoint

    public var ascent: CGFloat { inner.ascent }
    public var descent: CGFloat { inner.descent }
    public var width: CGFloat { inner.width }

    public init(
        inner: DisplayList,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1,
        fillsBackground: Bool = false,
        position: CGPoint = .zero
    ) {
        self.inner = inner
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
        self.fillsBackground = fillsBackground
        self.position = position
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

/// Thin horizontal or vertical rule (table `|` column specs, etc.).
public struct RuleDisplay: Sendable, Hashable {
    public var thickness: CGFloat
    public var isVertical: Bool
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        thickness: CGFloat,
        isVertical: Bool,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.thickness = thickness
        self.isVertical = isVertical
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

/// Phantom / smash / lap / cancel display (iosMath `MTMathBoxDisplay`).
public struct BoxDisplay: Sendable, Hashable {
    public var child: DisplayList
    public var keepWidth: Bool
    public var drawChild: Bool
    public var hAlign: MathAtom.Box.HAlign
    public var strike: MathAtom.Box.StrikeStyle
    public var strikeThickness: CGFloat
    public var strikeVerticalOffset: CGFloat
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        child: DisplayList,
        keepWidth: Bool,
        keepHeight: Bool,
        keepDepth: Bool,
        drawChild: Bool,
        hAlign: MathAtom.Box.HAlign,
        strike: MathAtom.Box.StrikeStyle,
        strikeThickness: CGFloat,
        strikeVerticalOffset: CGFloat,
        position: CGPoint = .zero
    ) {
        self.child = child
        self.keepWidth = keepWidth
        self.drawChild = drawChild
        self.hAlign = hAlign
        self.strike = strike
        self.strikeThickness = strikeThickness
        self.strikeVerticalOffset = strikeVerticalOffset
        self.ascent = keepHeight ? child.ascent : 0
        self.descent = keepDepth ? child.descent : 0
        self.width = keepWidth ? child.width : 0
        self.position = position
    }

    /// Child x offset relative to the box origin (laps).
    public var childOffsetX: CGFloat {
        guard !keepWidth else { return 0 }
        switch hAlign {
        case .right: return -child.width
        case .center: return -child.width / 2
        case .left: return 0
        }
    }
}

/// Over/under stack (`\overset`, `\overbrace`, …).
public struct StackDisplay: Sendable, Hashable {
    public var base: DisplayList
    public var over: DisplayList?
    public var under: DisplayList?
    public var ascent: CGFloat
    public var descent: CGFloat
    public var width: CGFloat
    public var position: CGPoint

    public init(
        base: DisplayList,
        over: DisplayList?,
        under: DisplayList?,
        ascent: CGFloat,
        descent: CGFloat,
        width: CGFloat,
        position: CGPoint = .zero
    ) {
        self.base = base
        self.over = over
        self.under = under
        self.ascent = ascent
        self.descent = descent
        self.width = width
        self.position = position
    }
}

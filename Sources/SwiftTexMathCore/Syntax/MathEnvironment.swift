import CoreGraphics
import Foundation

/// Configurable TeX-style math parameters (defaults match classic TeX / iosMath).
public struct MathParameters: Sendable, Hashable {
    public var thinMuskip: CGFloat
    public var medMuskip: CGFloat
    public var thickMuskip: CGFloat
    public var delimiterFactor: CGFloat
    public var delimiterShortfall: CGFloat
    /// Penalty for breaking line at a relation symbol (TeX default = 500).
    public var relpenalty: Int
    /// Penalty for breaking line at a binary operator (TeX default = 700).
    public var binoppenalty: Int

    public init(
        thinMuskip: CGFloat = 3,
        medMuskip: CGFloat = 4,
        thickMuskip: CGFloat = 5,
        delimiterFactor: CGFloat = 901,
        delimiterShortfall: CGFloat = 5,
        relpenalty: Int = 500,
        binoppenalty: Int = 700
    ) {
        self.thinMuskip = thinMuskip
        self.medMuskip = medMuskip
        self.thickMuskip = thickMuskip
        self.delimiterFactor = delimiterFactor
        self.delimiterShortfall = delimiterShortfall
        self.relpenalty = relpenalty
        self.binoppenalty = binoppenalty
    }

    public static let `default` = MathParameters()
}

/// Layout environment passed to the typesetter.
public struct MathEnvironment: Sendable, Hashable {
    public var font: MathFont
    public var style: MathStyle
    public var cramped: Bool
    public var parameters: MathParameters
    public var maxWidth: CGFloat
    public var variant: MathVariant
    /// Optional text fallback font (PostScript name) for glyphs missing from the math font (CJK, emoji).
    /// When nil, a platform UI font is used as last resort for missing glyphs.
    public var textFallbackFontName: String?
    /// Maximum allowed recursion depth during layout and parsing to guard against stack overflow.
    public var maxRecursionDepth: Int

    public init(
        font: MathFont = MathFont(name: .latinModern, size: 20),
        style: MathStyle = .display,
        cramped: Bool = false,
        parameters: MathParameters = .default,
        maxWidth: CGFloat = 0,
        variant: MathVariant = .italic,
        textFallbackFontName: String? = nil,
        maxRecursionDepth: Int = 128
    ) {
        self.font = font
        self.style = style
        self.cramped = cramped
        self.parameters = parameters
        self.maxWidth = maxWidth
        self.variant = variant
        self.textFallbackFontName = textFallbackFontName
        self.maxRecursionDepth = maxRecursionDepth
    }

    public func with(
        style: MathStyle? = nil,
        cramped: Bool? = nil,
        fontSize: CGFloat? = nil,
        variant: MathVariant? = nil
    ) -> MathEnvironment {
        var copy = self
        if let style { copy.style = style }
        if let cramped { copy.cramped = cramped }
        if let fontSize {
            copy.font = MathFont(name: font.name, size: fontSize)
        }
        if let variant { copy.variant = variant }
        return copy
    }

    public var styleFontSize: CGFloat {
        font.size * style.sizeMultiplier
    }
}

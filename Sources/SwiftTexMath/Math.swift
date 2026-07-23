import SwiftUI
import SwiftTexMathCore

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// SwiftUI view that renders a LaTeX math expression.
///
/// ```swift
/// Math("x = \\frac{-b \\pm \\sqrt{b^2-4ac}}{2a}")
///   .mathFont(MathFont(name: .latinModern, size: 24))
///   .mathTypesettingStyle(.display)
/// ```
public struct Math: View {
    @Environment(\.mathFont) private var font
    @Environment(\.mathTypesettingStyle) private var typesettingStyle
    @Environment(\.mathRenderingMode) private var renderingMode
    @Environment(\.mathFonts) private var fonts
    @Environment(\.mathTextFallbackFontName) private var textFallbackFontName

    private let latex: String

    public init(_ latex: String) {
        self.latex = latex
    }

    public var body: some View {
        MathProposalLayout(
            latex: latex,
            font: font,
            style: typesettingStyle,
            fonts: fonts,
            textFallbackFontName: textFallbackFontName
        ) {
            Canvas { context, size in
                switch DisplayProvider.display(
                    for: latex,
                    font: font,
                    style: typesettingStyle,
                    proposedWidth: size.width,
                    fonts: fonts,
                    textFallbackFontName: textFallbackFontName
                ) {
                case .success(let display):
                    let color: Color = {
                        switch renderingMode {
                        case .monochrome:
                            return .primary
                        case .multicolor(let base):
                            return base
                        }
                    }()
                    context.draw(
                        display,
                        in: CGRect(origin: .zero, size: size),
                        color: color,
                        fonts: fonts
                    )
                case .failure(let error):
                    context.draw(
                        Text(error.message.isEmpty ? "?\(error.code.rawValue)" : error.message),
                        at: CGPoint(x: size.width / 2, y: size.height / 2),
                        anchor: .center
                    )
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(latex.isEmpty ? "Empty math" : latex))
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Feeds the parent's proposed width into Core typesetting so `maxWidth` wrapping works.
///
/// Reports ``VerticalAlignment/firstTextBaseline`` / ``lastTextBaseline`` from the
/// TeX box metrics (`ascent` from the top) so inline math aligns with surrounding `Text`.
private struct MathProposalLayout: Layout {
    struct Cache {
        var width: CGFloat = 1
        var height: CGFloat = 1
        /// Distance from the top of the math box to the math baseline (TeX ascent).
        var ascent: CGFloat = 0
        /// Distance from the math baseline to the bottom of the box (TeX descent).
        var descent: CGFloat = 0
        var measuredWidth: CGFloat?
    }

    let latex: String
    let font: MathFont
    let style: TypesettingStyle
    let fonts: any FontProviding
    let textFallbackFontName: String?

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        updateCache(proposedWidth: proposal.width, cache: &cache)
        return CGSize(width: cache.width, height: cache.height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        updateCache(proposedWidth: proposal.width, cache: &cache)
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGFloat? {
        updateCache(proposedWidth: proposal.width, cache: &cache)
        // Prefer metrics from the laid-out height when the parent stretches us.
        let ascent: CGFloat
        if cache.height > 0.5, bounds.height > 0.5, abs(bounds.height - cache.height) > 0.5 {
            // Scale ascent if bounds differ from natural size (uncommon for fixedSize math).
            ascent = cache.ascent * (bounds.height / cache.height)
        } else {
            ascent = cache.ascent
        }
        switch guide {
        case .firstTextBaseline:
            return bounds.minY + ascent
        case .lastTextBaseline:
            // Single TeX box: one reference baseline; multi-line wrap still uses outer metrics.
            return bounds.minY + ascent
        default:
            return nil
        }
    }

    private func updateCache(proposedWidth: CGFloat?, cache: inout Cache) {
        let width: CGFloat
        if let proposedWidth, proposedWidth.isFinite, proposedWidth > 0 {
            width = proposedWidth
        } else {
            width = 0
        }
        if cache.measuredWidth == width, cache.height > 0.5 {
            return
        }
        cache.measuredWidth = width
        switch DisplayProvider.display(
            for: latex,
            font: font,
            style: style,
            proposedWidth: width,
            fonts: fonts,
            textFallbackFontName: textFallbackFontName
        ) {
        case .success(let display):
            let ascent = max(display.ascent, 0)
            let descent = max(display.descent, 0)
            cache.ascent = ascent
            cache.descent = descent
            cache.width = max(display.width, 1)
            cache.height = max(ascent + descent, 1)
        case .failure:
            // Keep a readable error footprint for layout; approximate body baseline.
            let fallbackAscent = max(font.size * 0.8, 12)
            cache.ascent = fallbackAscent
            cache.descent = max(font.size * 0.2, 4)
            cache.width = 120
            cache.height = 24
        }
    }
}

extension GraphicsContext {
    fileprivate func draw(
        _ display: DisplayList,
        in rect: CGRect,
        color: Color,
        fonts: any FontProviding
    ) {
        withCGContext { cg in
            cg.saveGState()
            // SwiftUI Canvas is y-down; math display is y-up with baseline origin.
            cg.translateBy(x: rect.minX, y: rect.minY + display.ascent)
            cg.scaleBy(x: 1, y: -1)
            let cgColor = color.resolveCGColor()
            cg.draw(display, at: .zero, foregroundColor: cgColor, fonts: fonts)
            cg.restoreGState()
        }
    }
}

extension Color {
    fileprivate func resolveCGColor() -> CGColor {
        #if canImport(UIKit)
        return UIColor(self).cgColor
        #elseif canImport(AppKit)
        return NSColor(self).cgColor
        #else
        return CGColor(gray: 0, alpha: 1)
        #endif
    }
}

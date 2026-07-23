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
private struct MathProposalLayout: Layout {
    let latex: String
    let font: MathFont
    let style: TypesettingStyle
    let fonts: any FontProviding
    let textFallbackFontName: String?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        measure(proposedWidth: proposal.width)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }
        subview.place(
            at: bounds.origin,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }

    private func measure(proposedWidth: CGFloat?) -> CGSize {
        let width: CGFloat
        if let proposedWidth, proposedWidth.isFinite, proposedWidth > 0 {
            width = proposedWidth
        } else {
            width = 0
        }
        switch DisplayProvider.display(
            for: latex,
            font: font,
            style: style,
            proposedWidth: width,
            fonts: fonts,
            textFallbackFontName: textFallbackFontName
        ) {
        case .success(let display):
            return CGSize(
                width: max(display.width, 1),
                height: max(display.ascent + display.descent, 1)
            )
        case .failure:
            // Keep a readable error footprint for layout.
            return CGSize(width: 120, height: 24)
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

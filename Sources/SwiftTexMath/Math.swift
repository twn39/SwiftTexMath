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

    private let latex: String

    public init(_ latex: String) {
        self.latex = latex
    }

    public var body: some View {
        MathProposalLayout(latex: latex, font: font, style: typesettingStyle) {
            Canvas { context, size in
                switch DisplayProvider.display(
                    for: latex,
                    font: font,
                    style: typesettingStyle,
                    proposedWidth: size.width
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
                        color: color
                    )
                case .failure(let error):
                    context.draw(
                        Text("?\(error.code.rawValue)"),
                        at: CGPoint(x: size.width / 2, y: size.height / 2),
                        anchor: .center
                    )
                }
            }
        }
    }
}

/// Feeds the parent's proposed width into Core typesetting so `maxWidth` wrapping works.
private struct MathProposalLayout: Layout {
    let latex: String
    let font: MathFont
    let style: TypesettingStyle

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
            proposedWidth: width
        ) {
        case .success(let display):
            return CGSize(
                width: max(display.width, 1),
                height: max(display.ascent + display.descent, 1)
            )
        case .failure:
            return CGSize(width: 24, height: 24)
        }
    }
}

extension GraphicsContext {
    fileprivate func draw(_ display: DisplayList, in rect: CGRect, color: Color) {
        withCGContext { cg in
            cg.saveGState()
            // SwiftUI Canvas is y-down; math display is y-up with baseline origin.
            cg.translateBy(x: rect.minX, y: rect.minY + display.ascent)
            cg.scaleBy(x: 1, y: -1)
            let cgColor = color.resolveCGColor()
            cg.draw(display, at: .zero, foregroundColor: cgColor)
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

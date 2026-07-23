import SwiftUI
import SwiftTexMathCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if (canImport(UIKit) && !os(watchOS)) || (canImport(AppKit) && !targetEnvironment(macCatalyst))

/// SwiftUI host that embeds UIKit/AppKit ``MathLabel`` (useful when you need AppKit/UIKit layout integration).
///
/// Prefer the pure-SwiftUI ``Math`` view for most cases; use this when embedding into
/// UIKit/AppKit view hierarchies via representable, or when you need ``MathLabel`` APIs.
public struct HostedMathLabel: View {
    public var latex: String
    public var mathFont: MathFont
    public var typesettingStyle: TypesettingStyle
    public var textAlignment: MathLabelAlignment
    public var preferredMaxLayoutWidth: CGFloat
    public var displayErrorInline: Bool
    public var textFallbackFontName: String?
    public var contentInsets: EdgeInsets

    public init(
        _ latex: String,
        mathFont: MathFont = MathFont(name: .latinModern, size: 20),
        typesettingStyle: TypesettingStyle = .display,
        textAlignment: MathLabelAlignment = .left,
        preferredMaxLayoutWidth: CGFloat = 0,
        displayErrorInline: Bool = true,
        textFallbackFontName: String? = nil,
        contentInsets: EdgeInsets = EdgeInsets()
    ) {
        self.latex = latex
        self.mathFont = mathFont
        self.typesettingStyle = typesettingStyle
        self.textAlignment = textAlignment
        self.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        self.displayErrorInline = displayErrorInline
        self.textFallbackFontName = textFallbackFontName
        self.contentInsets = contentInsets
    }

    public var body: some View {
        HostedMathLabelRepresentable(
            latex: latex,
            mathFont: mathFont,
            typesettingStyle: typesettingStyle,
            textAlignment: textAlignment,
            preferredMaxLayoutWidth: preferredMaxLayoutWidth,
            displayErrorInline: displayErrorInline,
            textFallbackFontName: textFallbackFontName,
            contentInsets: contentInsets
        )
        .fixedSize(horizontal: preferredMaxLayoutWidth <= 0, vertical: true)
    }
}

#if canImport(UIKit) && !os(watchOS)

private struct HostedMathLabelRepresentable: UIViewRepresentable {
    var latex: String
    var mathFont: MathFont
    var typesettingStyle: TypesettingStyle
    var textAlignment: MathLabelAlignment
    var preferredMaxLayoutWidth: CGFloat
    var displayErrorInline: Bool
    var textFallbackFontName: String?
    var contentInsets: EdgeInsets

    func makeUIView(context: Context) -> MathLabel {
        let label = MathLabel()
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        apply(to: label)
        return label
    }

    func updateUIView(_ uiView: MathLabel, context: Context) {
        apply(to: uiView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MathLabel,
        context: Context
    ) -> CGSize? {
        let width = preferredMaxLayoutWidth > 0
            ? preferredMaxLayoutWidth
            : (proposal.width ?? 0)
        return uiView.sizeThatFitsMath(CGSize(width: width, height: proposal.height ?? 0))
    }

    private func apply(to label: MathLabel) {
        label.latex = latex
        label.mathFont = mathFont
        label.typesettingStyle = typesettingStyle
        label.textAlignment = textAlignment
        label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        label.displayErrorInline = displayErrorInline
        label.textFallbackFontName = textFallbackFontName
        label.contentInsets = NSDirectionalEdgeInsets(
            top: contentInsets.top,
            leading: contentInsets.leading,
            bottom: contentInsets.bottom,
            trailing: contentInsets.trailing
        )
    }
}

#elseif canImport(AppKit)

private struct HostedMathLabelRepresentable: NSViewRepresentable {
    var latex: String
    var mathFont: MathFont
    var typesettingStyle: TypesettingStyle
    var textAlignment: MathLabelAlignment
    var preferredMaxLayoutWidth: CGFloat
    var displayErrorInline: Bool
    var textFallbackFontName: String?
    var contentInsets: EdgeInsets

    func makeNSView(context: Context) -> MathLabel {
        let label = MathLabel()
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        apply(to: label)
        return label
    }

    func updateNSView(_ nsView: MathLabel, context: Context) {
        apply(to: nsView)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: MathLabel,
        context: Context
    ) -> CGSize? {
        let width = preferredMaxLayoutWidth > 0
            ? preferredMaxLayoutWidth
            : (proposal.width ?? 0)
        return nsView.sizeThatFitsMath(CGSize(width: width, height: proposal.height ?? 0))
    }

    private func apply(to label: MathLabel) {
        label.latex = latex
        label.mathFont = mathFont
        label.typesettingStyle = typesettingStyle
        label.textAlignment = textAlignment
        label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        label.displayErrorInline = displayErrorInline
        label.textFallbackFontName = textFallbackFontName
        label.contentInsets = NSDirectionalEdgeInsets(
            top: contentInsets.top,
            leading: contentInsets.leading,
            bottom: contentInsets.bottom,
            trailing: contentInsets.trailing
        )
    }
}

#endif

#endif

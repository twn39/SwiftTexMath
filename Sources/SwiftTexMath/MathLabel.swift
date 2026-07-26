import CoreGraphics
import Foundation
import SwiftTexMathCore

#if canImport(UIKit) && !os(watchOS)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Horizontal alignment of math content inside ``MathLabel``.
public enum MathLabelAlignment: Sendable, Hashable {
    case left
    case center
    case right
}

#if (canImport(UIKit) && !os(watchOS)) || (canImport(AppKit) && !targetEnvironment(macCatalyst))

#if canImport(UIKit) && !os(watchOS)
public typealias MathLabelView = UIView
public typealias MathLabelColor = UIColor
#elseif canImport(AppKit)
public typealias MathLabelView = NSView
public typealias MathLabelColor = NSColor
#endif

/// UIKit / AppKit host that typesets LaTeX with ``MathRenderer`` (parity with iosMath `MTMathUILabel`).
///
/// ```swift
/// let label = MathLabel()
/// label.latex = #"E = mc^2"#
/// label.mathFont = MathFont(name: .latinModern, size: 24)
/// label.preferredMaxLayoutWidth = 280
/// ```
@MainActor
open class MathLabel: MathLabelView {
    public var latex: String = "" {
        didSet { invalidateMath() }
    }

    public var mathFont: MathFont = MathFont(name: .latinModern, size: 20) {
        didSet { invalidateMath() }
    }

    public var typesettingStyle: TypesettingStyle = .display {
        didSet { invalidateMath() }
    }

    public var textColor: MathLabelColor = {
        #if canImport(UIKit) && !os(watchOS)
        .label
        #else
        .labelColor
        #endif
    }() {
        didSet { setNeedsDisplayPlatform() }
    }

    public var contentInsets: NSDirectionalEdgeInsets = .init(top: 0, leading: 0, bottom: 0, trailing: 0) {
        didSet {
            invalidateIntrinsicContentSizePlatform()
            setNeedsDisplayPlatform()
        }
    }

    public var textAlignment: MathLabelAlignment = .left {
        didSet { setNeedsDisplayPlatform() }
    }

    /// Soft wrap width hint (0 = use bounds width when laid out).
    public var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet { invalidateMath() }
    }

    public var displayErrorInline: Bool = true {
        didSet { setNeedsDisplayPlatform() }
    }

    public var fonts: any FontProviding = FontRegistry.shared {
        didSet { invalidateMath() }
    }

    public var textFallbackFontName: String? {
        didSet { invalidateMath() }
    }

    public private(set) var parseError: ParseError?
    public private(set) var displayList: DisplayList?

    /// When true (default), the context menu / edit menu includes “Copy LaTeX”.
    public var allowsCopyingLatex: Bool = true

    #if canImport(UIKit) && !os(watchOS)
    private let errorLabel = UILabel()
    #elseif canImport(AppKit)
    private let errorLabel = NSTextField(labelWithString: "")
    #endif

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        #if canImport(UIKit) && !os(watchOS)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        isUserInteractionEnabled = true
        addInteraction(UIEditMenuInteraction(delegate: self))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressForCopy(_:)))
        addGestureRecognizer(longPress)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.font = .preferredFont(forTextStyle: .caption1)
        errorLabel.isHidden = true
        addSubview(errorLabel)
        #elseif canImport(AppKit)
        wantsLayer = true
        layer?.backgroundColor = .clear
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        errorLabel.textColor = .systemRed
        errorLabel.isEditable = false
        errorLabel.isBordered = false
        errorLabel.drawsBackground = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 0
        errorLabel.isHidden = true
        addSubview(errorLabel)
        #endif
        updateAccessibilityLabel()
    }

    /// Copy the source LaTeX string to the system pasteboard.
    @discardableResult
    public func copyLatexToPasteboard() -> Bool {
        guard allowsCopyingLatex, !latex.isEmpty else { return false }
        #if canImport(UIKit) && !os(watchOS)
        UIPasteboard.general.string = latex
        return true
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(latex, forType: .string)
        #else
        return false
        #endif
    }

    private func updateAccessibilityLabel() {
        let label: String
        if let parseError {
            label = parseError.message.isEmpty
                ? "Math parse error"
                : "Math parse error: \(parseError.message)"
        } else if latex.isEmpty {
            label = "Empty math"
        } else {
            label = latex
        }
        #if canImport(UIKit) && !os(watchOS)
        accessibilityLabel = label
        #elseif canImport(AppKit)
        setAccessibilityLabel(label)
        #endif
    }

    private func invalidateMath() {
        relayout()
        updateAccessibilityLabel()
        invalidateIntrinsicContentSizePlatform()
        setNeedsDisplayPlatform()
    }

    private func effectiveMaxWidth(for size: CGSize) -> CGFloat {
        let hint = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : size.width
        let insetWidth = contentInsets.leading + contentInsets.trailing
        return max(0, hint - insetWidth)
    }

    private func makeEnvironment(maxWidth: CGFloat) -> MathEnvironment {
        MathEnvironment(
            font: mathFont,
            style: typesettingStyle.mathStyle,
            maxWidth: maxWidth,
            textFallbackFontName: textFallbackFontName
        )
    }

    private func relayout(for size: CGSize? = nil) {
        parseError = nil
        displayList = nil
        let layoutSize = size ?? bounds.size
        let env = makeEnvironment(maxWidth: effectiveMaxWidth(for: layoutSize))
        do {
            displayList = try MathRenderer(environment: env, fonts: fonts).layout(latex: latex)
            #if canImport(UIKit) && !os(watchOS)
            errorLabel.isHidden = true
            #elseif canImport(AppKit)
            errorLabel.isHidden = true
            #endif
        } catch let error as ParseError {
            parseError = error
            #if canImport(UIKit) && !os(watchOS)
            errorLabel.text = error.message
            errorLabel.isHidden = !displayErrorInline
            #elseif canImport(AppKit)
            errorLabel.stringValue = error.message
            errorLabel.isHidden = !displayErrorInline
            #endif
        } catch {
            let wrapped = ParseError(code: .internalError, message: error.localizedDescription)
            parseError = wrapped
            #if canImport(UIKit) && !os(watchOS)
            errorLabel.text = wrapped.message
            errorLabel.isHidden = !displayErrorInline
            #elseif canImport(AppKit)
            errorLabel.stringValue = wrapped.message
            errorLabel.isHidden = !displayErrorInline
            #endif
        }
    }

    private func contentSize(for display: DisplayList) -> CGSize {
        CGSize(
            width: display.width + contentInsets.leading + contentInsets.trailing,
            height: display.ascent + display.descent + contentInsets.top + contentInsets.bottom
        )
    }

    public func sizeThatFitsMath(_ size: CGSize) -> CGSize {
        let env = makeEnvironment(maxWidth: effectiveMaxWidth(for: size))
        do {
            let display = try MathRenderer(environment: env, fonts: fonts).layout(latex: latex)
            return contentSize(for: display)
        } catch {
            return CGSize(width: max(120, size.width), height: 24)
        }
    }

    #if canImport(UIKit) && !os(watchOS)
    /// Aligns with surrounding UILabel text when used in baseline-aligned stacks.
    open var firstBaselineOffsetFromTop: CGFloat {
        let ascent = displayList?.ascent ?? max(mathFont.size * 0.8, 12)
        return contentInsets.top + ascent
    }

    open var lastBaselineOffsetFromBottom: CGFloat {
        let descent = displayList?.descent ?? max(mathFont.size * 0.2, 4)
        return contentInsets.bottom + descent
    }

    public override var intrinsicContentSize: CGSize {
        sizeThatFitsMath(
            CGSize(
                width: preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : UIView.noIntrinsicMetric,
                height: UIView.noIntrinsicMetric
            )
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        relayout(for: bounds.size)
        errorLabel.frame = bounds.inset(
            by: UIEdgeInsets(
                top: contentInsets.top,
                left: contentInsets.leading,
                bottom: contentInsets.bottom,
                right: contentInsets.trailing
            )
        )
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let display = displayList, let ctx = UIGraphicsGetCurrentContext() else { return }
        drawMath(display, in: ctx, bounds: bounds)
    }

    #elseif canImport(AppKit)
    /// Aligns with surrounding NSTextField / labels in baseline-aligned Auto Layout.
    public override var firstBaselineOffsetFromTop: CGFloat {
        let ascent = displayList?.ascent ?? max(mathFont.size * 0.8, 12)
        return contentInsets.top + ascent
    }

    public override var lastBaselineOffsetFromBottom: CGFloat {
        let descent = displayList?.descent ?? max(mathFont.size * 0.2, 4)
        return contentInsets.bottom + descent
    }

    public override var intrinsicContentSize: NSSize {
        sizeThatFitsMath(
            CGSize(
                width: preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : NSView.noIntrinsicMetric,
                height: NSView.noIntrinsicMetric
            )
        )
    }

    public override var isFlipped: Bool { true }

    public override func layout() {
        super.layout()
        relayout(for: bounds.size)
        let inset = NSEdgeInsets(
            top: contentInsets.top,
            left: contentInsets.leading,
            bottom: contentInsets.bottom,
            right: contentInsets.trailing
        )
        errorLabel.frame = bounds.insetBy(dx: inset.left, dy: inset.top).integral
        // Approximate insets for error label.
        errorLabel.frame = CGRect(
            x: bounds.minX + contentInsets.leading,
            y: bounds.minY + contentInsets.top,
            width: max(0, bounds.width - contentInsets.leading - contentInsets.trailing),
            height: max(0, bounds.height - contentInsets.top - contentInsets.bottom)
        )
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let display = displayList, let ctx = NSGraphicsContext.current?.cgContext else { return }
        drawMath(display, in: ctx, bounds: bounds)
    }
    #endif

    private func drawMath(_ display: DisplayList, in ctx: CGContext, bounds: CGRect) {
        ctx.saveGState()

        let availableWidth = bounds.width - contentInsets.leading - contentInsets.trailing
        let availableHeight = bounds.height - contentInsets.top - contentInsets.bottom
        let textX: CGFloat
        switch textAlignment {
        case .left:
            textX = contentInsets.leading
        case .center:
            textX = contentInsets.leading + max(0, (availableWidth - display.width) / 2)
        case .right:
            textX = bounds.width - contentInsets.trailing - display.width
        }

        let contentHeight = display.ascent + display.descent
        let textYDown = contentInsets.top + max(0, (availableHeight - contentHeight) / 2) + display.ascent

        // Platform contexts are y-down; flip to math y-up around the baseline.
        ctx.translateBy(x: textX, y: textYDown)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(display, at: .zero, foregroundColor: textColor.cgColor, fonts: fonts)
        ctx.restoreGState()
    }

    private func setNeedsDisplayPlatform() {
        #if canImport(UIKit) && !os(watchOS)
        setNeedsDisplay()
        #elseif canImport(AppKit)
        needsDisplay = true
        #endif
    }

    private func invalidateIntrinsicContentSizePlatform() {
        #if canImport(UIKit) && !os(watchOS)
        invalidateIntrinsicContentSize()
        #elseif canImport(AppKit)
        invalidateIntrinsicContentSize()
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    @objc private func handleLongPressForCopy(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, allowsCopyingLatex, !latex.isEmpty else { return }
        becomeFirstResponder()
        let menu = UIMenuController.shared
        menu.menuItems = [UIMenuItem(title: "Copy LaTeX", action: #selector(copyLatexAction))]
        menu.showMenu(from: self, rect: bounds)
    }

    @objc private func copyLatexAction() {
        _ = copyLatexToPasteboard()
    }

    public override var canBecomeFirstResponder: Bool { allowsCopyingLatex }

    public override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(copyLatexAction) {
            return allowsCopyingLatex && !latex.isEmpty
        }
        return super.canPerformAction(action, withSender: sender)
    }

    public override func copy(_ sender: Any?) {
        _ = copyLatexToPasteboard()
    }
    #elseif canImport(AppKit)
    public override func menu(for event: NSEvent) -> NSMenu? {
        guard allowsCopyingLatex, !latex.isEmpty else { return super.menu(for: event) }
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Copy LaTeX",
            action: #selector(copyLatexAction),
            keyEquivalent: ""
        )
        return menu
    }

    @objc private func copyLatexAction() {
        _ = copyLatexToPasteboard()
    }

    public override var acceptsFirstResponder: Bool { true }

    @objc public func copy(_ sender: Any?) {
        _ = copyLatexToPasteboard()
    }
    #endif
}

#if canImport(UIKit) && !os(watchOS)
@MainActor
extension MathLabel: @preconcurrency UIEditMenuInteractionDelegate {
    public func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        guard allowsCopyingLatex, !latex.isEmpty else { return nil }
        let copy = UIAction(title: "Copy LaTeX") { [weak self] _ in
            _ = self?.copyLatexToPasteboard()
        }
        return UIMenu(children: [copy])
    }
}
#endif

#endif

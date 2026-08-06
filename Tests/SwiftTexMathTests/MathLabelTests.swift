import CoreGraphics
import Testing
import SwiftTexMath
import SwiftTexMathCore

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit) && !os(watchOS)
import UIKit
#endif

#if (canImport(UIKit) && !os(watchOS)) || (canImport(AppKit) && !targetEnvironment(macCatalyst))

@Test @MainActor
func mathLabelIntrinsicSizePositive() {
    let label = MathLabel(frame: .zero)
    label.latex = #"E = mc^2"#
    label.mathFont = MathFont(name: .latinModern, size: 20)
    label.typesettingStyle = .display
    let size = label.intrinsicContentSize
    #expect(size.width > 40)
    #expect(size.height > 12)
}

@Test @MainActor
func mathLabelPreferredWidthWraps() {
    let label = MathLabel(frame: .zero)
    label.latex = #"a = b = c = d = e = f = g = h"#
    label.mathFont = MathFont(name: .latinModern, size: 18)
    label.preferredMaxLayoutWidth = 60
    let wrapped = label.sizeThatFitsMath(CGSize(width: 60, height: 0))
    label.preferredMaxLayoutWidth = 0
    let unwrapped = label.sizeThatFitsMath(CGSize(width: 0, height: 0))
    #expect(wrapped.width <= 61)
    #expect(wrapped.height >= unwrapped.height)
}

@Test @MainActor
func mathLabelSurfacesParseErrorInline() {
    let label = MathLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    label.displayErrorInline = true
    label.latex = #"\notacommand"#
    #if canImport(UIKit) && !os(watchOS)
    label.layoutIfNeeded()
    #elseif canImport(AppKit)
    label.layout()
    #endif
    #expect(label.parseError != nil)
    #expect(label.displayList == nil)
}

@Test @MainActor
func mathLabelLayoutsValidLatex() {
    let label = MathLabel(frame: CGRect(x: 0, y: 0, width: 300, height: 80))
    label.latex = #"\frac{1}{2}"#
    #if canImport(UIKit) && !os(watchOS)
    label.layoutIfNeeded()
    #elseif canImport(AppKit)
    label.layout()
    #endif
    #expect(label.parseError == nil)
    #expect(label.displayList != nil)
    #expect(label.displayList!.width > 0)
}

@Test @MainActor
func mathLabelFontAndStyleUpdates() {
    let label = MathLabel(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    label.latex = #"x + y"#
    label.mathFont = MathFont(name: .xits, size: 24)
    label.typesettingStyle = .text
    #if canImport(UIKit) && !os(watchOS)
    label.textColor = .red
    label.layoutIfNeeded()
    #elseif canImport(AppKit)
    label.textColor = .red
    label.layout()
    #endif
    #expect(label.mathFont.size == 24)
    #expect(label.typesettingStyle == .text)
}

#endif

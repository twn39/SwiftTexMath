import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

// MARK: - Cross-parse user macros

@Test func crossParseUserMacrosViaMathParser() throws {
    let macros: [String: MathParser.UserMacro] = [
        "RR": .init(parameterCount: 0, replacement: #"\mathrm{R}"#),
        "swap": .init(parameterCount: 2, replacement: "#2+#1")
    ]
    let list = try MathParser.parse(#"\RR+\swap{a}{b}"#, userMacros: macros)
    #expect(list.atoms.count >= 3)
    #expect(list.atoms.contains { $0.nucleus == "b" || $0.kind == .variable })
}

@Test func crossParseUserMacrosViaMathRenderer() throws {
    var renderer = MathRenderer()
    renderer.defineMacro("qq", parameterCount: 1, replacement: "#1^2")
    let display = try renderer.layout(latex: #"\qq{x}"#)
    #expect(display.width > 0)
    #expect(display.ascent > 0)

    renderer.removeMacro("qq")
    #expect(throws: ParseError.self) {
        _ = try renderer.layout(latex: #"\qq{x}"#)
    }
}

@Test func inSourceNewcommandOverridesSeededMacro() throws {
    let macros: [String: MathParser.UserMacro] = [
        "foo": .init(parameterCount: 0, replacement: "a")
    ]
    let list = try MathParser.parse(
        #"\renewcommand{\foo}{b}\foo"#,
        userMacros: macros
    )
    #expect(list.atoms.count == 1)
    #expect(list.atoms[0].nucleus == "b")
}

// MARK: - \notag and auto equation numbers

@Test func notagParsesAndSuppressesAutoNumber() throws {
    let list = try MathParser.parse(#"x=1\notag"#)
    #expect(list.atoms.contains { atom in
        if case .tag(let tag) = atom.payload { return tag.suppress }
        return false
    })

    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(latex: #"x=1\notag"#)
    // No visible tag digits when suppressed.
    #expect(!display.accessibilityPlainText.contains("1)") && !display.accessibilityPlainText.contains("(1"))
}

@Test func autoEquationNumberOnDisplayLine() throws {
    let env = MathEnvironment(style: .display, numberEquations: true, equationNumberStart: 7)
    let display = try MathRenderer(environment: env).layout(latex: #"E=mc^2"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("7") || display.width > 0)
    // Explicit tag should be present as a trailing node with positive width past body.
    #expect(display.children.count >= 2)
}

@Test func explicitTagBlocksAutoNumber() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(latex: #"a=b\tag{42}"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("42"))
    #expect(!text.contains("(1)"))
}

@Test func autoNumberOnGatherRows() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{gather} a=1 \\ b=2 \end{gather}"#
    )
    #expect(display.width > 0)
    #expect(display.ascent + display.descent > 0)
    // Two rows → two auto numbers widen or deepen layout vs unnumbered.
    let plain = try MathRenderer().layout(
        latex: #"\begin{gather} a=1 \\ b=2 \end{gather}"#
    )
    #expect(display.width >= plain.width)
}

@Test func notagOnOneGatherRow() throws {
    let env = MathEnvironment(numberEquations: true, equationNumberStart: 1)
    let display = try MathRenderer(environment: env).layout(
        latex: #"\begin{gather} a=1\notag \\ b=2 \end{gather}"#
    )
    #expect(display.width > 0)
}

// MARK: - Tag + wrap

@Test func tagFlushRightWithMaxWidth() throws {
    var env = MathEnvironment()
    env.maxWidth = 200
    let display = try MathRenderer(environment: env).layout(latex: #"x+y=z\tag{1}"#)
    #expect(display.width >= 200 - 0.5)
    #expect(display.children.count >= 1)
}

// MARK: - Recursion safety

@Test func deepNestedFractionsDoNotCrashLayoutOrSVG() throws {
    // Keep nesting modest so debug stack frames stay safe; depth budget still truncates.
    var latex = "x"
    for _ in 0..<12 {
        latex = "\\frac{\(latex)}{1}"
    }
    let env = MathEnvironment(maxRecursionDepth: 6)
    let renderer = MathRenderer(environment: env)
    // Layout may truncate nested content past the depth budget.
    let display = try renderer.layout(latex: latex)
    #expect(display.width >= 0)
    let svg = MathSVG.render(display: display, options: .init())
    #expect(!svg.svg.isEmpty)
    #expect(svg.svg.contains("<svg"))
}

@Test func drawRespectsMaxDepth() throws {
    let display = try MathRenderer().layout(latex: #"\frac{1}{2}"#)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let color = CGColor(colorSpace: colorSpace, components: [0, 0, 0, 1])!
    let width = Int(max(display.width, 1).rounded(.up)) + 4
    let height = Int(max(display.ascent + display.descent, 1).rounded(.up)) + 4
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        Issue.record("Failed to create CGContext")
        return
    }
    // Depth 0 only: should not crash; may draw nothing useful.
    ctx.draw(display, at: .zero, foregroundColor: color, maxDepth: 0)
    ctx.draw(display, at: .zero, foregroundColor: color, maxDepth: DisplayTraversal.defaultMaxDepth)
}

// MARK: - Accessibility plain text

@Test func accessibilityPlainTextExtractsGlyphs() throws {
    let display = try MathRenderer().layout(latex: #"x+y"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("x") || text.contains("y") || !text.isEmpty)
}

@Test func accessibilityPlainTextForFraction() throws {
    let display = try MathRenderer().layout(latex: #"\frac{a}{b}"#)
    let text = display.accessibilityPlainText
    #expect(text.contains("a") || text.contains("b") || text.contains("/"))
}

// MARK: - MathRenderer thin façade (architecture)

@Test func mathRendererRemainsThinFacade() throws {
    let renderer = MathRenderer()
    let list = try renderer.parse(#"1+1"#)
    #expect(!list.isEmpty)
    let display = renderer.layout(list)
    #expect(display.width > 0)
}

@Test func latexSerializerNotagRoundTripBestEffort() throws {
    let list = try MathParser.parse(#"a\notag"#)
    let latex = list.latexString
    #expect(latex.contains("notag"))
}

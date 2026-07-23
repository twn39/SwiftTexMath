import Testing
@testable import SwiftTexMathCore

/// Color resolution + parse failure matrix (iosMath `MTColorDecoderTest` / builder color tests).
@Suite("Color parse")
struct ColorParseTests {
    @Test func namedColorsResolve() {
        for name in ["red", "blue", "green", "black", "white", "gray", "grey", "cyan", "LimeGreen", "orange"] {
            #expect(MathColor.components(from: name) != nil, "named color \(name)")
        }
    }

    @Test func hexSixDigit() throws {
        let c = try #require(MathColor.components(from: "#ff00aa"))
        #expect(abs(c.red - 1) < 0.001)
        #expect(abs(c.green - 0) < 0.001)
        #expect(abs(c.blue - 170.0 / 255.0) < 0.001)
    }

    @Test func hexThreeDigitExpands() throws {
        let c = try #require(MathColor.components(from: "#f0a"))
        let full = try #require(MathColor.components(from: "#ff00aa"))
        #expect(abs(c.red - full.red) < 0.001)
        #expect(abs(c.green - full.green) < 0.001)
        #expect(abs(c.blue - full.blue) < 0.001)
    }

    @Test func invalidColorsRejected() {
        for raw in ["", "   ", "#", "#12", "#12345", "#1234567", "#gg0000", "notacolor", "Redish"] {
            #expect(MathColor.components(from: raw) == nil, "should reject \(raw)")
        }
    }

    @Test func whitespaceTrimmed() {
        #expect(MathColor.components(from: "  red  ") != nil)
        #expect(MathColor.components(from: " #00ff00 ") != nil)
    }

    @Test func parseUnknownColorThrows() {
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\color{notacolor}{x}"#)
        }
        #expect(throws: ParseError.self) {
            _ = try MathParser.parse(#"\colorbox{#12}{x}"#)
        }
    }

    @Test func parseValidColorSucceeds() throws {
        let list = try MathParser.parse(#"\color{red}{x}"#)
        #expect(list.atoms.count == 1)
        guard case .colored(let colored) = list.atoms[0].payload else {
            Issue.record("expected colored payload")
            return
        }
        #expect(colored.color == "red")
        #expect(colored.fillsBackground == false)
    }

    @Test func parseColorboxFillsBackground() throws {
        let list = try MathParser.parse(#"\colorbox{#ff0000}{x}"#)
        guard case .colored(let colored) = list.atoms[0].payload else {
            Issue.record("expected colored payload")
            return
        }
        #expect(colored.fillsBackground == true)
    }
}

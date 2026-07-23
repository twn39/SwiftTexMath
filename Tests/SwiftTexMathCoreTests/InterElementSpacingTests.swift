import CoreGraphics
import Testing
@testable import SwiftTexMathCore

/// Full TeX Chapter 18 inter-element spacing matrix (iosMath / SwiftUIMath `testSpacing`).
@Suite("Inter-element spacing")
struct InterElementSpacingTests {
    private let kinds: [AtomKind] = [
        .ordinary, .largeOperator, .binaryOperator, .relation,
        .open, .close, .punctuation, .fraction, .radical
    ]

    /// Expected mu multipliers for text/display style (`mathUnit = 1`, default parameters).
    /// Rows = left kind (incl. radical), columns = ordinary…fraction (radical-as-right uses ordinary column).
    private let textMu: [[CGFloat]] = [
        // ord, op, bin, rel, open, close, punct, frac
        [0, 3, 4, 5, 0, 0, 0, 3], // ordinary
        [3, 3, 0, 5, 0, 0, 0, 3], // operator
        [4, 4, 0, 0, 4, 0, 0, 4], // binary
        [5, 5, 0, 0, 5, 0, 0, 5], // relation
        [0, 0, 0, 0, 0, 0, 0, 0], // open
        [0, 3, 4, 5, 0, 0, 0, 3], // close
        [3, 3, 0, 3, 3, 3, 3, 3], // punct
        [3, 3, 4, 5, 3, 0, 3, 3], // fraction
        [4, 3, 4, 5, 0, 0, 0, 3] // radical (left)
    ]

    @Test func textStyleFullMatrix() {
        for (row, left) in kinds.enumerated() {
            for col in 0..<8 {
                let right = kinds[col]
                let space = InterElementSpacing.space(
                    left: left,
                    right: right,
                    style: .text,
                    parameters: .default,
                    mathUnit: 1
                )
                #expect(
                    space == textMu[row][col],
                    "text \(left)×\(right): got \(space), expected \(textMu[row][col])"
                )
            }
        }
    }

    @Test func scriptStyleDropsNonScriptSpaces() {
        // nsThin / nsMedium / nsThick become 0 in script; thin stays.
        let pairs: [(AtomKind, AtomKind, CGFloat)] = [
            (.ordinary, .largeOperator, 3), // thin
            (.ordinary, .binaryOperator, 0), // nsMedium
            (.ordinary, .relation, 0), // nsThick
            (.ordinary, .fraction, 0), // nsThin
            (.largeOperator, .ordinary, 3), // thin
            (.open, .ordinary, 0)
        ]
        for (left, right, expected) in pairs {
            let space = InterElementSpacing.space(
                left: left,
                right: right,
                style: .script,
                parameters: .default,
                mathUnit: 1
            )
            #expect(space == expected, "script \(left)×\(right)")
        }
    }

    @Test func mathUnitScalesLinearly() {
        let at1 = InterElementSpacing.space(
            left: .ordinary, right: .relation, style: .display,
            parameters: .default, mathUnit: 1
        )
        let at2 = InterElementSpacing.space(
            left: .ordinary, right: .relation, style: .display,
            parameters: .default, mathUnit: 2
        )
        #expect(at1 == 5)
        #expect(at2 == 10)
    }

    @Test func numberAndVariableUseOrdinaryRow() {
        let viaOrdinary = InterElementSpacing.space(
            left: .ordinary, right: .relation, style: .text,
            parameters: .default, mathUnit: 1
        )
        let viaNumber = InterElementSpacing.space(
            left: .number, right: .relation, style: .text,
            parameters: .default, mathUnit: 1
        )
        let viaVariable = InterElementSpacing.space(
            left: .variable, right: .relation, style: .text,
            parameters: .default, mathUnit: 1
        )
        #expect(viaOrdinary == viaNumber)
        #expect(viaOrdinary == viaVariable)
        #expect(viaOrdinary == 5)
    }

    @Test func radicalAsRightUsesOrdinaryColumn() {
        // Radical on the right indexes as ordinary (spacingIndex isLeft: false → 0).
        let space = InterElementSpacing.space(
            left: .ordinary, right: .radical, style: .text,
            parameters: .default, mathUnit: 1
        )
        #expect(space == 0)
    }
}

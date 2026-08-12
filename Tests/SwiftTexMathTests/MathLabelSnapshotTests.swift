import CoreGraphics
import Testing
import SwiftTexMath
import SwiftTexMathCore

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit) && !os(watchOS)
import UIKit
#endif

@Suite("MathLabel UI Component Snapshots")
struct MathLabelSnapshotTests {

#if (canImport(UIKit) && !os(watchOS)) || (canImport(AppKit) && !targetEnvironment(macCatalyst))

    @Test("MathLabel Intrinsic Dimensions Snapshot")
    @MainActor
    func testMathLabelIntrinsicDimensionsSnapshot() {
        let label = MathLabel(frame: .zero)
        label.latex = #"E = mc^2"#
        label.mathFont = MathFont(name: .latinModern, size: 20)
        label.typesettingStyle = .display

        let size = label.intrinsicContentSize
        let snapshotText = "MathLabel(latex: '\(label.latex)', size: (\(String(format: "%.2f", size.width)), \(String(format: "%.2f", size.height))))"
        assertSnapshot(matching: snapshotText, as: .lines, named: "math_label_intrinsic_size")
    }

    @Test("MathLabel Wrapped Dimensions Snapshot")
    @MainActor
    func testMathLabelWrappedDimensionsSnapshot() {
        let label = MathLabel(frame: .zero)
        label.latex = #"a = b = c = d = e = f = g = h"#
        label.mathFont = MathFont(name: .latinModern, size: 18)
        label.preferredMaxLayoutWidth = 60

        let wrapped = label.sizeThatFitsMath(CGSize(width: 60, height: 0))
        let snapshotText = "MathLabelWrapped(width: \(String(format: "%.2f", wrapped.width)), height: \(String(format: "%.2f", wrapped.height)))"
        assertSnapshot(matching: snapshotText, as: .lines, named: "math_label_wrapped_size")
    }

#endif

}

import CoreGraphics
import Foundation

/// Layout for phantom / smash / lap / cancel boxes.
enum BoxLayout {
    static func make(
        _ box: MathAtom.Box,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        let child = typeset(box.contents, env)
        return .box(
            BoxDisplay(
                child: child,
                keepWidth: box.keepWidth,
                keepHeight: box.keepHeight,
                keepDepth: box.keepDepth,
                drawChild: box.drawChild,
                hAlign: box.hAlign,
                strike: box.strike,
                strikeThickness: metrics.fractionRuleThickness,
                strikeVerticalOffset: 0.55 * metrics.accentBaseHeight
            )
        )
    }
}

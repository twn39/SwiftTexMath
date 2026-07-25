import CoreGraphics
import Foundation

enum ScriptLayout {
    static func attach(
        base: DisplayNode,
        superscript: MathList?,
        subscript: MathList?,
        env: MathEnvironment,
        metrics: FontMetrics,
        typeset: (MathList, MathEnvironment) -> DisplayList
    ) -> DisplayNode {
        guard superscript != nil || `subscript` != nil else { return base }

        let scriptStyle = env.style.scriptStyle
        let superEnv = env.with(style: scriptStyle, cramped: env.cramped)
        let subEnv = env.with(style: scriptStyle, cramped: true)

        var superList = superscript.map { typeset($0, superEnv) }
        var subList = `subscript`.map { typeset($0, subEnv) }

        let delta = metrics.spaceAfterScript
        var superShift = env.cramped ? metrics.superscriptShiftUpCramped : metrics.superscriptShiftUp
        var subShift = metrics.subscriptShiftDown

        superShift = max(superShift, base.ascent - metrics.superscriptBottomMin)
        subShift = max(subShift, base.descent + metrics.subscriptTopMax)

        if let s = superList, let b = subList {
            let gap = (superShift - s.descent) - (-subShift + b.ascent)
            if gap < metrics.subSuperscriptGapMin {
                let extra = metrics.subSuperscriptGapMin - gap
                subShift += extra
                let maxSuper = metrics.superscriptBottomMaxWithSubscript
                let superBottom = superShift - s.descent
                if superBottom < maxSuper {
                    superShift += min(maxSuper - superBottom, extra)
                }
            }
        }

        // TeX italic correction shifts the superscript right of an italic nucleus.
        let italic = italicCorrection(of: base)
        let scriptX = base.width
        let subItalicShift = isLargeOperator(of: base) ? italic : 0
        if var s = superList {
            s.position = CGPoint(x: scriptX + italic, y: superShift)
            superList = s
        }
        if var b = subList {
            b.position = CGPoint(x: max(0, scriptX - subItalicShift), y: -subShift)
            subList = b
        }

        let superExtent = (superList?.width ?? 0) + (superList != nil ? italic : 0)
        let subExtent = (subList?.width ?? 0) - (subList != nil ? subItalicShift : 0)
        let scriptWidth = max(superExtent, subExtent) + delta
        let ascent = max(base.ascent, (superList.map { $0.position.y + $0.ascent } ?? base.ascent))
        let descent = max(base.descent, (subList.map { -$0.position.y + $0.descent } ?? base.descent))

        var children: [DisplayNode] = [base]
        if let s = superList { children.append(.list(s)) }
        if let b = subList { children.append(.list(b)) }

        return .list(
            DisplayList(
                ascent: ascent,
                descent: descent,
                width: base.width + scriptWidth,
                children: children
            )
        )
    }

    private static func italicCorrection(of node: DisplayNode) -> CGFloat {
        switch node {
        case .glyphs(let run):
            return run.italicCorrection
        case .list(let list):
            return list.children.last.map(italicCorrection(of:)) ?? 0
        case .largeOperator(let op):
            return op.nucleus.italicCorrection
        default:
            return 0
        }
    }

    private static func isLargeOperator(of node: DisplayNode) -> Bool {
        switch node {
        case .largeOperator:
            return true
        case .glyphs(let run):
            return run.italicCorrection > 0
        case .list(let list):
            return list.children.last.map(isLargeOperator(of:)) ?? false
        default:
            return false
        }
    }
}

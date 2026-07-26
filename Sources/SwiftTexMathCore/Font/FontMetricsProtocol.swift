@preconcurrency import CoreGraphics
import Foundation

/// Protocol abstraction for font metrics lookup.
///
/// Decouples layout engines and display nodes from the concrete `FontMetrics` struct,
/// enabling mock implementations for unit testing and modular font providers.
public protocol FontMetricsProtocol: Sendable {
    var mathUnit: CGFloat { get }
    var size: CGFloat { get }

    func unitsToPoints(_ value: Int) -> CGFloat
    func constant(named name: String) -> CGFloat
    func percentConstant(named name: String) -> CGFloat
    func glyph(for nucleus: String) -> CGGlyph
    func glyphName(for glyph: CGGlyph) -> String
    func glyphID(named name: String) -> CGGlyph
    func advances(forGlyphs glyphs: [CGGlyph]) -> [CGSize]
    func boundingRects(forGlyphs glyphs: [CGGlyph]) -> [CGRect]
    func italicCorrection(for glyph: CGGlyph) -> CGFloat
    func topAccentAdjustment(for glyph: CGGlyph) -> CGFloat
}

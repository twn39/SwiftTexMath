import Testing
import CoreGraphics
import Foundation
@testable import SwiftTexMathCore

@Suite("MathRenderer CGContext Tests")
struct MathRendererCGContextTests {
    @Test("MathRenderer render into bitmap CGContext")
    func testRenderIntoBitmapCGContext() throws {
        let width = 200
        let height = 100
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            #expect(Bool(false), "Failed to create CGContext")
            return
        }

        let renderer = MathRenderer()
        let blackColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Exercise render convenience method
        try renderer.render(#"\int_{0}^{\infty} e^{-x^2} dx"#, in: context, at: CGPoint(x: 10, y: 50), foregroundColor: blackColor)

        // Exercise direct draw method
        let display = try renderer.layout(latex: #"A = \pi r^2"#)
        renderer.draw(display, in: context, at: CGPoint(x: 10, y: 20), foregroundColor: blackColor)

        #expect(Bool(true))
    }
}

import CoreGraphics
import Foundation

/// Vector PDF export for laid-out math (page sized to the expression + padding).
public enum MathPDF {
    public struct Options: Sendable {
        public var padding: CGFloat
        public var foregroundColor: CGColor
        public var backgroundColor: CGColor?

        public init(
            padding: CGFloat = 4,
            foregroundColor: CGColor = CGColor(gray: 0, alpha: 1),
            backgroundColor: CGColor? = nil
        ) {
            self.padding = padding
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }

        public static let darkMode = Options(
            padding: 4,
            foregroundColor: CGColor(gray: 1, alpha: 1),
            backgroundColor: CGColor(gray: 0, alpha: 1)
        )

        public static let transparent = Options(
            padding: 4,
            foregroundColor: CGColor(gray: 0, alpha: 1),
            backgroundColor: nil
        )
    }

    public struct Result: Sendable {
        public var data: Data
        public var display: DisplayList
        public var size: CGSize
        public var baselineOffset: CGFloat

        public init(data: Data, display: DisplayList, size: CGSize, baselineOffset: CGFloat = 0) {
            self.data = data
            self.display = display
            self.size = size
            self.baselineOffset = baselineOffset
        }
    }

    /// Parse + layout + PDF.
    public static func render(
        latex: String,
        environment: MathEnvironment = MathEnvironment(),
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) throws -> Data {
        let renderer = MathRenderer(environment: environment, fonts: fonts)
        let display = try renderer.layout(latex: latex)
        return render(display: display, fonts: fonts, options: options)
    }

    /// Parse + layout + PDF Result (with metadata).
    public static func renderResult(
        latex: String,
        environment: MathEnvironment = MathEnvironment(),
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) throws -> Result {
        let renderer = MathRenderer(environment: environment, fonts: fonts)
        let display = try renderer.layout(latex: latex)
        return renderResult(display: display, fonts: fonts, options: options)
    }

    /// PDF Result for an existing display list.
    public static func renderResult(
        display: DisplayList,
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) -> Result {
        let pad = max(options.padding, 0)
        let width = max(display.width + 2 * pad, 1)
        let height = max(display.ascent + display.descent + 2 * pad, 1)
        let pdfData = render(display: display, fonts: fonts, options: options)
        return Result(
            data: pdfData,
            display: display,
            size: CGSize(width: width, height: height),
            baselineOffset: pad + display.descent
        )
    }

    /// PDF data for an existing display list (points = media box).
    public static func render(
        display: DisplayList,
        fonts: any FontProviding = FontRegistry.shared,
        options: Options = Options()
    ) -> Data {
        let pad = max(options.padding, 0)
        let width = max(display.width + 2 * pad, 1)
        let height = max(display.ascent + display.descent + 2 * pad, 1)
        let mediaBox = CGRect(x: 0, y: 0, width: width, height: height)

        let data = NSMutableData()
        var mediaBoxVar = mediaBox
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBoxVar, nil)
        else {
            return Data()
        }

        ctx.beginPDFPage(nil)
        if let background = options.backgroundColor {
            ctx.setFillColor(background)
            ctx.fill(mediaBox)
        }

        // PDF is y-up; place baseline so ascent sits below the top padding.
        let origin = CGPoint(x: pad, y: pad + display.descent)
        ctx.draw(display, at: origin, foregroundColor: options.foregroundColor, fonts: fonts)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }
}

import Foundation
import SwiftTexMathCore

/// Headless smoke demo: parse → layout → report sizes, optional PNG write.
///
/// ```bash
/// swift run SwiftTexMathDemo
/// swift run SwiftTexMathDemo 'E=mc^2' /tmp/out.png
/// ```

let latex = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : #"x = \frac{-b \pm \sqrt{b^2-4ac}}{2a}"#

let env = MathEnvironment(
    font: MathFont(name: .latinModern, size: 24),
    style: .display
)

do {
    let display = try MathRenderer(environment: env).layout(latex: latex)
    print("latex: \(latex)")
    print(
        String(
            format: "size: ascent=%.2f descent=%.2f width=%.2f",
            display.ascent,
            display.descent,
            display.width
        )
    )
    print("children: \(display.children.count)")

    if CommandLine.arguments.count > 2 {
        let path = CommandLine.arguments[2]
        let result = try MathImage.render(latex: latex, environment: env)
        guard let png = MathImage.pngData(from: result.image) else {
            fputs("error: failed to encode PNG\n", stderr)
            exit(1)
        }
        try png.write(to: URL(fileURLWithPath: path))
        print("wrote PNG: \(path) (\(result.image.width)×\(result.image.height) px)")
    }

    // Vector PDF / SVG smoke paths
    let pdf = try MathPDF.render(latex: latex, environment: env)
    print("pdf bytes: \(pdf.count)")
    let svg = try MathSVG.render(latex: latex, environment: env)
    print("svg chars: \(svg.svg.count) size=\(svg.size.width)×\(svg.size.height)")
    if CommandLine.arguments.count > 2 {
        let svgURL = URL(fileURLWithPath: CommandLine.arguments[2])
            .deletingPathExtension()
            .appendingPathExtension("svg")
        try svg.data.write(to: svgURL)
        print("wrote SVG: \(svgURL.path)")
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

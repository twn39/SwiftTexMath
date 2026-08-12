import CoreGraphics
import Foundation
import Testing
@testable import SwiftTexMathCore

/// A snapshotting strategy defining how a value of type `Value` is rendered into a baseline format `Format`.
public struct Snapshotting<Value, Format> {
    public var pathExtension: String
    public var serialize: (Value) throws -> Format
    public var compare: (Format, Format) -> Bool
    public var formatDescription: (Format) -> String

    public init(
        pathExtension: String,
        serialize: @escaping (Value) throws -> Format,
        compare: @escaping (Format, Format) -> Bool,
        formatDescription: @escaping (Format) -> String
    ) {
        self.pathExtension = pathExtension
        self.serialize = serialize
        self.compare = compare
        self.formatDescription = formatDescription
    }
}

extension Snapshotting where Value == MathSVG.Result, Format == String {
    /// Strategy for SVG vector outputs.
    public static var svg: Snapshotting<MathSVG.Result, String> {
        Snapshotting(
            pathExtension: "svg",
            serialize: { $0.svg },
            compare: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == $1.trimmingCharacters(in: .whitespacesAndNewlines) },
            formatDescription: { $0 }
        )
    }
}

extension Snapshotting where Value == DisplayList, Format == String {
    /// Strategy for DisplayList structural tree representations.
    public static var displayTree: Snapshotting<DisplayList, String> {
        Snapshotting(
            pathExtension: "txt",
            serialize: { formatDisplayListTree($0) },
            compare: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == $1.trimmingCharacters(in: .whitespacesAndNewlines) },
            formatDescription: { $0 }
        )
    }
}

extension Snapshotting where Value == CGImage, Format == Data {
    /// Strategy for PNG image data.
    public static var pngData: Snapshotting<CGImage, Data> {
        Snapshotting(
            pathExtension: "png",
            serialize: { image in
                guard let data = MathImage.pngData(from: image) else {
                    throw SnapshotError.pngEncodingFailed
                }
                return data
            },
            compare: { actual, expected in
                guard let actualImg = MathImage.image(fromPNG: actual),
                      let expectedImg = MathImage.image(fromPNG: expected) else {
                    return actual == expected
                }
                return MathImage.matches(actualImg, expectedImg, maxDifferingFraction: 0, maxChannelDelta: 0)
            },
            formatDescription: { data in "PNG image data (\(data.count) bytes)" }
        )
    }
}

extension Snapshotting where Value == String, Format == String {
    /// Strategy for plain text string lines.
    public static var lines: Snapshotting<String, String> {
        Snapshotting(
            pathExtension: "txt",
            serialize: { $0 },
            compare: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == $1.trimmingCharacters(in: .whitespacesAndNewlines) },
            formatDescription: { $0 }
        )
    }
}

public enum SnapshotError: Error {
    case pngEncodingFailed
    case fileReadFailed(URL)
}

/// Asserts that a value matches its committed snapshot baseline file.
public func assertSnapshot<Value, Format>(
    matching value: Value,
    as strategy: Snapshotting<Value, Format>,
    named name: String,
    filePath: String = #filePath,
    line: Int = #line
) {
    let isRecording = ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ||
                      ProcessInfo.processInfo.environment["REGENERATE_GOLDENS"] == "1"

    let testFileURL = URL(fileURLWithPath: filePath)
    let testFileName = testFileURL.deletingPathExtension().lastPathComponent
    let snapshotsDir = testFileURL.deletingLastPathComponent()
        .appendingPathComponent("__Snapshots__", isDirectory: true)
        .appendingPathComponent(testFileName, isDirectory: true)

    let snapshotFileURL = snapshotsDir.appendingPathComponent("\(name).\(strategy.pathExtension)")

    do {
        let actualFormat = try strategy.serialize(value)

        if isRecording || !FileManager.default.fileExists(atPath: snapshotFileURL.path) {
            try FileManager.default.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
            let data: Data
            if let stringContent = actualFormat as? String {
                data = Data(stringContent.utf8)
            } else if let dataContent = actualFormat as? Data {
                data = dataContent
            } else {
                fatalError("Unsupported snapshot format type")
            }
            try data.write(to: snapshotFileURL)
            if !isRecording {
                print("Recorded new snapshot baseline at \(snapshotFileURL.path)")
            }
            return
        }

        let existingData = try Data(contentsOf: snapshotFileURL)
        let expectedFormat: Format
        if Format.self == String.self {
            guard let str = String(data: existingData, encoding: .utf8) as? Format else {
                Issue.record("Failed to read snapshot file as UTF-8 at \(snapshotFileURL.path)")
                return
            }
            expectedFormat = str
        } else if Format.self == Data.self {
            guard let d = existingData as? Format else {
                Issue.record("Failed to read snapshot data at \(snapshotFileURL.path)")
                return
            }
            expectedFormat = d
        } else {
            fatalError("Unsupported format type")
        }

        if !strategy.compare(actualFormat, expectedFormat) {
            let actualDesc = strategy.formatDescription(actualFormat)
            let expectedDesc = strategy.formatDescription(expectedFormat)
            Issue.record(
                "Snapshot mismatch for '\(name)'. Run: RECORD_SNAPSHOTS=1 swift test to re-record.\nExpected:\n\(expectedDesc)\n\nActual:\n\(actualDesc)",
                sourceLocation: SourceLocation(fileID: #fileID, filePath: filePath, line: line, column: 1)
            )
        }
    } catch {
        Issue.record("Snapshot error: \(error)", sourceLocation: SourceLocation(fileID: #fileID, filePath: filePath, line: line, column: 1))
    }
}

/// Formats a `DisplayList` recursively into a clean ASCII tree.
public func formatDisplayListTree(_ display: DisplayList, indent: String = "") -> String {
    var result = "\(indent)DisplayList(w: \(String(format: "%.2f", display.width)), a: \(String(format: "%.2f", display.ascent)), d: \(String(format: "%.2f", display.descent)))\n"
    for node in display.children {
        result += formatDisplayNode(node, indent: indent + "  ")
    }
    return result
}

private func formatDisplayNode(_ node: DisplayNode, indent: String) -> String {
    switch node {
    case .list(let list):
        return formatDisplayListTree(list, indent: indent)
    case .glyphs(let g):
        let ids = g.glyphIDs.map { String($0) }.joined(separator: ", ")
        return "\(indent)glyphs(text: '\(g.text)', ids: [\(ids)], w: \(String(format: "%.2f", g.width)))\n"
    case .fraction(let f):
        var res = "\(indent)fraction(w: \(String(format: "%.2f", f.width)))\n"
        res += "\(indent)  num:\n" + formatDisplayListTree(f.numerator, indent: indent + "    ")
        res += "\(indent)  den:\n" + formatDisplayListTree(f.denominator, indent: indent + "    ")
        return res
    case .radical(let r):
        var res = "\(indent)radical(w: \(String(format: "%.2f", r.width)))\n"
        if let deg = r.degree {
            res += "\(indent)  deg:\n" + formatDisplayListTree(deg, indent: indent + "    ")
        }
        res += "\(indent)  radicand:\n" + formatDisplayListTree(r.radicand, indent: indent + "    ")
        return res
    case .line(let l):
        return "\(indent)line(w: \(String(format: "%.2f", l.width)), isOverline: \(l.isOverline))\n"
    case .largeOperator(let lo):
        var res = "\(indent)op(w: \(String(format: "%.2f", lo.width)), text: '\(lo.nucleus.text)')\n"
        if let lower = lo.lowerLimit {
            res += "\(indent)  lower:\n" + formatDisplayListTree(lower, indent: indent + "    ")
        }
        if let upper = lo.upperLimit {
            res += "\(indent)  upper:\n" + formatDisplayListTree(upper, indent: indent + "    ")
        }
        return res
    case .colored(let c):
        var res = "\(indent)colored(fillsBG: \(c.fillsBackground))\n"
        res += formatDisplayListTree(c.inner, indent: indent + "  ")
        return res
    case .rule(let r):
        return "\(indent)rule(w: \(String(format: "%.2f", r.width)), isVertical: \(r.isVertical))\n"
    case .box(let b):
        var res = "\(indent)box(w: \(String(format: "%.2f", b.width)))\n"
        res += formatDisplayListTree(b.child, indent: indent + "  ")
        return res
    case .stack(let s):
        var res = "\(indent)stack(w: \(String(format: "%.2f", s.width)))\n"
        res += "\(indent)  base:\n" + formatDisplayListTree(s.base, indent: indent + "    ")
        if let over = s.over {
            res += "\(indent)  over:\n" + formatDisplayListTree(over, indent: indent + "    ")
        }
        if let under = s.under {
            res += "\(indent)  under:\n" + formatDisplayListTree(under, indent: indent + "    ")
        }
        return res
    }
}

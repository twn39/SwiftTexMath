import CoreGraphics
import Foundation
import Testing
import SwiftTexMath
import SwiftTexMathCore

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

extension Snapshotting where Value == String, Format == String {
    public static var lines: Snapshotting<String, String> {
        Snapshotting(
            pathExtension: "txt",
            serialize: { $0 },
            compare: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == $1.trimmingCharacters(in: .whitespacesAndNewlines) },
            formatDescription: { $0 }
        )
    }
}

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

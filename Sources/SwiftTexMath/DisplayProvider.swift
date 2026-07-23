import SwiftUI
import SwiftTexMathCore

/// Caches parse + layout results for SwiftUI layout/draw passes.
enum DisplayProvider {
    struct Key: Hashable, Sendable {
        var latex: String
        var font: MathFont
        var style: TypesettingStyle
        var proposedWidth: CGFloat
    }

    private final class CacheBox: @unchecked Sendable {
        let lock = NSLock()
        var storage: [Key: Result<DisplayList, ParseError>] = [:]
        var order: [Key] = []
        let capacity = 256

        func get(_ key: Key) -> Result<DisplayList, ParseError>? {
            lock.lock()
            defer { lock.unlock() }
            return storage[key]
        }

        func set(_ key: Key, _ value: Result<DisplayList, ParseError>) {
            lock.lock()
            defer { lock.unlock() }
            if storage[key] == nil {
                order.append(key)
            }
            storage[key] = value
            while order.count > capacity {
                let evicted = order.removeFirst()
                storage.removeValue(forKey: evicted)
            }
        }
    }

    private static let cache = CacheBox()

    static func display(
        for latex: String,
        font: MathFont,
        style: TypesettingStyle,
        proposedWidth: CGFloat
    ) -> Result<DisplayList, ParseError> {
        let key = Key(
            latex: latex,
            font: font,
            style: style,
            proposedWidth: proposedWidth.rounded()
        )
        if let cached = cache.get(key) {
            return cached
        }

        let env = MathEnvironment(font: font, style: style.mathStyle, maxWidth: proposedWidth)
        let result: Result<DisplayList, ParseError>
        do {
            let list = try MathParser.parse(latex)
            result = .success(Typesetter.createDisplay(for: list, environment: env))
        } catch let error as ParseError {
            result = .failure(error)
        } catch {
            result = .failure(ParseError(code: .internalError, message: error.localizedDescription))
        }

        cache.set(key, result)
        return result
    }
}

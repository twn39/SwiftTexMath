import SwiftUI
import SwiftTexMathCore

/// Caches parse + layout results for SwiftUI layout/draw passes.
enum DisplayProvider {
    struct Key: Hashable, Sendable {
        var latex: String
        var font: MathFont
        var style: TypesettingStyle
        var proposedWidth: CGFloat
        var textFallbackFontName: String?
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

    /// Returns whether `fonts` is the process-wide shared registry (safe to cache).
    private static func usesSharedRegistry(_ fonts: any FontProviding) -> Bool {
        (fonts as AnyObject) === FontRegistry.shared
    }

    static func display(
        for latex: String,
        font: MathFont,
        style: TypesettingStyle,
        proposedWidth: CGFloat,
        fonts: any FontProviding = FontRegistry.shared,
        textFallbackFontName: String? = nil
    ) -> Result<DisplayList, ParseError> {
        let key = Key(
            latex: latex,
            font: font,
            style: style,
            proposedWidth: proposedWidth.rounded(),
            textFallbackFontName: textFallbackFontName
        )
        let cacheable = usesSharedRegistry(fonts)
        if cacheable, let cached = cache.get(key) {
            return cached
        }

        let env = MathEnvironment(
            font: font,
            style: style.mathStyle,
            maxWidth: proposedWidth,
            textFallbackFontName: textFallbackFontName
        )
        let result: Result<DisplayList, ParseError>
        do {
            let list = try MathParser.parse(latex)
            result = .success(Typesetter.createDisplay(for: list, environment: env, fonts: fonts))
        } catch let error as ParseError {
            result = .failure(error)
        } catch {
            result = .failure(ParseError(code: .internalError, message: error.localizedDescription))
        }

        if cacheable {
            cache.set(key, result)
        }
        return result
    }
}

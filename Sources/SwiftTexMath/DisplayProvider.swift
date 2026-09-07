import SwiftUI
import SwiftTexMathCore

/// Caches parse + layout results for SwiftUI layout/draw passes.
///
/// Automatically caches results across layout passes for default and custom ``FontProviding``
/// implementations to avoid redundant layout calculations.
enum DisplayProvider {
    struct Key: Hashable, Sendable {
        var latex: String
        var font: MathFont
        var style: TypesettingStyle
        var proposedWidth: CGFloat
        var fontProviderID: ObjectIdentifier
        var textFallbackFontName: String?
    }

    private final class LRUCache<Key: Hashable, Value>: @unchecked Sendable {
        private final class Node {
            let key: Key
            var value: Value
            var prev: Node?
            var next: Node?

            init(key: Key, value: Value) {
                self.key = key
                self.value = value
            }
        }

        private let lock = NSLock()
        private var storage: [Key: Node] = [:]
        private var head: Node?
        private var tail: Node?
        let capacity: Int

        init(capacity: Int = 256) {
            self.capacity = capacity
        }

        func get(_ key: Key) -> Value? {
            lock.lock()
            defer { lock.unlock() }
            guard let node = storage[key] else { return nil }
            moveToHead(node)
            return node.value
        }

        func set(_ key: Key, _ value: Value) {
            lock.lock()
            defer { lock.unlock() }
            if let node = storage[key] {
                node.value = value
                moveToHead(node)
                return
            }
            let node = Node(key: key, value: value)
            storage[key] = node
            insertAtHead(node)
            if storage.count > capacity, let oldest = tail {
                removeNode(oldest)
                storage.removeValue(forKey: oldest.key)
            }
        }

        func removeAll() {
            lock.lock()
            defer { lock.unlock() }
            storage.removeAll()
            head = nil
            tail = nil
        }

        private func moveToHead(_ node: Node) {
            guard head !== node else { return }
            removeNode(node)
            insertAtHead(node)
        }

        private func insertAtHead(_ node: Node) {
            node.next = head
            node.prev = nil
            head?.prev = node
            head = node
            if tail == nil {
                tail = node
            }
        }

        private func removeNode(_ node: Node) {
            if let prev = node.prev {
                prev.next = node.next
            } else {
                head = node.next
            }
            if let next = node.next {
                next.prev = node.prev
            } else {
                tail = node.prev
            }
            node.prev = nil
            node.next = nil
        }
    }

    private static let displayCache = LRUCache<Key, Result<DisplayList, ParseError>>(capacity: 256)
    private static let astCache = LRUCache<String, Result<MathList, ParseError>>(capacity: 256)

    #if canImport(Darwin)
    private static let memoryPressureSource: (any DispatchSourceMemoryPressure)? = {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler {
            purgeCaches()
        }
        source.resume()
        return source
    }()
    #endif

    /// Purge all cached ASTs and typeset DisplayLists (e.g. on memory pressure).
    public static func purgeCaches() {
        displayCache.removeAll()
        astCache.removeAll()
    }

    private static func fontProviderIdentifier(_ fonts: any FontProviding) -> ObjectIdentifier {
        if type(of: fonts) is AnyObject.Type {
            return ObjectIdentifier(fonts as AnyObject)
        }
        return ObjectIdentifier(type(of: fonts))
    }

    static func display(
        for latex: String,
        font: MathFont,
        style: TypesettingStyle,
        proposedWidth: CGFloat,
        fonts: any FontProviding = FontRegistry.shared,
        textFallbackFontName: String? = nil
    ) -> Result<DisplayList, ParseError> {
        #if canImport(Darwin)
        _ = memoryPressureSource
        #endif
        let providerID = fontProviderIdentifier(fonts)
        // Inline math (.text, .script, etc.) should never be broken into multiline stacked boxes.
        // It must always typeset at its natural single-line width.
        let effectiveMaxWidth: CGFloat = 0
        let key = Key(
            latex: latex,
            font: font,
            style: style,
            proposedWidth: effectiveMaxWidth.rounded(),
            fontProviderID: providerID,
            textFallbackFontName: textFallbackFontName
        )
        if let cached = displayCache.get(key) {
            return cached
        }

        let parsed: Result<MathList, ParseError>
        if let cachedAST = astCache.get(latex) {
            parsed = cachedAST
        } else {
            do {
                let list = try MathParser.parse(latex)
                parsed = .success(list)
            } catch let error as ParseError {
                parsed = .failure(error)
            } catch {
                parsed = .failure(ParseError(code: .internalError, message: error.localizedDescription))
            }
            astCache.set(latex, parsed)
        }

        let result: Result<DisplayList, ParseError>
        switch parsed {
        case .success(let list):
            let env = MathEnvironment(
                font: font,
                style: style.mathStyle,
                maxWidth: effectiveMaxWidth,
                textFallbackFontName: textFallbackFontName
            )
            result = .success(Typesetter.createDisplay(for: list, environment: env, fonts: fonts))
        case .failure(let error):
            result = .failure(error)
        }

        displayCache.set(key, result)
        return result
    }
}

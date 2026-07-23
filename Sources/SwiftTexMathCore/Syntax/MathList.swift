import Foundation

/// An immutable math list (TeX math list / sequence of noads).
public struct MathList: Sendable, Hashable {
    public var atoms: [MathAtom]

    public init(atoms: [MathAtom] = []) {
        self.atoms = atoms
    }

    public var isEmpty: Bool { atoms.isEmpty }

    public mutating func append(_ atom: MathAtom) {
        atoms.append(atom)
    }

    public func appending(_ atom: MathAtom) -> MathList {
        var copy = self
        copy.append(atom)
        return copy
    }
}

extension MathList: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: MathAtom...) {
        self.atoms = elements
    }
}

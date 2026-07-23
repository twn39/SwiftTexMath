import Foundation

/// Environment and large-operator limit command handlers.
enum EnvironmentCommands {
    static func appendBegin(
        parser: inout MathParser,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        let env = try parser.readBracedName()
        var columnSpec: TableEnvironment.ColumnSpec?
        let baseEnv = env.hasSuffix("*") ? String(env.dropLast()) : env
        if baseEnv == "array" {
            columnSpec = try parser.readColumnSpec()
        } else if env.hasSuffix("*") {
            columnSpec = try parser.readOptionalMatrixAlignment(columnsHint: nil)
        } else if baseEnv == "alignedat" {
            let n = try parser.readBracedInteger()
            columnSpec = TableEnvironment.alignedAtSpec(pairs: n)
        }
        let table = try parser.parseTable(environment: env, columnSpec: columnSpec)
        let atom = MathAtom(kind: .table, payload: .table(table))
        list.append(atom)
        prev = atom
    }

    static func applyLimits(
        command: String,
        list: inout MathList,
        prev: inout MathAtom?
    ) throws {
        guard var op = prev, op.kind == .largeOperator else {
            throw ParseError(code: .invalidLimits, message: "\\limits not after large operator")
        }
        op.payload = .largeOperator(limits: command == "limits")
        list.atoms[list.atoms.count - 1] = op
        prev = op
    }
}

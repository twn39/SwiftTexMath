# `MathAtom.Payload` change checklist

Adding a `Payload` case multiplies work across the pipeline. Prefer lowering sugar
in **Parse** or **`MathNormalizer`** when the layout shape already exists.

## Before adding a case

- [ ] Can this be desugared to an existing payload (box, stack, table, styled, inner)?
- [ ] Does layout need a **distinct** geometry (e.g. flush-right tag, new node type)?

## If you still add a case

Update **all** of:

1. `MathAtom.Payload` (+ nested struct if needed)
2. `MathNormalizer.normalizeAtom` (recurse nested lists)
3. `Typesetter.makeNode` (or dedicated `*Layout.swift`)
4. `LatexSerializer.payloadLatex` (even if best-effort)
5. Any other exhaustive switches (`MacroCommands+OperatorName` flatten, wrap break rules, …)
6. Unit tests: parse → normalize → layout size/clearance
7. Optional: golden PNG if visual
8. `docs/KNOWN_LIMITATIONS.md` if behavior is approximate
9. Rebuild knowledge graph: `codegraph build .`

## Do not

- Special-case TeX sugar only inside Layout when Normalize can lower it
- Skip serializer (callers use `latexString` for debugging)

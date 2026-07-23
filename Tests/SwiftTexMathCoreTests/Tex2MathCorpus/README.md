# tex2math formula corpus

Extracted from `/Users/2342184/programs/tex2math` unit tests:

- `fixtures/` — `tests/fixtures/{baseline,coverage,p1}/*.tex` (46 formulas)
- `catalog.json` — fixtures + unique `let mut input = "..."` formulas from
  `tests/*.rs` and `src/tests/*.rs` (**162** entries total)

Each catalog entry: `{ id, source, latex, expectError }`.

- `expectError=true` — intentionally invalid inputs from `error_recovery.rs`
  (parse success or `ParseError` both count as pass).
- `Tex2MathCorpusTests.unsupportedIDs` is reserved for temporary skips (currently empty;
  Core covers `\tag`, `\genfrac`, `align`, unbraced `\kern`, `\boxed`, …).

Runner: `Tex2MathCorpusTests` (parse + layout, positive size).

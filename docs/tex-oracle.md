# External geometry oracle

How SwiftTexMath compares layout metrics to external engines.

## Goals

1. **Catch pathological geometry** (collapse / blow-up) against an independent engine.
2. **Track grade-A formulas** (simple symbols, light scripts) in a tighter band.
3. Keep absolute LM 20pt goldens as the **hard regression** source of truth for this repo.

## Shared catalog

| File | Role |
|---|---|
| [`scripts/oracle_catalog.json`](../scripts/oracle_catalog.json) | Formula list (`id` + `latex`) for KaTeX and TeX oracles |

---

## Oracle A: KaTeX DomTree (always available with Node)

| Item | Detail |
|---|---|
| Script | [`scripts/katex_oracle.mjs`](../scripts/katex_oracle.mjs) |
| Fixture | `Tests/SwiftTexMathCoreTests/Fixtures/katex_oracle_metrics.json` |
| Tests | `ExternalGeometryOracleTests` |
| Unit | **em** |
| STM side | Latin Modern @ 20pt → pt / 20 |

```bash
node scripts/katex_oracle.mjs -o Tests/SwiftTexMathCoreTests/Fixtures/katex_oracle_metrics.json
swift test --filter ExternalGeometryOracle
```

### Bands (display, STM/KaTeX)

| Grade | Height ratio |
|---|---|
| Hard (all) | 0.25 – 4.0 |
| Grade A | 0.55 – 1.85 for most of the simple set |

Different default fonts → **wider bands**.

### Bands (display, STM/TeX box — same LM OTF)

| Grade | Height ratio | Notes |
|---|---|---|
| Hard (all) | **0.40 – 2.5** | Pathological collapse/blow-up (`TeXGeometryOracleTests`) |
| Grade A | **0.70 – 1.45**, ≤35% outliers | Simple symbols / light scripts |

TeX bands are tighter than KaTeX because both sides use Latin Modern Math. CI
(`.github/workflows/tex-oracle.yml`) installs BasicTeX, regenerates
`tex_oracle_metrics.json` with `status=ok`, and fails if generation or comparison
fails. The committed fixture may still be `unavailable` for local clones without
TeX — tests soft-pass the live suite in that case.

---

## Oracle B: TeX box metrics (LuaTeX / XeTeX skeleton)

| Item | Detail |
|---|---|
| Driver | [`scripts/tex_oracle/tex_oracle.py`](../scripts/tex_oracle/tex_oracle.py) |
| Wrapper | [`scripts/tex_oracle/run.sh`](../scripts/tex_oracle/run.sh) |
| Docs | [`scripts/tex_oracle/README.md`](../scripts/tex_oracle/README.md) |
| CI example | [`scripts/tex_oracle/ci-optional.yml.example`](../scripts/tex_oracle/ci-optional.yml.example) |
| Fixture | `Tests/SwiftTexMathCoreTests/Fixtures/tex_oracle_metrics.json` |
| Tests | `TeXGeometryOracleTests` |
| Font | Bundled `latinmodern-math.otf` (same as STM) |

### Pipeline

```
oracle_catalog.json
  → measure.tex  (\setbox + \write wd/ht/dp)
  → lualatex | xelatex + unicode-math
  → metrics.tsv (sp)
  → tex_oracle_metrics.json (em)
  → TeXGeometryOracleTests vs MathRenderer (LM 20pt)
```

### Commands

```bash
# Safe probe (exit 0 even if TeX missing)
python3 scripts/tex_oracle/tex_oracle.py --check-deps

# Generate .tex only
python3 scripts/tex_oracle/tex_oracle.py --dry-run -w /tmp/stm_tex_oracle

# Full generate → fixture (requires TeX)
python3 scripts/tex_oracle/tex_oracle.py --write-fixture
# or
./scripts/tex_oracle/run.sh

# If TeX missing but you want a placeholder JSON
python3 scripts/tex_oracle/tex_oracle.py --allow-unavailable --write-fixture

swift test --filter TeXGeometryOracle
```

### Fixture `status` field

| status | Meaning | Tests |
|---|---|---|
| `ok` | Metrics measured | Hard height/width bands (tighter than KaTeX) |
| `unavailable` | No engine/font (committed default) | Soft-pass skeleton only |
| `compile_failed` / `empty` | TeX ran but failed | Soft-pass + log tail in JSON |

### Why box metrics (not PDF crop)?

`\setbox0=\hbox{$...$}` / `\displaystyle` records TeX’s own math list dimensions
(`\wd` / `\ht` / `\dp`), which map cleanly to STM `width` / `ascent` / `descent`
without depending on page shipout or PDF tooling (`pdfinfo`, Ghostscript, …).

### Suggested TeX Live packages

- `latex-bin`, `luatex` or `xetex`
- `unicode-math`, `fontspec`, `amsmath`, `geometry`

### CI (configured)

| Workflow | File | Role |
|---|---|---|
| **CI** | [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | Swift build + full tests; **no TeX** |
| **TeX Oracle** | [`.github/workflows/tex-oracle.yml`](../.github/workflows/tex-oracle.yml) | BasicTeX + generate fixture + `TeXGeometryOracle` |

TeX Oracle runs on path-filtered PR/push, weekly schedule, and manual dispatch.
It caches the BasicTeX tree and **fails the job** if generation does not produce
`status=ok` (so the oracle stays honest when TeX is installed on the runner).
---

## Related

- [layout-geometry-status.md](layout-geometry-status.md) — absolute LM goldens
- [math-constants-coverage.md](math-constants-coverage.md) — MATH table wiring
- `KaTeXCrossValidationTests` — broader soft KaTeX corpus

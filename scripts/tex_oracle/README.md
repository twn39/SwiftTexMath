# TeX geometry oracle

Measure formula boxes with **LuaTeX / XeTeX + unicode-math** using the same OTF
as SwiftTexMath (`latinmodern-math.otf`), emit JSON consumed by unit tests.

## Requirements

| Tool | Purpose |
|---|---|
| `lualatex` or `xelatex` | Compile measure document |
| `unicode-math` + `fontspec` | Load OpenType math font |
| `amsmath` | Environments / macros in the catalog |
| Python 3.9+ | Driver script |

macOS: install [MacTeX](https://www.tug.org/mactex/) or BasicTeX + `tlmgr install unicode-math fontspec amsmath`.

## Quick start

```bash
# Probe (safe when TeX is absent)
python3 scripts/tex_oracle/tex_oracle.py --check-deps

# Generate TeX only
python3 scripts/tex_oracle/tex_oracle.py --dry-run -w /tmp/stm_tex_oracle

# Full run → Tests/.../Fixtures/tex_oracle_metrics.json
./scripts/tex_oracle/run.sh
# or:
python3 scripts/tex_oracle/tex_oracle.py --write-fixture

# Tests (skip soft-pass when status != ok)
swift test --filter TeXGeometryOracle
```

## Output schema

Same family as KaTeX oracle:

```json
{
  "generator": "scripts/tex_oracle/tex_oracle.py",
  "status": "ok | unavailable | compile_failed | empty",
  "unit": "em",
  "fontSizePt": 10,
  "engine": "lualatex",
  "font": "/path/to/latinmodern-math.otf",
  "measuredCount": 40,
  "items": [
    {
      "id": "frac_12",
      "latex": "\\frac{1}{2}",
      "display": { "heightEm": 1.2, "depthEm": 0.6, "totalHeightEm": 1.8, "widthEm": 0.5 },
      "text": { "heightEm": 0.8, "depthEm": 0.3, "totalHeightEm": 1.1, "widthEm": 0.4 }
    }
  ]
}
```

## How measurement works

1. Driver expands `scripts/oracle_catalog.json` into `measure.tex`.
2. Each formula is boxed twice: `$...$` and `$\displaystyle ...$`.
3. TeX writes `id mode wd ht dp` in **scaled points** to `metrics.tsv`.
4. Driver converts sp → em with `1em = fontSizePt` (default 10pt document class).

This measures the **math list box**, not page crop marks — closest practical
analogue to STM `DisplayList` ascent/descent/width without PDF parsing.

## CI

Production workflow: **[`.github/workflows/tex-oracle.yml`](../../.github/workflows/tex-oracle.yml)**

| | |
|---|---|
| Runner | `macos-15` (same as main Swift CI; CoreGraphics) |
| TeX | Homebrew **BasicTeX** + `tlmgr` packages (cached) |
| Font | Repo bundle `latinmodern-math.otf` |
| Tests | `swift test --filter TeXGeometryOracle` |
| Triggers | PR/push (path-filtered), weekly cron, `workflow_dispatch` |

Main PR gate remains [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) (`swift test` only, no TeX install).

## Related

- Shared catalog: [`../oracle_catalog.json`](../oracle_catalog.json)
- KaTeX oracle: [`../katex_oracle.mjs`](../katex_oracle.mjs)
- Design notes: [`../../docs/tex-oracle.md`](../../docs/tex-oracle.md)

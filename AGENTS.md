# AGENTS.md

> Project instructions, architectural constraints, and operational harness for AI coding agents working on **SwiftTexMath**.

---

## 1. Project Overview & Tech Stack

**SwiftTexMath** is a native, high-performance TeX math typesetting engine for Apple platforms written in Swift with **zero external dependencies**.

- **Language & Runtime**: Swift 6.1+ (Strict Concurrency ready, `Sendable` value types).
- **Target Platforms**: macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+.
- **Pipeline Architecture**: Unidirectional compiler-style pipeline (**`Parse → Normalize → Typeset → Draw`**).
- **Products**:
  - `SwiftTexMathCore`: Headless parser, typesetter, CoreGraphics renderer, and vector/raster exporters (`MathImage`, `MathPDF`, `MathSVG`).
  - `SwiftTexMath`: Native UI framework (SwiftUI `Math` view, UIKit/AppKit `MathLabel` / `HostedMathLabel`, environment modifiers, and layout cache).

---

## 2. Repository Structure & Key Paths

```
SwiftTexMath/
├── Sources/
│   ├── SwiftTexMathCore/         # Headless TeX pipeline
│   │   ├── Parse/                # Recursive-descent parser & *Commands family modules
│   │   ├── Syntax/               # AST structures (MathAtom, MathList, AtomFactory, serializers)
│   │   ├── Normalize/            # Pre-layout AST lowering (number fusion, Bin→Ord, boundary hygiene)
│   │   ├── Layout/               # TeX Appendix-G engine (Typesetter, TableLayout, WrapLayout)
│   │   ├── Display/              # DisplayList generation, IR tree, CoreGraphics path drawing
│   │   ├── Font/                 # OpenType MATH metric tables, FontRegistry, bundled fonts
│   │   ├── MathRenderer.swift    # Thin façade orchestrating the 4-stage pipeline
│   │   └── MathImage.swift, MathPDF.swift, MathSVG.swift # Multi-format exporters
│   └── SwiftTexMath/             # Apple UI Layer (SwiftUI / UIKit / AppKit components)
├── Tests/
│   ├── SwiftTexMathCoreTests/    # Unit, oracle, cross-validation, font matrix & snapshot tests
│   └── SwiftTexMathTests/        # UI component & SwiftUI environment tests
├── docs/                         # Specifications, limitations, and geometry baselines
├── scripts/                      # External geometry oracles (KaTeX & LuaTeX/XeTeX)
└── .codegraph/                   # Codebase Knowledge Graph & architectural index
```

---

## 3. Essential Commands & Development Harness

All agents **MUST** use the following canonical commands for building, testing, and graph synchronization:

### Build & Test
```bash
# Build all targets
swift build

# Run entire test suite (530+ tests across 37 suites)
swift test

# Run a specific test suite or test case
swift test --filter KaTeXCrossValidationTests
swift test --filter LayoutGeometryTests

# Re-record snapshot baselines (SVG, PNG, DisplayTree, UI)
RECORD_SNAPSHOTS=1 swift test
```

### CLI Demo & Export
```bash
# Print layout metrics for a formula
swift run SwiftTexMathDemo

# Render directly to a PNG bitmap file
swift run SwiftTexMathDemo 'E = mc^2' /tmp/math.png
```

### Oracles & Knowledge Graph
```bash
# Rebuild Codebase Knowledge Graph
codegraph build .

# Run KaTeX oracle generator
node scripts/katex_oracle.mjs -o Tests/SwiftTexMathCoreTests/Fixtures/katex_oracle_metrics.json

# Run TeX box metrics oracle (requires TeX Live / BasicTeX)
python3 scripts/tex_oracle/tex_oracle.py --write-fixture
```

---

## 4. Architectural Rules & Pipeline Disciplines

Agents modifying code in this repository **MUST** adhere to these core principles:

### 1. Strict Pipeline Order & Thin Façade
- Pipeline stages are strictly ordered: **`parse → normalize → typeset → draw`**.
- Keep `MathRenderer` a **thin façade** (~111–150 LOC maximum). Do **NOT** add layout formulas, math spacing constants, or TeX parsing logic directly to `MathRenderer`.
- Exporters (`MathImage`, `MathPDF`, `MathSVG`) and UI wrappers must call through the standard pipeline without bypassing stages.

### 2. AST Payload & Normalization Discipline
- **Prefer lowering in `MathNormalizer` or `Parse` over introducing new `MathAtom.Payload` cases.**
- Before adding any new `Payload` case, consult and complete [docs/PAYLOAD_CHECKLIST.md](docs/PAYLOAD_CHECKLIST.md).
- Any new `Payload` requires exhaustive updates across:
  1. `MathAtom.Payload` enum definition
  2. `MathNormalizer.normalizeAtom` (nested list recursion)
  3. `Typesetter.makeNode` (or specialized `*Layout.swift`)
  4. `LatexSerializer.payloadLatex`
  5. Exhaustive pattern matches (`WrapLayout`, `MacroCommands+OperatorName`, etc.)
  6. Pipeline unit tests + clearance tests

### 3. Modular Parse Command Registration
- New LaTeX commands belong in dedicated `Sources/SwiftTexMathCore/Parse/*Commands.swift` modules (e.g. `FractionCommands`, `DelimiterCommands`, `StyleCommands`, `BoxCommands`, `EnvironmentCommands`).
- Register commands in the centralized dispatch table; do not write ad-hoc branching in `MathParser.swift` or layout modules.

### 4. Font Metrics & Injection
- Always accept and inject `any FontProviding` / `FontMetricsProtocol` on layout and drawing paths.
- Avoid hardcoding `FontRegistry.shared` inside core layout logic so that test suites and custom font loaders remain fully isolated.

### 5. Recursion Budget & Concurrency
- Respect `MathEnvironment.maxRecursionDepth` and `DisplayTraversal.defaultMaxDepth` (default 128) across all recursive tree walkers to prevent stack exhaustion on malicious/deeply nested inputs.
- Keep all AST models, options, and layouts strictly `Sendable` and thread-safe.

---

## 5. Knowledge Graph Guidelines (`.codegraph/`)

This project maintains an automated knowledge graph to assist AI reasoning:

1. **Prioritize the Knowledge Graph**:
   - Before answering architectural questions or designing large changes, read [.codegraph/README.md](.codegraph/README.md) to inspect God nodes, logical communities, and dependencies.
   - Use [.codegraph/components/](.codegraph/components/) and [.codegraph/nodes/](.codegraph/nodes/) for token-efficient navigation.
2. **AI Architectural Insights**:
   - Review and maintain the `## AI Architectural Insights` section in [.codegraph/README.md](.codegraph/README.md). Keep it synchronized with [.codegraph/AGENT_PROMPT.md](.codegraph/AGENT_PROMPT.md) during major updates.
3. **Keep Graph Synchronized**:
   - Remind the user to run `codegraph build .` (or run it directly) after creating, deleting, or refactoring code files.

---

## 6. Definition of Done (DoD)

A task is considered complete only when:
1. **Tests Pass**: `swift test` exits with code 0 (all 530+ tests across 37 suites pass).
2. **No Regression**: Concurrency, memory safety, and layout clearance invariant suites pass.
3. **Documentation Updated**:
   - Approximate behaviors or intentional gaps documented in [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).
   - Layout metric updates or baseline changes recorded in [docs/layout-geometry-status.md](docs/layout-geometry-status.md).
   - New MATH table constant wiring updated in [docs/math-constants-coverage.md](docs/math-constants-coverage.md).
4. **Clean Git State**: No unexpected scratch files or broken formatting.

## codegraph-gen

This project maintains a codebase knowledge graph at `.codegraph/`.

### Guidelines for AI Agents (Antigravity, Claude Code, Cursor, Roo Code, etc.)

You MUST follow these rules when working in this codebase:

1. **Prioritize the Knowledge Graph**:
   - Before answering architecture, design, or codebase structure questions, you **MUST** read [.codegraph/README.md](.codegraph/README.md) to understand the system overview, god nodes, and logical community structure.
   - Use [.codegraph/components/](.codegraph/components/) and [.codegraph/nodes/](.codegraph/nodes/) to navigate component boundaries, file relationships, and symbol definitions. This is much faster and more token-efficient than reading raw source files directly.

2. **AI Architectural Insights**:
   - Check [.codegraph/README.md](.codegraph/README.md) for a section titled `AI Architectural Insights`.
   - If this section is missing, incomplete, or contains placeholders, read [.codegraph/AGENT_PROMPT.md](.codegraph/AGENT_PROMPT.md), perform a deep architectural analysis of the project, and write your report into that section. Do not overwrite other sections.

3. **Keep Graph Sync'd**:
   - Whenever you create, delete, or modify code files, you **SHOULD** remind the user to run `codegraph build .` to rebuild the knowledge graph and keep it current.
   - When running the build command, exclude irrelevant or generated directories (e.g., third-party dependencies, build folders, or documentation) using the `-e`/`--exclude` flag to keep the graph focused and clean (e.g., `codegraph build . -e third_party/`).

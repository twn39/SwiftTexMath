#!/usr/bin/env node
/**
 * KaTeX geometry oracle — emits em metrics for a formula catalog.
 *
 * Usage:
 *   node scripts/katex_oracle.mjs > Tests/SwiftTexMathCoreTests/Fixtures/katex_oracle_metrics.json
 *   node scripts/katex_oracle.mjs --check path/to/file.json
 *
 * Requires: `katex` (npm) available to Node.
 * TeX (LuaTeX/XeTeX) path is reserved for future extension (see docs/tex-oracle.md).
 */
import { createRequire } from 'module';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
let katex;
try {
  katex = require('katex');
} catch {
  console.error('katex not found. Install with: npm install katex');
  process.exit(1);
}

/** Prefer shared scripts/oracle_catalog.json (also used by TeX oracle). */
function loadCatalog() {
  const shared = join(__dirname, 'oracle_catalog.json');
  if (existsSync(shared)) {
    const data = JSON.parse(readFileSync(shared, 'utf8'));
    if (Array.isArray(data.items) && data.items.length) return data.items;
  }
  return null;
}

const catalog = loadCatalog() ?? [
  { id: 'var_x', latex: 'x' },
  { id: 'frac_12', latex: String.raw`\frac{1}{2}` },
];

function widthOf(node) {
  if (!node) return 0;
  if (typeof node.width === 'number' && Number.isFinite(node.width)) return node.width;
  if (Array.isArray(node.children) && node.children.length) {
    return node.children.reduce((s, c) => s + widthOf(c), 0);
  }
  return 0;
}

function metrics(latex, displayMode) {
  const tree = katex.__renderToDomTree(latex, {
    displayMode,
    throwOnError: true,
    strict: 'ignore',
  });
  const widthEm = typeof tree.width === 'number' ? tree.width : widthOf(tree);
  return {
    heightEm: tree.height,
    depthEm: tree.depth,
    totalHeightEm: tree.height + tree.depth,
    widthEm,
  };
}

function build() {
  const items = [];
  for (const entry of catalog) {
    try {
      items.push({
        id: entry.id,
        latex: entry.latex,
        display: metrics(entry.latex, true),
        text: metrics(entry.latex, false),
      });
    } catch (err) {
      items.push({
        id: entry.id,
        latex: entry.latex,
        error: String(err && err.message ? err.message : err),
      });
    }
  }
  return {
    generator: 'katex_oracle.mjs',
    katexVersion: katex.version || 'unknown',
    unit: 'em',
    note: 'Heights/depths from katex.__renderToDomTree; width summed from DomTree when missing on root.',
    items,
  };
}

const args = process.argv.slice(2);
if (args[0] === '--check' && args[1]) {
  const expected = JSON.parse(readFileSync(args[1], 'utf8'));
  const actual = build();
  if (expected.items?.length !== actual.items?.length) {
    console.error('count mismatch', expected.items?.length, actual.items?.length);
    process.exit(2);
  }
  console.log('ok', actual.items.length, 'items katex', actual.katexVersion);
  process.exit(0);
}

const out = JSON.stringify(build(), null, 2);
if (args[0] === '-o' && args[1]) {
  writeFileSync(args[1], out + '\n');
  console.error('wrote', args[1]);
} else {
  process.stdout.write(out + '\n');
}

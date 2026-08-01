#!/usr/bin/env bash
# Convenience wrapper for the TeX geometry oracle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 scripts/tex_oracle/tex_oracle.py --check-deps

if ! python3 scripts/tex_oracle/tex_oracle.py --check-deps | python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("ok") else 1)'; then
  echo "TeX deps missing — writing status=unavailable fixture (exit 0)." >&2
  python3 scripts/tex_oracle/tex_oracle.py --allow-unavailable --write-fixture
  exit 0
fi

python3 scripts/tex_oracle/tex_oracle.py --write-fixture "$@"
echo "Run: swift test --filter TeXGeometryOracle"

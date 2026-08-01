#!/usr/bin/env python3
"""
TeX geometry oracle skeleton for SwiftTexMath.

Measures formula boxes with LuaTeX/XeTeX + unicode-math, writing the same JSON
shape as scripts/katex_oracle.mjs so Swift tests can compare STM layout to TeX.

Pipeline:
  catalog JSON
    → generate measure.tex (\\setbox + \\write metrics)
    → lualatex | xelatex (nonstopmode)
    → parse metrics.tsv (sp → em)
    → katex-compatible oracle JSON

Usage:
  # Dependency probe (always succeeds; exit 0 if TeX missing)
  python3 scripts/tex_oracle/tex_oracle.py --check-deps

  # Generate fixture (requires TeX + unicode-math + font)
  python3 scripts/tex_oracle/tex_oracle.py \\
      -o Tests/SwiftTexMathCoreTests/Fixtures/tex_oracle_metrics.json

  # Dry-run: write .tex only, do not compile
  python3 scripts/tex_oracle/tex_oracle.py --dry-run -w /tmp/tex_oracle_work

Environment:
  TEX_ORACLE_ENGINE   lualatex | xelatex | auto (default: auto)
  TEX_ORACLE_FONT     path to latinmodern-math.otf (optional)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Optional


# 1 pt = 65536 sp (TeX scaled points)
SP_PER_PT = 65536.0

ROOT = Path(__file__).resolve().parents[2]  # package root
DEFAULT_CATALOG = ROOT / "scripts" / "oracle_catalog.json"
DEFAULT_FONT = (
    ROOT
    / "Sources"
    / "SwiftTexMathCore"
    / "Resources"
    / "mathFonts.bundle"
    / "latinmodern-math.otf"
)
DEFAULT_OUT = (
    ROOT
    / "Tests"
    / "SwiftTexMathCoreTests"
    / "Fixtures"
    / "tex_oracle_metrics.json"
)


@dataclass
class Deps:
    engine: Optional[str]
    engine_path: Optional[str]
    font: Optional[Path]
    notes: list[str]

    @property
    def ok(self) -> bool:
        return self.engine_path is not None and self.font is not None and self.font.is_file()


def find_engine(preferred: str = "auto") -> tuple[Optional[str], Optional[str]]:
    order: list[str]
    if preferred == "auto":
        order = ["lualatex", "xelatex"]
    else:
        order = [preferred]
    for name in order:
        path = shutil.which(name)
        if path:
            return name, path
    # Common macOS TeX Live location not always on PATH
    for name in order:
        candidate = Path("/Library/TeX/texbin") / name
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return name, str(candidate)
    return None, None


def resolve_font(explicit: Optional[str]) -> Optional[Path]:
    if explicit:
        p = Path(explicit).expanduser().resolve()
        return p if p.is_file() else None
    env = os.environ.get("TEX_ORACLE_FONT")
    if env:
        p = Path(env).expanduser().resolve()
        return p if p.is_file() else None
    if DEFAULT_FONT.is_file():
        return DEFAULT_FONT.resolve()
    return None


def check_deps(engine_pref: str = "auto", font: Optional[str] = None) -> Deps:
    notes: list[str] = []
    eng_name, eng_path = find_engine(engine_pref)
    if not eng_path:
        notes.append(
            "No lualatex/xelatex on PATH (also checked /Library/TeX/texbin). "
            "Install MacTeX / TeX Live and ensure unicode-math is available."
        )
    font_path = resolve_font(font)
    if not font_path:
        notes.append(
            f"Math font not found (default {DEFAULT_FONT}). "
            "Pass --font or set TEX_ORACLE_FONT."
        )
    else:
        notes.append(f"font={font_path}")
    if eng_path:
        notes.append(f"engine={eng_name} ({eng_path})")
    return Deps(engine=eng_name, engine_path=eng_path, font=font_path, notes=notes)


def load_catalog(path: Path) -> list[dict[str, str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    items = data.get("items") if isinstance(data, dict) else data
    if not isinstance(items, list) or not items:
        raise SystemExit(f"empty or invalid catalog: {path}")
    out: list[dict[str, str]] = []
    for it in items:
        if not isinstance(it, dict):
            continue
        iid = str(it.get("id", "")).strip()
        latex = str(it.get("latex", ""))
        if iid and latex is not None:
            out.append({"id": iid, "latex": latex})
    if not out:
        raise SystemExit(f"no usable items in {path}")
    return out


def tex_escape_for_verb(s: str) -> str:
    """Escape for \\detokenize / write-safe id tokens (ids are already safe)."""
    return s


def latex_escape_math(s: str) -> str:
    """Keep latex as-is inside math; only strip nulls / normalize newlines."""
    return s.replace("\x00", "").replace("\r\n", "\n").replace("\r", "\n")


def generate_tex(
    items: Iterable[dict[str, str]],
    font: Path,
    font_size_pt: float = 10.0,
) -> str:
    """
    Build a standalone document that measures each formula in text and display
    math, writing one TSV line per measurement to metrics.tsv.

    Formulas are inlined in the document body (not macro arguments) so
    ``\\frac`` and friends keep correct catcodes.
    """
    font_dir = font.parent.as_posix()
    if not font_dir.endswith("/"):
        font_dir += "/"
    font_name = font.name  # e.g. latinmodern-math.otf

    body_lines: list[str] = []
    for it in items:
        iid = it["id"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", iid):
            raise SystemExit(f"unsafe catalog id for TeX write: {iid!r}")
        latex = latex_escape_math(it["latex"])
        body_lines.append(f"% --- {iid} ---")
        body_lines.append(rf"\setbox0=\hbox{{${latex}$}}")
        body_lines.append(
            rf"\immediate\write\stmmetrics{{{iid} text \number\wd0 \number\ht0 \number\dp0}}"
        )
        body_lines.append(rf"\setbox0=\hbox{{$\displaystyle {latex}$}}")
        body_lines.append(
            rf"\immediate\write\stmmetrics{{{iid} display \number\wd0 \number\ht0 \number\dp0}}"
        )
        body_lines.append("")

    preamble = rf"""%% Auto-generated by scripts/tex_oracle/tex_oracle.py — do not edit by hand.
\documentclass[{font_size_pt:.0f}pt]{{article}}
\usepackage[margin=1in]{{geometry}}
\usepackage{{amsmath,amssymb}}
\usepackage{{unicode-math}}
\setmathfont{{{font_name}}}[
  Path={{{font_dir}}},
  Extension={{}},
]
\pagestyle{{empty}}
\newwrite\stmmetrics
\immediate\openout\stmmetrics=metrics.tsv
% metrics.tsv columns: id mode width_sp height_sp depth_sp
\begin{{document}}
"""
    ending = r"""
\immediate\closeout\stmmetrics
\end{document}
"""
    return preamble + "\n".join(body_lines) + ending


def sp_to_em(sp: float, font_size_pt: float) -> float:
    """Convert TeX sp to em at the document font size (1em = font_size_pt)."""
    pt = sp / SP_PER_PT
    return pt / font_size_pt


def parse_metrics_tsv(path: Path, font_size_pt: float) -> dict[str, dict[str, Any]]:
    """
    Returns { id: { "display": Metrics, "text": Metrics } }.
    """
    by_id: dict[str, dict[str, Any]] = {}
    if not path.is_file():
        return by_id
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("%"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        iid, mode, w_s, h_s, d_s = parts[0], parts[1], parts[2], parts[3], parts[4]
        try:
            w_sp, h_sp, d_sp = float(w_s), float(h_s), float(d_s)
        except ValueError:
            continue
        metrics = {
            "heightEm": sp_to_em(h_sp, font_size_pt),
            "depthEm": sp_to_em(d_sp, font_size_pt),
            "totalHeightEm": sp_to_em(h_sp + d_sp, font_size_pt),
            "widthEm": sp_to_em(w_sp, font_size_pt),
            "widthSp": int(w_sp),
            "heightSp": int(h_sp),
            "depthSp": int(d_sp),
        }
        slot = by_id.setdefault(iid, {})
        if mode in ("display", "text"):
            slot[mode] = metrics
    return by_id


def run_tex(
    engine_path: str,
    work: Path,
    tex_name: str = "measure.tex",
    timeout: int = 180,
) -> subprocess.CompletedProcess[str]:
    # Interaction nonstop; cwd = work so metrics.tsv lands there.
    cmd = [
        engine_path,
        "-interaction=nonstopmode",
        "-halt-on-error",
        tex_name,
    ]
    return subprocess.run(
        cmd,
        cwd=str(work),
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def build_result(
    items: list[dict[str, str]],
    measured: dict[str, dict[str, Any]],
    deps: Deps,
    font_size_pt: float,
    status: str,
    compile_log: Optional[str] = None,
) -> dict[str, Any]:
    out_items: list[dict[str, Any]] = []
    for it in items:
        iid = it["id"]
        entry: dict[str, Any] = {"id": iid, "latex": it["latex"]}
        m = measured.get(iid, {})
        if "display" in m:
            entry["display"] = {
                k: m["display"][k]
                for k in ("heightEm", "depthEm", "totalHeightEm", "widthEm")
            }
        if "text" in m:
            entry["text"] = {
                k: m["text"][k]
                for k in ("heightEm", "depthEm", "totalHeightEm", "widthEm")
            }
        if "display" not in entry and "text" not in entry:
            entry["error"] = "not measured"
        out_items.append(entry)

    measured_n = sum(1 for x in out_items if "display" in x or "text" in x)
    return {
        "generator": "scripts/tex_oracle/tex_oracle.py",
        "status": status,
        "unit": "em",
        "fontSizePt": font_size_pt,
        "engine": deps.engine,
        "enginePath": deps.engine_path,
        "font": str(deps.font) if deps.font else None,
        "note": (
            "Box metrics from TeX \\setbox (\\wd/\\ht/\\dp) in text ($) and "
            "display ($\\displaystyle$). 1em = document font size. "
            "Prefer same OTF as SwiftTexMath for fair comparison."
        ),
        "depsNotes": deps.notes,
        "measuredCount": measured_n,
        "itemCount": len(out_items),
        "compileLogTail": (compile_log or "")[-4000:] if compile_log else None,
        "items": out_items,
    }


def unavailable_result(
    items: list[dict[str, str]],
    deps: Deps,
    font_size_pt: float,
) -> dict[str, Any]:
    return build_result(
        items,
        measured={},
        deps=deps,
        font_size_pt=font_size_pt,
        status="unavailable",
    )


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="SwiftTexMath TeX geometry oracle")
    parser.add_argument(
        "--catalog",
        type=Path,
        default=DEFAULT_CATALOG,
        help=f"formula catalog JSON (default: {DEFAULT_CATALOG})",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="write oracle JSON (default: stdout, or fixture path with --write-fixture)",
    )
    parser.add_argument(
        "--write-fixture",
        action="store_true",
        help=f"write to default fixture path {DEFAULT_OUT}",
    )
    parser.add_argument(
        "--font",
        type=str,
        default=None,
        help="path to latinmodern-math.otf (or other unicode-math OTF)",
    )
    parser.add_argument(
        "--engine",
        choices=("auto", "lualatex", "xelatex"),
        default=os.environ.get("TEX_ORACLE_ENGINE", "auto"),
    )
    parser.add_argument(
        "--font-size",
        type=float,
        default=10.0,
        help="document font size in pt (metrics reported in em of this size)",
    )
    parser.add_argument(
        "-w",
        "--work-dir",
        type=Path,
        default=None,
        help="working directory for TeX run (default: temp dir)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="only generate measure.tex; do not compile",
    )
    parser.add_argument(
        "--check-deps",
        action="store_true",
        help="print dependency status and exit 0 (missing TeX is not an error)",
    )
    parser.add_argument(
        "--allow-unavailable",
        action="store_true",
        help="if TeX missing, still write status=unavailable JSON and exit 0",
    )
    parser.add_argument(
        "--keep-work",
        action="store_true",
        help="do not delete work dir when using a temp directory",
    )
    args = parser.parse_args(argv)

    deps = check_deps(args.engine, args.font)

    if args.check_deps:
        print(json.dumps({
            "ok": deps.ok,
            "engine": deps.engine,
            "enginePath": deps.engine_path,
            "font": str(deps.font) if deps.font else None,
            "notes": deps.notes,
        }, indent=2))
        return 0

    items = load_catalog(args.catalog)

    out_path: Optional[Path] = args.output
    if args.write_fixture:
        out_path = DEFAULT_OUT

    # Dry-run only needs the math font (to embed Path= in the generated .tex).
    if args.dry_run:
        font = deps.font or resolve_font(args.font)
        if font is None:
            print("dry-run requires a math font (--font / TEX_ORACLE_FONT / bundle).", file=sys.stderr)
            return 2
        own_temp = args.work_dir is None
        work = Path(tempfile.mkdtemp(prefix="stm_tex_oracle_")) if own_temp else args.work_dir
        assert work is not None
        work.mkdir(parents=True, exist_ok=True)
        tex_path = work / "measure.tex"
        tex_path.write_text(
            generate_tex(items, font, font_size_pt=args.font_size),
            encoding="utf-8",
        )
        print(f"wrote {tex_path} ({len(items)} formulas)", file=sys.stderr)
        print(f"dry-run: skip compile in {work}", file=sys.stderr)
        if own_temp and not args.keep_work:
            print(f"(temp work dir kept only with --keep-work; path was {work})", file=sys.stderr)
            # Keep work for inspection when user passed -w; if temp, still keep on dry-run
            # so the path printed above remains valid.
        return 0

    if not deps.ok:
        msg = "TeX oracle dependencies missing:\n  - " + "\n  - ".join(deps.notes)
        # Default: write unavailable JSON when targeting the fixture path.
        if args.allow_unavailable or out_path is not None:
            result = unavailable_result(items, deps, args.font_size)
            text = json.dumps(result, indent=2) + "\n"
            if out_path:
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_text(text, encoding="utf-8")
                print(f"wrote unavailable fixture: {out_path}", file=sys.stderr)
            else:
                sys.stdout.write(text)
            print(msg, file=sys.stderr)
            return 0 if (args.allow_unavailable or args.write_fixture) else 2
        print(msg, file=sys.stderr)
        return 2

    assert deps.font is not None and deps.engine_path is not None

    own_temp = args.work_dir is None
    work = Path(tempfile.mkdtemp(prefix="stm_tex_oracle_")) if own_temp else args.work_dir
    assert work is not None
    work.mkdir(parents=True, exist_ok=True)

    try:
        tex_source = generate_tex(items, deps.font, font_size_pt=args.font_size)
        tex_path = work / "measure.tex"
        tex_path.write_text(tex_source, encoding="utf-8")
        print(f"wrote {tex_path}", file=sys.stderr)

        print(f"running {deps.engine} …", file=sys.stderr)
        proc = run_tex(deps.engine_path, work)
        log = (proc.stdout or "") + "\n" + (proc.stderr or "")
        log_path = work / "measure.log"
        if log_path.is_file():
            log = log_path.read_text(encoding="utf-8", errors="replace")

        tsv = work / "metrics.tsv"
        measured = parse_metrics_tsv(tsv, args.font_size)

        if proc.returncode != 0 and not measured:
            result = build_result(
                items,
                measured={},
                deps=deps,
                font_size_pt=args.font_size,
                status="compile_failed",
                compile_log=log,
            )
            text = json.dumps(result, indent=2) + "\n"
            if out_path:
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_text(text, encoding="utf-8")
            else:
                sys.stdout.write(text)
            print(f"TeX compile failed (code {proc.returncode}). Log tail:", file=sys.stderr)
            print(log[-2000:], file=sys.stderr)
            return 3

        status = "ok" if measured else "empty"
        result = build_result(
            items,
            measured,
            deps=deps,
            font_size_pt=args.font_size,
            status=status,
            compile_log=log if status != "ok" else None,
        )
        text = json.dumps(result, indent=2) + "\n"
        if out_path:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(text, encoding="utf-8")
            print(
                f"wrote {out_path} (measured {result['measuredCount']}/{result['itemCount']})",
                file=sys.stderr,
            )
        else:
            sys.stdout.write(text)
        return 0 if status == "ok" else 3
    finally:
        if own_temp and work is not None and not args.keep_work:
            shutil.rmtree(work, ignore_errors=True)
        elif own_temp and args.keep_work and work is not None:
            print(f"kept work dir: {work}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())

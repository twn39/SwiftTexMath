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
    font_basename: str = "latinmodern-math",
    font_size_pt: float = 10.0,
    font_path_dir: str = "./",
) -> str:
    """
    Build a standalone document that measures each formula in text and display
    math, writing one TSV line per measurement to metrics.tsv.

    Expects ``latinmodern-math.otf`` to live in ``font_path_dir`` (usually the
    TeX working directory after the driver copies the bundled font there).
    Formulas are inlined so ``\\frac`` keeps correct catcodes.
    """
    if not font_path_dir.endswith("/"):
        font_path_dir = font_path_dir + "/"

    body_lines: list[str] = []
    for it in items:
        iid = it["id"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", iid):
            raise SystemExit(f"unsafe catalog id for TeX write: {iid!r}")
        latex = latex_escape_math(it["latex"])
        # Isolate each measurement.
        # IMPORTANT: after ``\number\wd0`` a plain space is *eaten* as the number
        # terminator and does NOT appear in the written file — use ``\space`` or
        # ``|`` delimiters so the parser sees five fields.
        body_lines.append(f"% --- {iid} ---")
        body_lines.append(r"\begingroup")
        body_lines.append(rf"\setbox0=\hbox{{${latex}$}}%")
        body_lines.append(
            rf"\immediate\write\stmmetrics{{{iid}|text|\number\wd0|\number\ht0|\number\dp0}}%"
        )
        body_lines.append(rf"\setbox0=\hbox{{$\displaystyle {latex}$}}%")
        body_lines.append(
            rf"\immediate\write\stmmetrics{{{iid}|display|\number\wd0|\number\ht0|\number\dp0}}%"
        )
        body_lines.append(r"\endgroup")
        body_lines.append("")

    # Do NOT load amssymb with unicode-math (conflicts). Font is local OTF copy.
    # Extension=.otf + basename without extension is the reliable fontspec form.
    preamble = rf"""%% Auto-generated by scripts/tex_oracle/tex_oracle.py — do not edit by hand.
\documentclass[{font_size_pt:.0f}pt]{{article}}
\usepackage{{amsmath}}
\usepackage{{unicode-math}}
\setmathfont{{{font_basename}}}[
  Path={{{font_path_dir}}},
  Extension={{.otf}}
]
\pagestyle{{empty}}
\newwrite\stmmetrics
\immediate\openout\stmmetrics=\jobname-metrics.tsv
% columns: id|mode|width_sp|height_sp|depth_sp  (sp integers; | avoids TeX space-eating)
\begin{{document}}
"""
    ending = r"""
\immediate\closeout\stmmetrics
\null
\end{document}
"""
    return preamble + "\n".join(body_lines) + ending


def generate_single_item_tex(
    item: dict[str, str],
    font_basename: str = "latinmodern-math",
    font_size_pt: float = 10.0,
    font_path_dir: str = "./",
) -> str:
    return generate_tex(
        [item],
        font_basename=font_basename,
        font_size_pt=font_size_pt,
        font_path_dir=font_path_dir,
    )


def sp_to_em(sp: float, font_size_pt: float) -> float:
    """Convert TeX sp to em at the document font size (1em = font_size_pt)."""
    pt = sp / SP_PER_PT
    return pt / font_size_pt


def _parse_dim_token(token: str) -> Optional[tuple[float, str]]:
    """
    Parse a TeX dimension token into (value, unit).

    Accepts:
      - pure sp integers from ``\\number\\wd0``: ``655360``
      - ``\\the\\wd0`` style: ``10.5pt`` / ``10.5sp``
    """
    token = token.strip()
    if not token:
        return None
    m = re.fullmatch(r"([+-]?(?:\d+(?:\.\d*)?|\.\d+))(pt|sp|em|mm|cm|in|bp|dd|cc|nd|nc|pc)?", token)
    if not m:
        return None
    value = float(m.group(1))
    unit = m.group(2) or "sp"
    return value, unit


def _to_em(value: float, unit: str, font_size_pt: float) -> float:
    if unit == "em":
        return value
    if unit == "sp":
        return sp_to_em(value, font_size_pt)
    # remaining are physical units TeX reports via \the — convert via pt
    pt_per = {
        "pt": 1.0,
        "bp": 72.27 / 72.0,
        "in": 72.27,
        "cm": 72.27 / 2.54,
        "mm": 72.27 / 25.4,
        "pc": 12.0,
        "dd": 1238.0 / 1157.0,
        "cc": 12.0 * 1238.0 / 1157.0,
        "nd": 685.0 / 642.0,
        "nc": 12.0 * 685.0 / 642.0,
    }
    pt = value * pt_per.get(unit, 1.0)
    return pt / font_size_pt


def parse_metrics_tsv(path: Path, font_size_pt: float) -> dict[str, dict[str, Any]]:
    """
    Returns { id: { "display": Metrics, "text": Metrics } }.

    Accepts pipe-separated (preferred) or whitespace-separated lines:
      id|mode|width|height|depth
      id mode width height depth
    """
    by_id: dict[str, dict[str, Any]] = {}
    if not path.is_file():
        return by_id
    raw = path.read_text(encoding="utf-8", errors="replace")
    skipped = 0
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("%"):
            continue
        if "|" in line:
            parts = [p.strip() for p in line.split("|")]
        else:
            parts = line.split()
        if len(parts) < 5:
            skipped += 1
            continue
        iid, mode, w_s, h_s, d_s = parts[0], parts[1], parts[2], parts[3], parts[4]
        mode = mode.lower()
        if mode not in ("display", "text"):
            skipped += 1
            continue
        try:
            w_p = _parse_dim_token(w_s)
            h_p = _parse_dim_token(h_s)
            d_p = _parse_dim_token(d_s)
            if not w_p or not h_p or not d_p:
                skipped += 1
                continue
            w_em = _to_em(w_p[0], w_p[1], font_size_pt)
            h_em = _to_em(h_p[0], h_p[1], font_size_pt)
            d_em = _to_em(d_p[0], d_p[1], font_size_pt)
        except ValueError:
            skipped += 1
            continue
        metrics = {
            "heightEm": h_em,
            "depthEm": d_em,
            "totalHeightEm": h_em + d_em,
            "widthEm": w_em,
        }
        by_id.setdefault(iid, {})[mode] = metrics

    if not by_id and raw.strip():
        sample = "\n".join(raw.splitlines()[:5])
        print(
            f"warning: parse_metrics_tsv got 0 rows from {path} "
            f"(skipped={skipped}). sample:\n{sample}",
            file=sys.stderr,
        )
    return by_id


def find_metrics_tsv(work: Path, jobname: str = "measure") -> Optional[Path]:
    """Locate metrics file written by the TeX job (name can vary with engine)."""
    candidates = [
        work / f"{jobname}-metrics.tsv",
        work / "metrics.tsv",
        work / f"{jobname}.tsv",
    ]
    # Also accept any *-metrics.tsv produced in the work dir.
    candidates.extend(sorted(work.glob("*-metrics.tsv")))
    candidates.extend(sorted(work.glob("*.tsv")))
    seen: set[Path] = set()
    for p in candidates:
        rp = p.resolve() if p.exists() else p
        if p in seen:
            continue
        seen.add(p)
        if p.is_file() and p.stat().st_size > 0:
            return p
    return None


def run_tex(
    engine_path: str,
    work: Path,
    tex_name: str = "measure.tex",
    jobname: str = "measure",
    timeout: int = 180,
) -> subprocess.CompletedProcess[str]:
    # -recorder helps diagnose file writes; nonstopmode for CI logs.
    cmd = [
        engine_path,
        "-interaction=nonstopmode",
        "-halt-on-error",
        f"-jobname={jobname}",
        tex_name,
    ]
    return subprocess.run(
        cmd,
        cwd=str(work),
        text=True,
        capture_output=True,
        timeout=timeout,
    )


def collect_log(work: Path, jobname: str, proc: subprocess.CompletedProcess[str]) -> str:
    chunks = [(proc.stdout or ""), (proc.stderr or "")]
    for name in (f"{jobname}.log", "measure.log", "texput.log"):
        p = work / name
        if p.is_file():
            chunks.append(p.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(chunks)


def prepare_work_font(work: Path, font: Path) -> str:
    """Copy bundled OTF into work dir; return fontspec basename (no extension)."""
    dest = work / "latinmodern-math.otf"
    if font.resolve() != dest.resolve():
        shutil.copy2(font, dest)
    return "latinmodern-math"


def merge_measured(
    dst: dict[str, dict[str, Any]],
    src: dict[str, dict[str, Any]],
) -> None:
    for iid, modes in src.items():
        slot = dst.setdefault(iid, {})
        slot.update(modes)


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

    # Dry-run only needs the math font (copy into work dir like a real run).
    if args.dry_run:
        font = deps.font or resolve_font(args.font)
        if font is None:
            print("dry-run requires a math font (--font / TEX_ORACLE_FONT / bundle).", file=sys.stderr)
            return 2
        own_temp = args.work_dir is None
        work = Path(tempfile.mkdtemp(prefix="stm_tex_oracle_")) if own_temp else args.work_dir
        assert work is not None
        work.mkdir(parents=True, exist_ok=True)
        prepare_work_font(work, font)
        tex_path = work / "measure.tex"
        tex_path.write_text(
            generate_tex(items, font_size_pt=args.font_size, font_path_dir="./"),
            encoding="utf-8",
        )
        print(f"wrote {tex_path} ({len(items)} formulas)", file=sys.stderr)
        print(f"dry-run: skip compile in {work}", file=sys.stderr)
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
    logs: list[str] = []

    try:
        prepare_work_font(work, deps.font)
        tex_source = generate_tex(items, font_size_pt=args.font_size, font_path_dir="./")
        tex_path = work / "measure.tex"
        tex_path.write_text(tex_source, encoding="utf-8")
        print(f"wrote {tex_path}", file=sys.stderr)
        print(f"font copy: {work / 'latinmodern-math.otf'}", file=sys.stderr)

        print(f"running {deps.engine} (batch) …", file=sys.stderr)
        proc = run_tex(deps.engine_path, work, tex_name="measure.tex", jobname="measure")
        log = collect_log(work, "measure", proc)
        logs.append(log)
        print(
            f"batch exit={proc.returncode} log_bytes={len(log)}",
            file=sys.stderr,
        )

        tsv = find_metrics_tsv(work, "measure")
        measured: dict[str, dict[str, Any]] = {}
        if tsv is not None:
            measured = parse_metrics_tsv(tsv, args.font_size)
            nlines = len(tsv.read_text(encoding="utf-8", errors="replace").splitlines())
            print(f"batch metrics file: {tsv} lines={nlines}", file=sys.stderr)
        else:
            print("batch: no metrics TSV found", file=sys.stderr)
            print(
                "work dir:",
                ", ".join(sorted(p.name for p in work.iterdir())[:50]),
                file=sys.stderr,
            )

        # Fallback: per-formula jobs if batch produced nothing (preamble OK, body error)
        # or only a few items (partial failure).
        need_fallback = len(measured) < max(1, len(items) // 4)
        if need_fallback:
            print(
                f"fallback: per-item compile (batch measured {len(measured)}/{len(items)}) …",
                file=sys.stderr,
            )
            per_dir = work / "per_item"
            per_dir.mkdir(exist_ok=True)
            shutil.copy2(work / "latinmodern-math.otf", per_dir / "latinmodern-math.otf")
            for it in items:
                if it["id"] in measured and "display" in measured[it["id"]]:
                    continue
                job = re.sub(r"[^A-Za-z0-9_-]", "_", it["id"])[:40]
                single = generate_single_item_tex(
                    it, font_size_pt=args.font_size, font_path_dir="./"
                )
                tex_i = per_dir / f"{job}.tex"
                tex_i.write_text(single, encoding="utf-8")
                try:
                    p = run_tex(
                        deps.engine_path,
                        per_dir,
                        tex_name=tex_i.name,
                        jobname=job,
                        timeout=60,
                    )
                except subprocess.TimeoutExpired:
                    logs.append(f"timeout: {it['id']}")
                    continue
                logs.append(collect_log(per_dir, job, p))
                tsv_i = find_metrics_tsv(per_dir, job)
                if tsv_i is not None:
                    merge_measured(measured, parse_metrics_tsv(tsv_i, args.font_size))

        combined_log = "\n---\n".join(logs)

        if not measured:
            result = build_result(
                items,
                measured={},
                deps=deps,
                font_size_pt=args.font_size,
                status="compile_failed",
                compile_log=combined_log,
            )
            text = json.dumps(result, indent=2) + "\n"
            if out_path:
                out_path.parent.mkdir(parents=True, exist_ok=True)
                out_path.write_text(text, encoding="utf-8")
                print(f"wrote {out_path} (measured 0/{len(items)})", file=sys.stderr)
            else:
                sys.stdout.write(text)
            print("TeX oracle produced no metrics. Log tail:", file=sys.stderr)
            print(combined_log[-4000:], file=sys.stderr)
            return 3

        status = "ok"
        result = build_result(
            items,
            measured,
            deps=deps,
            font_size_pt=args.font_size,
            status=status,
            compile_log=None if len(measured) >= len(items) // 2 else combined_log,
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
        # Require a reasonable hit rate so silent partial failures don't pass CI.
        if result["measuredCount"] < max(10, len(items) // 2):
            print(
                f"error: measured too few formulas ({result['measuredCount']}/{len(items)})",
                file=sys.stderr,
            )
            print(combined_log[-2000:], file=sys.stderr)
            return 3
        return 0
    finally:
        if own_temp and work is not None and not args.keep_work:
            shutil.rmtree(work, ignore_errors=True)
        elif work is not None and (args.keep_work or (own_temp and args.keep_work)):
            print(f"kept work dir: {work}", file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main())

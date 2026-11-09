#!/usr/bin/env python3
"""Read-only UTF-8 / mojibake audit for ShadowSlave text resources.

The game text lives in Godot text formats. A legacy Windows-1251 round-trip
turns Russian into sequences such as ``РџСЂРёРІРµС‚`` (UTF-8 read as CP1251)
or ``ÐŸÑ€Ð¸Ð²ÐµÑ‚`` (UTF-8 read as Latin-1), and a broken save can leave
U+FFFD or runs of ``?`` where Russian used to be. This scanner reports those
cases without modifying any file.

Run from the project root:
    python tools/audit/encoding_scan.py
    python tools/audit/encoding_scan.py --json
    python tools/audit/encoding_scan.py --questions

Exit code 0 means no mojibake / invalid UTF-8 was found. ``--questions`` also
reports suspicious runs of three or more question marks in game-facing text;
intentional mystery placeholders (``???`` for unknown map regions and locked
bestiary entries) are listed separately, not treated as failures.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_EXTENSIONS = (".tscn", ".tres", ".gd", ".json")
SKIP_DIRS = {".git", ".godot", "build", "experiments", "addons"}

REPLACEMENT_CHAR = "\ufffd"
CP1251_FFFD = "\u043f\u0457\u0405"  # "пїЅ" — UTF-8 U+FFFD read as CP1251
LATIN1_MARKERS = ("\u00d0", "\u00d1")  # "Ð", "Ñ"
CYRILLIC_MARKERS = set(
    "\u0401\u0410\u0411\u0412\u0413\u0414\u0415\u0416\u0417\u0418\u0419"
    "\u041a\u041b\u041c\u041d\u041e\u041f\u0420\u0421\u0422\u0423\u0424"
    "\u0425\u0426\u0427\u0428\u0429\u042a\u042b\u042c\u042d\u042e\u042f"
    "\u0430\u0431\u0432\u0433\u0434\u0435\u0436\u0437\u0438\u0439\u043a"
    "\u043b\u043c\u043d\u043e\u043f\u0440\u0441\u0442\u0443\u0444\u0445"
    "\u0446\u0447\u0448\u0449\u044a\u044b\u044c\u044d\u044e\u044f"
    "\u0402\u0403\u0404\u0405\u0406\u0407\u0408\u0409\u040a\u040b\u040c"
    "\u040e\u040f\u0452\u0453\u0454\u0455\u0456\u0457\u0458\u0459\u045a"
    "\u045b\u045c\u045e\u045f\u0490\u0491"
)
MOJIBAKE_MARKERS = set("РСÐÑ") | {
    "\u045f", "\u0452", "\u0453", "\u0454", "\u0455", "\u0456", "\u0457",
    "\u0458", "\u0459", "\u045a", "\u045b", "\u045c", "\u045e", "\u045f",
    "\u0402", "\u0403", "\u0404", "\u0405", "\u0406", "\u0407", "\u0408",
    "\u0409", "\u040a", "\u040b", "\u040c", "\u040e", "\u040f", "\u0490",
    "\u0491", "\u00ab", "\u00bb", "\u00b4", "\u00a6", "\u00a7", "\u00a9",
    "\u00ae", "\u00b0", "\u00b1", "\u00b5", "\u00b6", "\u00b7", "\u2116",
}
QUESTION_RUN_RE = re.compile(r"\?{3,}")
QUESTION_ALLOWLIST_RE = re.compile(
    r'(label\s*=\s*"\?\?\?"|title\.text\s*=\s*"\?\?\?"|«\?\?\?»)'
)


def is_probable_mojibake(chunk: str) -> str | None:
    """Return the repaired text when a CP1251 round-trip makes sense.

    A real CP1251-read-as-UTF-8 chunk always contains at least one of the
    characteristic marker letters (Р/С in Cyrillic or Ð/Ñ in Latin-1). Normal
    Russian text encodes to CP1251 bytes that are not valid UTF-8, so it does
    not match.
    """
    if not any(ch in MOJIBAKE_MARKERS for ch in chunk):
        return None
    try:
        repaired = chunk.encode("cp1251").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None
    cyrillic = sum(1 for ch in repaired if ch in CYRILLIC_MARKERS)
    if cyrillic < 2 or cyrillic / max(1, len(repaired)) <= 0.5:
        return None
    return repaired


def scan_file(path: Path, root: Path, check_questions: bool) -> tuple[list[dict], list[dict]]:
    rel = path.relative_to(root).as_posix()
    raw = path.read_bytes()
    findings: list[dict] = []
    questions: list[dict] = []

    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        findings.append({"file": rel, "line": 0, "kind": "invalid-utf8", "detail": str(exc)})
        return findings, questions

    for lineno, line in enumerate(text.splitlines(), 1):
        if REPLACEMENT_CHAR in line:
            findings.append({"file": rel, "line": lineno, "kind": "U+FFFD", "text": line.strip()[:240]})
        if CP1251_FFFD in line:
            findings.append({"file": rel, "line": lineno, "kind": "cp1251-of-FFFD", "text": line.strip()[:240]})
        if any(marker in line for marker in LATIN1_MARKERS):
            findings.append({"file": rel, "line": lineno, "kind": "latin1-mojibake", "text": line.strip()[:240]})

        # CP1251 produces not only Cyrillic letters but punctuation such as
        # U+201A/U+2014/U+2026; keep the whole non-ASCII run together so the
        # round-trip can see the complete mojibake sequence.
        for match in re.finditer(r"[^\x00-\x7F]{4,}", line):
            repaired = is_probable_mojibake(match.group(0))
            if repaired is not None:
                findings.append({
                    "file": rel,
                    "line": lineno,
                    "kind": "double-encoded-utf8",
                    "text": line.strip()[:240],
                    "repaired": repaired[:200],
                })

        if check_questions:
            for match in QUESTION_RUN_RE.finditer(line):
                questions.append({
                    "file": rel,
                    "line": lineno,
                    "run": match.group(0),
                    "intentional": bool(QUESTION_ALLOWLIST_RE.search(line)),
                    "text": line.strip()[:240],
                })

    return findings, questions


def iter_files(root: Path, extensions: tuple[str, ...]):
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in extensions:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(root).parts):
            continue
        yield path


def main() -> int:
    parser = argparse.ArgumentParser(description="Scan ShadowSlave text files for mojibake.")
    parser.add_argument("--root", type=Path, default=ROOT, help="project root (default: repository root)")
    parser.add_argument("--extensions", default=",".join(DEFAULT_EXTENSIONS), help="comma-separated suffixes")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--questions", action="store_true", help="also report runs of 3+ question marks")
    args = parser.parse_args()

    root = args.root.resolve()
    extensions = tuple(ext.strip() if ext.strip().startswith(".") else "." + ext.strip()
                       for ext in args.extensions.split(",") if ext.strip())
    if not root.is_dir():
        print(f"encoding_scan: not a directory: {root}", file=sys.stderr)
        return 2

    files = list(iter_files(root, extensions))
    all_findings: list[dict] = []
    all_questions: list[dict] = []
    for path in files:
        findings, questions = scan_file(path, root, args.questions)
        all_findings.extend(findings)
        all_questions.extend(questions)

    unexpected_questions = [item for item in all_questions if not item["intentional"]]
    result = {
        "root": str(root),
        "files": len(files),
        "mojibake": all_findings,
        "questions": all_questions,
        "unexpected_question_runs": unexpected_questions,
        "ok": not all_findings and not unexpected_questions,
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for item in all_findings:
            location = f"{item['file']}:{item['line']}" if item["line"] else item["file"]
            detail = item.get("repaired") or item.get("detail") or item.get("text", "")
            print(f"MOJIBAKE {item['kind']} {location}: {detail}")
        for item in all_questions:
            label = "QUESTION(ok)" if item["intentional"] else "QUESTION"
            print(f"{label} {item['file']}:{item['line']}: {item['text']}")
        print(
            f"encoding_scan: files={len(files)} mojibake={len(all_findings)} "
            f"unexpected_question_runs={len(unexpected_questions)}"
        )
        if all_questions:
            print(f"encoding_scan: question_runs={len(all_questions)} (see --questions)")

    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())

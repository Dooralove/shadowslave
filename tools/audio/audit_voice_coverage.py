"""Read-only VO coverage audit for M1 dialogue sequences.

DialogueRunner derives a voice id as <sequence_basename>_<index:03d> when
DialogueLine.voice_id is empty. This tool mirrors that rule and checks only the
project voice folders; it never invents or generates voice files.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIALOGUE = ROOT / "resources" / "dialogue" / "post_nightmare"
VOICE = ROOT / "assets" / "audio" / "voice" / "lines"
OUT = ROOT / "resources" / "audio" / "voice_manifest_m1.json"


def sequence_lines(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    records = []
    for match in re.finditer(
        r'\[sub_resource type="Resource" id="Line_\d+"\](.*?)(?=\n\[|\Z)',
        text,
        re.S,
    ):
        block = match.group(1)
        speaker_match = re.search(r'speaker = &"([^"]*)"', block)
        duration_match = re.search(r"duration = ([0-9.]+)", block)
        records.append({
            "speaker": speaker_match.group(1) if speaker_match else "",
            "duration": float(duration_match.group(1)) if duration_match else 0.0,
        })
    return records


def has_voice(voice_id: str) -> bool:
    return any((VOICE / f"{voice_id}{suffix}").exists() for suffix in (".wav", ".ogg"))


def main() -> None:
    entries = []
    sequences = 0
    total = 0
    missing = 0
    for path in sorted(DIALOGUE.glob("*.tres")):
        sequences += 1
        base = path.stem
        for index, record in enumerate(sequence_lines(path)):
            voice_id = f"{base}_{index:03d}"
            present = has_voice(voice_id)
            total += 1
            missing += 0 if present else 1
            entries.append({
                "sequence": base,
                "index": index,
                "voice_id": voice_id,
                "speaker": record["speaker"],
                "duration": record["duration"],
                "has_voice": present,
            })
    payload = {
        "version": 1,
        "scope": "M1 post-Nightmare dialogue sequences",
        "note": "Import table only. No voice is generated. Missing lines are silent in VoiceDirector.",
        "counts": {
            "sequences": sequences,
            "lines": total,
            "with_voice": total - missing,
            "missing_voice": missing,
        },
        "lines": entries,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{OUT.relative_to(ROOT)}: sequences={sequences} lines={total} missing={missing}")


if __name__ == "__main__":
    main()

"""Measure integrated loudness with ffmpeg loudnorm (EBU R128 approximation).

Usage:
    python tools/audio/measure_loudness.py
    python tools/audio/measure_loudness.py assets/audio/placeholder/music/menu_base.ogg
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
TARGET_LUFS = -18.0
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def measure(path: Path) -> tuple[float, float]:
    command = [
        FFMPEG, "-hide_banner", "-nostats", "-i", str(path),
        "-af", f"loudnorm=I={TARGET_LUFS}:TP=-1.5:print_format=json",
        "-f", "null", "-",
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    match = re.search(r"\{[\s\S]*?\"input_i\"[\s\S]*?\}", result.stderr)
    if match is None:
        raise RuntimeError(f"loudnorm did not return JSON for {path}")
    data = json.loads(match.group(0))
    return float(data["input_i"]), float(data["input_tp"])


def main(argv: list[str]) -> None:
    if argv:
        paths = [Path(arg).resolve() for arg in argv]
    else:
        paths = sorted((ROOT / "assets" / "audio" / "placeholder" / "music").glob("*.ogg"))
        paths += sorted((ROOT / "assets" / "audio" / "placeholder" / "ambience").glob("*.ogg"))
    for path in paths:
        if not path.exists():
            print(f"missing: {path}")
            continue
        loudness, peak = measure(path)
        delta = TARGET_LUFS - loudness
        print(f"{path.relative_to(ROOT)}  I={loudness:+.1f} LUFS  TP={peak:+.1f} dBTP  target_delta={delta:+.1f} dB")


if __name__ == "__main__":
    main(sys.argv[1:])

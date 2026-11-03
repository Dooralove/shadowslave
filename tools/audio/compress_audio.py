"""Compress placeholder audio for runtime size.

- Music/ambience: OGG Vorbis, loop-friendly, WAV source removed.
- Generated SFX: mono 22.05 kHz PCM WAV (in place).
- Voice/SAPI and third-party files are left untouched.

Requires imageio-ffmpeg's bundled ffmpeg. Run from the project root:

    python tools/audio/compress_audio.py
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[2]
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
MUSIC = ROOT / "assets" / "audio" / "placeholder" / "music"
AMBIENCE = ROOT / "assets" / "audio" / "placeholder" / "ambience"
SFX = ROOT / "assets" / "audio" / "sfx"
UI = ROOT / "assets" / "audio" / "ui"


def run(args: list[str]) -> None:
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def to_ogg(path: Path) -> None:
    out = path.with_suffix(".ogg")
    run(["-i", str(path), "-c:a", "libvorbis", "-q:a", "5", str(out)])
    path.unlink()
    print(f"ogg  {out.relative_to(ROOT)}  {out.stat().st_size / 1024:.0f} KiB")


def to_mono_22k(path: Path) -> None:
    temp = path.with_name(path.stem + ".mono.tmp.wav")
    run(["-i", str(path), "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", str(temp)])
    temp.replace(path)
    print(f"mono {path.relative_to(ROOT)}  {path.stat().st_size / 1024:.0f} KiB")


def main() -> None:
    for path in sorted(MUSIC.glob("*.wav")):
        to_ogg(path)
    for path in sorted(AMBIENCE.glob("*.wav")):
        to_ogg(path)
    for path in sorted(SFX.rglob("*.wav")) + sorted(UI.rglob("*.wav")):
        to_mono_22k(path)
    # Remove obsolete full-mix music files from the earlier one-layer pass.
    for path in MUSIC.glob("*_music_01.wav"):
        path.unlink(missing_ok=True)
    print("compression complete")


if __name__ == "__main__":
    main()

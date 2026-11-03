"""Read-only audit: every new M1 asset must be referenced by a cue/profile.

No files are modified. Exit code 1 if an orphan audio/VFX asset is found.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
M1_AUDIO = ROOT / "assets" / "audio" / "m1"
CUE_LIBRARY = ROOT / "resources" / "audio" / "audio_cue_library_demo.tres"
AUDIO_DIRECTOR = ROOT / "scripts" / "audio" / "scene_audio_director.gd"
VFX_DIRECTOR = ROOT / "scripts" / "vfx" / "scene_vfx_director.gd"
VFX_PROFILE_DIR = ROOT / "resources" / "audio" / "scene_vfx_profiles"
VFX_SCENE_DIR = ROOT / "scenes" / "environment" / "vfx"


def referenced_paths(text: str) -> set[str]:
    return {
        path.removeprefix("res://")
        for path in re.findall(r'res://[^"\s]+', text)
    }


def main() -> None:
    audio_files = {
        p.relative_to(ROOT).as_posix()
        for p in M1_AUDIO.rglob("*")
        if p.suffix in {".wav", ".ogg"}
    }
    cue_text = CUE_LIBRARY.read_text(encoding="utf-8", errors="replace")
    cue_refs = referenced_paths(cue_text)
    orphan_audio = sorted(audio_files - cue_refs)

    vfx_files = {
        p.relative_to(ROOT).as_posix()
        for p in VFX_SCENE_DIR.glob("m1_*.tscn")
    }
    vfx_text = "\n".join(
        p.read_text(encoding="utf-8", errors="replace")
        for p in VFX_PROFILE_DIR.glob("*.tres")
    )
    vfx_refs = referenced_paths(vfx_text)
    orphan_vfx = sorted(vfx_files - vfx_refs)

    profile_refs = referenced_paths(
        AUDIO_DIRECTOR.read_text(encoding="utf-8", errors="replace")
        + VFX_DIRECTOR.read_text(encoding="utf-8", errors="replace")
    )
    profile_files = {
        p.relative_to(ROOT).as_posix()
        for p in (ROOT / "resources" / "audio" / "scene_profiles").glob("*.tres")
    } | {
        p.relative_to(ROOT).as_posix()
        for p in VFX_PROFILE_DIR.glob("*.tres")
    }
    orphan_profiles = sorted(profile_files - profile_refs)

    print(f"audio_files={len(audio_files)} referenced={len(audio_files & cue_refs)} orphan={len(orphan_audio)}")
    print(f"vfx_files={len(vfx_files)} referenced={len(vfx_files & vfx_refs)} orphan={len(orphan_vfx)}")
    print(f"profiles={len(profile_files)} referenced={len(profile_files & profile_refs)} orphan={len(orphan_profiles)}")
    for orphan in orphan_audio + orphan_vfx + orphan_profiles:
        print("ORPHAN:", orphan)
    raise SystemExit(1 if orphan_audio or orphan_vfx or orphan_profiles else 0)


if __name__ == "__main__":
    main()

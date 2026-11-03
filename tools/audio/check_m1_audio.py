"""Read-only quality probe for the M1 audio kit.

Reports peak/RMS/DC and loop-seam discontinuity. It cannot hear the result;
human listening remains NOT TESTED.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
M1 = ROOT / "assets" / "audio" / "m1"


def db(value: float) -> float:
    return 20.0 * math.log10(max(value, 1e-9))


def main() -> None:
    failures = []
    files = sorted(M1.rglob("*.wav")) + sorted(M1.rglob("*.ogg"))
    for path in files:
        data, rate = sf.read(str(path), always_2d=True)
        mono = data.mean(axis=1)
        peak = float(np.max(np.abs(data)))
        rms = float(np.sqrt(np.mean(mono * mono)))
        dc = float(np.mean(mono))
        seam = float(abs(mono[0] - mono[-1])) if "loop" in path.name or path.parent.name in {"ambience", "music"} else 0.0
        if not np.isfinite(data).all():
            failures.append(f"{path}: non-finite sample")
        if peak > 0.999:
            failures.append(f"{path}: peak clipping")
        if seam > 0.005:
            failures.append(f"{path}: seam {seam:.5f}")
        print(
            f"{path.relative_to(ROOT)}  {len(mono) / rate:6.2f}s  "
            f"peak={db(peak):+6.1f} dBFS  rms={db(rms):+6.1f} dBFS  "
            f"dc={dc:+.4f}  seam={seam:.5f}"
        )
    print(f"files={len(files)} failures={len(failures)}")
    for failure in failures:
        print("FAIL:", failure)
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()

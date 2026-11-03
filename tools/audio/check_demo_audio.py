"""Read-only quality probe for the demo audio kit.

Reports peak/RMS/DC and a loop-seam discontinuity score. It does not listen:
final balance still requires a human pass.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
DEMO = ROOT / "assets" / "audio" / "demo"


def db(value: float) -> float:
    return 20.0 * math.log10(max(value, 1e-9))


def scan(path: Path) -> None:
    data, rate = sf.read(str(path), always_2d=True)
    mono = data.mean(axis=1)
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(mono * mono)))
    dc = float(np.mean(mono))
    seam = 0.0
    if "loop" in path.name:
        # The audible defect is the discontinuity at the loop boundary, not
        # the difference between two unrelated noise windows.
        seam = float(abs(mono[0] - mono[-1]))
    print(
        f"{path.relative_to(ROOT)}  {len(mono) / rate:6.2f}s  "
        f"peak={db(peak):+6.1f} dBFS  rms={db(rms):+6.1f} dBFS  "
        f"dc={dc:+.4f}  seam={seam:.5f}"
    )


def main() -> None:
    files = sorted(DEMO.rglob("*.wav")) + sorted(DEMO.rglob("*.ogg"))
    for path in files:
        scan(path)


if __name__ == "__main__":
    main()

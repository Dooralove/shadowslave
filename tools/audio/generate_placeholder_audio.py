"""Generate temporary, project-owned placeholder audio for the audio system.

These are NOT final assets. They exist so AudioDirector, footsteps, UI and
ambience can be wired and tested before AI/recorded assets are produced.
Run from the project root:

    python tools/audio/generate_placeholder_audio.py
"""

from __future__ import annotations

import math
import os
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
AUDIO = ROOT / "assets" / "audio"


def write_wav(path: Path, data: np.ndarray, sr: int = SR) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.asarray(data, dtype=np.float64)
    if data.ndim == 1:
        data = np.stack([data, data], axis=1)
    peak = float(np.max(np.abs(data))) if data.size else 0.0
    if peak > 0:
        data = data / peak * 0.88
    pcm = np.clip(data, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(sr)
        handle.writeframes(pcm.tobytes())
    print(f"{path.relative_to(ROOT)}  {data.shape[0] / sr:.2f}s")


def t_axis(seconds: float, sr: int = SR) -> np.ndarray:
    return np.arange(int(seconds * sr), dtype=np.float64) / sr


def fade_out(x: np.ndarray, seconds: float = 0.02) -> np.ndarray:
    n = min(len(x), max(1, int(seconds * SR)))
    if n <= 1:
        return x
    env = np.linspace(1.0, 0.0, n)
    x = x.copy()
    x[-n:] *= env
    return x


def fade_in(x: np.ndarray, seconds: float = 0.01) -> np.ndarray:
    n = min(len(x), max(1, int(seconds * SR)))
    if n <= 1:
        return x
    env = np.linspace(0.0, 1.0, n)
    x = x.copy()
    x[:n] *= env
    return x


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    a = math.exp(-2.0 * math.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, value in enumerate(x):
        acc = (1.0 - a) * value + a * acc
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def periodic_noise(n: int, seed: int, lo: float, hi: float, count: int = 48) -> np.ndarray:
    """Noise-like signal that is exactly periodic over n samples."""
    rng = np.random.default_rng(seed)
    t = np.arange(n, dtype=np.float64)
    k_lo = max(1, int(math.ceil(lo * n / SR)))
    k_hi = max(k_lo + 1, int(math.floor(hi * n / SR)))
    out = np.zeros(n, dtype=np.float64)
    for _ in range(count):
        k = int(rng.integers(k_lo, k_hi + 1))
        phase = float(rng.uniform(0.0, 2.0 * math.pi))
        amp = float(rng.uniform(0.4, 1.0)) / math.sqrt(k)
        out += amp * np.sin(2.0 * math.pi * k * t / n + phase)
    peak = float(np.max(np.abs(out))) if out.size else 0.0
    return out / peak if peak > 0 else out


def qfreq(freq: float, n: int, sr: int = SR) -> float:
    k = max(1, round(freq * n / sr))
    return k * sr / n


def tone(freq: float, n: int, amp: float = 1.0, phase: float = 0.0) -> np.ndarray:
    t = np.arange(n, dtype=np.float64) / SR
    return amp * np.sin(2.0 * math.pi * qfreq(freq, n) * t + phase)


def noise_burst(seconds: float, seed: int, lo: float, hi: float, decay: float = 18.0) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-decay * t)
    return periodic_noise(n, seed, lo, hi) * env


def metal_ring(seconds: float, base: float, seed: int, decay: float = 5.0) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-decay * t)
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    for ratio in (1.0, 1.51, 2.03, 2.71, 3.37):
        out += np.sin(2.0 * math.pi * base * ratio * t + rng.uniform(0, 6.28)) * (0.7 ** (ratio - 1.0))
    return out * env


def make_footstep(surface: str, variation: int) -> np.ndarray:
    rng = np.random.default_rng(1000 + variation + len(surface) * 17)
    seconds = {
        "snow_packed": 0.18,
        "snow_soft": 0.26,
        "ice": 0.22,
        "stone": 0.16,
        "mud": 0.24,
        "bone": 0.18,
        "wood": 0.20,
        "metal": 0.24,
        "coral": 0.20,
    }[surface]
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-18.0 * t)
    if surface == "snow_packed":
        body = lowpass(periodic_noise(n, 11 + variation, 200, 4500), 2200) * 0.9
        click = noise_burst(0.035, 12 + variation, 1200, 6000, 45.0)
    elif surface == "snow_soft":
        body = lowpass(periodic_noise(n, 21 + variation, 80, 2200), 1200) * 1.0
        click = noise_burst(0.05, 22 + variation, 300, 2500, 28.0) * 0.5
    elif surface == "ice":
        body = highpass(periodic_noise(n, 31 + variation, 1200, 7000), 1800) * 0.5
        click = metal_ring(0.09, 2400 + variation * 90, 32 + variation, 30.0) * 0.35
        click = np.pad(click, (0, max(0, n - len(click))))[:n]
    elif surface == "stone":
        body = lowpass(periodic_noise(n, 41 + variation, 300, 5000), 2600) * 0.8
        click = noise_burst(0.025, 42 + variation, 1500, 7000, 55.0)
    elif surface == "mud":
        body = lowpass(periodic_noise(n, 51 + variation, 40, 1400), 700) * 1.1
        click = lowpass(noise_burst(0.08, 52 + variation, 60, 1200, 16.0), 900) * 0.6
    elif surface == "bone":
        body = highpass(periodic_noise(n, 61 + variation, 900, 6000), 900) * 0.55
        click = noise_burst(0.03, 62 + variation, 1800, 8000, 50.0)
    elif surface == "wood":
        body = lowpass(periodic_noise(n, 71 + variation, 120, 2800), 1600) * 0.7
        click = np.sin(2.0 * math.pi * (420 + variation * 20) * t) * np.exp(-26.0 * t) * 0.45
    elif surface == "coral":
        body = highpass(periodic_noise(n, 91 + variation, 500, 6000), 700) * 0.55
        click = noise_burst(0.035, 92 + variation, 900, 5500, 38.0) * 0.8
    else:  # metal
        body = metal_ring(0.14, 520 + variation * 25, 81 + variation, 18.0) * 0.6
        body = np.pad(body, (0, max(0, n - len(body))))[:n]
        click = noise_burst(0.025, 82 + variation, 2000, 9000, 55.0) * 0.4
    out = np.zeros(n)
    out[: len(body)] += body[:n] * env[: len(body[:n])]
    out[: len(click)] += click[:n] * 0.7
    out += rng.normal(0.0, 0.002, n)
    return fade_out(out, 0.03)


def make_ui(name: str) -> np.ndarray:
    if name == "hover":
        n = int(0.06 * SR); t = np.arange(n) / SR
        return fade_out(np.sin(2 * math.pi * 820 * t) * 0.25 + np.sin(2 * math.pi * 1230 * t) * 0.10, 0.02)
    if name == "click":
        n = int(0.10 * SR); t = np.arange(n) / SR
        click = noise_burst(0.03, 7, 1000, 7000, 50.0)
        click = np.pad(click, (0, max(0, n - len(click))))[:n]
        return fade_out(np.sin(2 * math.pi * 420 * t) * np.exp(-28 * t) * 0.5
                        + np.sin(2 * math.pi * 980 * t) * np.exp(-40 * t) * 0.25
                        + click * 0.25, 0.03)
    if name == "back":
        n = int(0.09 * SR); t = np.arange(n) / SR
        return fade_out(np.sin(2 * math.pi * 300 * t) * np.exp(-24 * t) * 0.45, 0.02)
    if name == "tab":
        n = int(0.12 * SR)
        return fade_out(lowpass(periodic_noise(n, 17, 300, 5000), 2500) * np.exp(-22 * np.arange(n) / SR) * 0.5, 0.03)
    if name == "slider":
        n = int(0.035 * SR); t = np.arange(n) / SR
        return fade_out(np.sin(2 * math.pi * 1050 * t) * np.exp(-60 * t) * 0.2, 0.01)
    if name == "toggle":
        n = int(0.08 * SR); t = np.arange(n) / SR
        return fade_out(np.sin(2 * math.pi * 620 * t) * np.exp(-30 * t) * 0.35, 0.02)
    if name == "error":
        n = int(0.28 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 210 * t) + 0.6 * np.sin(2 * math.pi * 315 * t)) * np.exp(-5 * t) * 0.45, 0.04)
    if name == "confirm":
        n = int(0.22 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 660 * t) + 0.7 * np.sin(2 * math.pi * 990 * t)) * np.exp(-8 * t) * 0.35, 0.05)
    if name in ("open_map", "close_map"):
        n = int(0.18 * SR)
        return fade_out(lowpass(periodic_noise(n, 27, 200, 4500), 1800) * np.exp(-14 * np.arange(n) / SR) * 0.45, 0.04)
    if name == "quest_update":
        n = int(0.35 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 523.25 * t) + np.sin(2 * math.pi * 783.99 * t)) * np.exp(-6 * t) * 0.3, 0.06)
    if name == "item_pickup":
        n = int(0.25 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 1046.5 * t) + 0.6 * np.sin(2 * math.pi * 1568 * t)) * np.exp(-12 * t) * 0.3, 0.05)
    if name == "item_equip":
        n = int(0.3 * SR)
        ring = metal_ring(0.25, 520, 37, 10.0)
        return fade_out(np.pad(ring, (0, max(0, n - len(ring))))[:n] * 0.45, 0.04)
    if name == "skill_unlock":
        n = int(0.6 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 523.25 * t) + np.sin(2 * math.pi * 659.25 * t) + np.sin(2 * math.pi * 783.99 * t)) * np.exp(-4 * t) * 0.25, 0.1)
    raise KeyError(name)


def make_swing(seed: int, low: float, high: float, seconds: float = 0.28) -> np.ndarray:
    n = int(seconds * SR)
    noise = periodic_noise(n, seed, low, high)
    t = np.arange(n) / SR
    env = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2
    return fade_out(noise * env * 0.7, 0.03)


def make_hit(seed: int, kind: str) -> np.ndarray:
    if kind == "flesh":
        n = int(0.22 * SR); t = np.arange(n) / SR
        thump = np.sin(2 * math.pi * 82 * t) * np.exp(-20 * t)
        body = lowpass(periodic_noise(n, seed, 50, 1800), 900) * np.exp(-14 * t)
        return fade_out(thump * 0.8 + body * 0.6, 0.03)
    if kind == "bone":
        n = int(0.16 * SR)
        crack = noise_burst(0.06, seed, 1800, 9000, 55.0)
        return fade_out(np.pad(crack, (0, max(0, n - len(crack))))[:n] * 0.8, 0.02)
    if kind == "carapace":
        n = int(0.22 * SR)
        crack = noise_burst(0.06, seed, 1200, 7000, 45.0)
        ring = metal_ring(0.18, 780, seed + 1, 14.0)
        return fade_out(np.pad(crack, (0, max(0, n - len(crack))))[:n] * 0.6
                        + np.pad(ring, (0, max(0, n - len(ring))))[:n] * 0.35, 0.03)
    if kind == "armor":
        n = int(0.35 * SR)
        ring = metal_ring(0.32, 620, seed + 2, 8.0)
        return fade_out(np.pad(ring, (0, max(0, n - len(ring))))[:n] * 0.7, 0.04)
    raise KeyError(kind)


def make_world(name: str) -> np.ndarray:
    if name == "door_metal":
        n = int(0.9 * SR); t = np.arange(n) / SR
        rumble = lowpass(periodic_noise(n, 3, 30, 700), 350) * np.exp(-4 * t)
        ring = metal_ring(0.5, 180, 4, 7.0)
        return fade_out(rumble * 0.8 + np.pad(ring, (0, max(0, n - len(ring))))[:n] * 0.4, 0.08)
    if name == "door_stone":
        n = int(1.4 * SR); t = np.arange(n) / SR
        grind = lowpass(periodic_noise(n, 5, 40, 1200), 600) * (0.4 + 0.6 * np.exp(-3 * t))
        rubble = noise_burst(0.2, 6, 300, 5000, 16.0)
        return fade_out(grind * 0.7 + np.pad(rubble, (0, max(0, n - len(rubble))))[:n] * 0.35, 0.12)
    if name == "key":
        n = int(0.45 * SR)
        out = np.zeros(n)
        for i, f in enumerate((1800, 2400, 2100)):
            ring = metal_ring(0.18, f, 10 + i, 22.0)
            off = int(i * 0.06 * SR)
            out[off:off + len(ring)] += ring[: max(0, n - off)] * 0.35
        return fade_out(out, 0.05)
    if name == "unlock":
        n = int(0.35 * SR)
        click = noise_burst(0.035, 13, 1500, 8000, 50.0)
        ring = metal_ring(0.2, 900, 14, 18.0)
        return fade_out(np.pad(click, (0, max(0, n - len(click))))[:n] * 0.7
                        + np.pad(ring, (0, max(0, n - len(ring))))[:n] * 0.3, 0.04)
    if name == "pickup":
        n = int(0.25 * SR); t = np.arange(n) / SR
        return fade_out((np.sin(2 * math.pi * 880 * t) + 0.5 * np.sin(2 * math.pi * 1320 * t)) * np.exp(-14 * t) * 0.35, 0.04)
    if name == "fire_loop":
        n = int(8.0 * SR)
        base = lowpass(periodic_noise(n, 33, 60, 2200), 900) * 0.35
        rng = np.random.default_rng(34)
        for _ in range(18):
            start = int(rng.uniform(0, 7.8) * SR)
            pop = noise_burst(0.05, int(rng.integers(0, 9999)), 800, 7000, 50.0)
            base[start:start + len(pop)] += pop[: max(0, n - start)] * 0.55
        return base * 0.8
    if name == "chain_loop":
        n = int(8.0 * SR)
        out = lowpass(periodic_noise(n, 43, 40, 800), 500) * 0.10
        pattern = (0.0, 0.38, 0.76, 1.14, 1.52, 1.90, 2.34, 2.72)
        for i, offset in enumerate(pattern):
            ring = metal_ring(0.20, 1600 + (i % 3) * 140, 50 + i, 20.0)
            start = int(offset * SR)
            out[start:start + len(ring)] += ring[: max(0, n - start)] * 0.22
        return out
    if name == "water_drip":
        n = int(0.45 * SR); t = np.arange(n) / SR
        drop = np.sin(2 * math.pi * (900 - 500 * t / 0.45) * t) * np.exp(-22 * t)
        return fade_out(drop * 0.6, 0.04)
    if name == "wind_loop":
        n = int(12.0 * SR)
        t = np.arange(n) / SR
        base = periodic_noise(n, 63, 80, 3000)
        mod = 0.55 + 0.45 * np.sin(2 * math.pi * 3 * t / 12.0) ** 2
        return lowpass(base * mod, 2600) * 0.7
    if name == "rockfall":
        n = int(1.6 * SR); t = np.arange(n) / SR
        rumble = lowpass(periodic_noise(n, 73, 25, 900), 300) * np.exp(-3 * t)
        out = rumble * 0.8
        for i, off in enumerate((0.15, 0.55, 1.05)):
            impact = noise_burst(0.18, 74 + i, 200, 5000, 18.0)
            start = int(off * SR)
            out[start:start + len(impact)] += impact[: max(0, n - start)] * 0.55
        return fade_out(out, 0.12)
    if name == "silver_bell":
        n = int(1.8 * SR)
        out = metal_ring(1.7, 1180, 1201, 3.2) * 0.7
        strike = noise_burst(0.04, 1202, 1200, 9000, 45.0)
        out[: len(strike)] += strike * 0.5
        return fade_out(out, 0.25)
    if name == "whip":
        n = int(0.45 * SR); t = np.arange(n) / SR
        swish = highpass(periodic_noise(n, 1301, 500, 7000), 800) * np.exp(-12 * t)
        crack = noise_burst(0.035, 1302, 1600, 11000, 55.0)
        out = swish * 0.45
        out[: len(crack)] += crack * 0.85
        return fade_out(out, 0.08)
    raise KeyError(name)


def make_pad(chord: tuple[float, ...], seconds: float, seed: int, brightness: float = 1.0) -> np.ndarray:
    n = int(seconds * SR)
    out = np.zeros(n)
    rng = np.random.default_rng(seed)
    for f in chord:
        out += tone(f, n, 0.18)
        out += tone(f * 2.0, n, 0.05 * brightness)
        out += tone(f * 0.5, n, 0.08)
    # slow breathing movement, periodic over the loop
    t = np.arange(n) / SR
    out *= 0.72 + 0.28 * np.sin(2 * math.pi * 2 * t / seconds + rng.uniform(0, 6.28)) ** 2
    return out


def make_music_menu() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((146.83, 174.61, 220.0), seconds, 101, 1.0) * 0.55
    # sparse, detuned piano-like motif
    for start, freq, dur in ((0.5, 587.33, 1.8), (4.0, 523.25, 2.2), (8.0, 440.0, 2.0), (12.0, 349.23, 2.4)):
        d = int(dur * SR)
        t = np.arange(d) / SR
        pluck = (np.sin(2 * math.pi * freq * t) + 0.35 * np.sin(2 * math.pi * freq * 2.01 * t)) * np.exp(-1.8 * t)
        off = int(start * SR)
        out[off:off + d] += pluck[: max(0, n - off)] * 0.20
    return out


def make_music_park() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((164.81, 196.0, 246.94), seconds, 202, 0.8) * 0.45
    city = lowpass(periodic_noise(n, 203, 30, 1200), 500) * 0.18
    out += city
    for start, freq in ((2.0, 493.88), (6.0, 440.0), (10.0, 392.0), (12.0, 329.63)):
        d = int(2.0 * SR)
        t = np.arange(d) / SR
        pluck = np.sin(2 * math.pi * freq * t) * np.exp(-2.2 * t)
        off = int(start * SR)
        out[off:off + d] += pluck[: max(0, n - off)] * 0.12
    return out


def make_music_caravan() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((98.0, 116.54, 146.83), seconds, 303, 0.7) * 0.55
    # chain-like 3+3+2 pulse
    pattern = (0.0, 0.5, 0.9, 1.4, 1.9, 2.3, 2.8, 3.25)
    for rep in range(4):
        for i, off in enumerate(pattern):
            ring = metal_ring(0.16, 740 + (i % 3) * 90, 300 + rep * 10 + i, 24.0)
            start = int((rep * 4.0 + off) * SR)
            if start >= n:
                continue
            out[start:start + len(ring)] += ring[: max(0, n - start)] * 0.10
    wind = lowpass(periodic_noise(n, 304, 60, 2400), 1800) * 0.12
    return out + wind


def make_music_camp() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((110.0, 130.81, 164.81), seconds, 404, 0.8) * 0.40
    for start, freq in ((1.0, 440.0), (5.0, 392.0), (9.0, 329.63), (13.0, 293.66)):
        d = int(2.2 * SR)
        t = np.arange(d) / SR
        pluck = (np.sin(2 * math.pi * freq * t) + 0.25 * np.sin(2 * math.pi * freq * 1.5 * t)) * np.exp(-1.6 * t)
        off = int(start * SR)
        out[off:off + d] += pluck[: max(0, n - off)] * 0.14
    return out


def make_music_sanctuary() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((73.42, 110.0, 146.83, 174.61), seconds, 505, 0.6) * 0.55
    # distant, slow "choir" partials
    out += tone(293.66, n, 0.05) + tone(349.23, n, 0.04)
    return out


def _empty(n: int) -> np.ndarray:
    return np.zeros(n, dtype=np.float64)


def _pluck(n: int, start: float, freq: float, duration: float, gain: float, seed: int = 0) -> np.ndarray:
    d = int(duration * SR)
    t = np.arange(d) / SR
    rng = np.random.default_rng(seed)
    out = (np.sin(2 * math.pi * freq * t) + 0.3 * np.sin(2 * math.pi * freq * 2.01 * t + rng.uniform(0, 1)))
    out *= np.exp(-1.8 * t) * gain
    result = _empty(n)
    off = int(start * SR)
    result[off:off + d] += out[: max(0, n - off)]
    return result


def make_music_menu_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((146.83, 174.61, 220.0), seconds, 101, 1.0) * 0.55
    pulse = _empty(n)
    for start in (0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0):
        pulse += _pluck(n, start, 55.0, 0.8, 0.10, 111)
    melody = _empty(n)
    for start, freq, dur in ((0.5, 587.33, 1.8), (4.0, 523.25, 2.2), (8.0, 440.0, 2.0), (12.0, 349.23, 2.4)):
        melody += _pluck(n, start, freq, dur, 0.20, 112)
    return base, pulse, melody


def make_music_park_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((164.81, 196.0, 246.94), seconds, 202, 0.8) * 0.45
    base += lowpass(periodic_noise(n, 203, 30, 1200), 500) * 0.18
    pulse = _empty(n)
    for start in (1.0, 5.0, 9.0, 13.0):
        pulse += _pluck(n, start, 82.41, 1.2, 0.07, 211)
    melody = _empty(n)
    for start, freq in ((2.0, 493.88), (6.0, 440.0), (10.0, 392.0), (12.0, 329.63)):
        melody += _pluck(n, start, freq, 2.0, 0.12, 212)
    return base, pulse, melody


def make_music_caravan_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((98.0, 116.54, 146.83), seconds, 303, 0.7) * 0.55
    base += lowpass(periodic_noise(n, 304, 60, 2400), 1800) * 0.12
    pulse = _empty(n)
    pattern = (0.0, 0.5, 0.9, 1.4, 1.9, 2.3, 2.8, 3.25)
    for rep in range(4):
        for i, offset in enumerate(pattern):
            ring = metal_ring(0.16, 740 + (i % 3) * 90, 300 + rep * 10 + i, 24.0)
            start = int((rep * 4.0 + offset) * SR)
            pulse[start:start + len(ring)] += ring[: max(0, n - start)] * 0.10
    melody = _empty(n)
    for start, freq in ((0.0, 196.0), (4.0, 174.61), (8.0, 146.83), (12.0, 196.0)):
        melody += _pluck(n, start, freq, 3.0, 0.045, 311)
    return base, pulse, melody


def make_music_camp_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((110.0, 130.81, 164.81), seconds, 404, 0.8) * 0.40
    pulse = _empty(n)
    for start in (0.0, 3.0, 6.0, 9.0, 12.0, 15.0):
        pulse += _pluck(n, start, 73.42, 0.7, 0.08, 411)
    rng = np.random.default_rng(412)
    for _ in range(14):
        start = float(rng.uniform(0.0, 15.5))
        burst = noise_burst(0.08, int(rng.integers(0, 9999)), 400, 5000, 24.0) * 0.025
        off = int(start * SR)
        pulse[off:off + len(burst)] += burst[: max(0, n - off)]
    melody = _empty(n)
    for start, freq in ((1.0, 440.0), (5.0, 392.0), (9.0, 329.63), (13.0, 293.66)):
        melody += _pluck(n, start, freq, 2.2, 0.14, 413)
    return base, pulse, melody


def make_music_sanctuary_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((73.42, 110.0, 146.83, 174.61), seconds, 505, 0.6) * 0.55
    pulse = _empty(n)
    for start in (0.0, 4.0, 8.0, 12.0):
        pulse += _pluck(n, start, 36.71, 1.0, 0.08, 511)
    melody = _empty(n)
    for start, freq in ((0.0, 293.66), (5.0, 349.23), (10.0, 440.0), (12.0, 349.23)):
        melody += _pluck(n, start, freq, 2.5, 0.05, 512)
    return base, pulse, melody


def make_music_labyrinth_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((73.42, 87.31, 110.0), seconds, 1309, 0.7) * 0.50
    pulse = _empty(n)
    for start in (0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0):
        pulse += _pluck(n, start, 55.0, 0.6, 0.22, 13111)
    melody = _empty(n)
    for start, base_freq in ((1.0, 1600), (5.0, 1800), (9.0, 1500), (13.0, 1900)):
        ring = metal_ring(0.18, base_freq, int(start * 7), 28.0)
        off = int(start * SR)
        melody[off:off + len(ring)] += ring[: max(0, n - off)] * 0.07
    return base, pulse, melody


def make_music_pilgrim_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((110.0, 130.81, 164.81), seconds, 1409, 0.65) * 0.42
    pulse = _empty(n)
    for start in (1.0, 5.0, 9.0, 13.0):
        pulse += _pluck(n, start, 55.0, 1.2, 0.06, 1411)
    melody = _empty(n)
    for start, freq in ((2.0, 440.0), (6.0, 392.0), (10.0, 329.63), (13.0, 293.66)):
        melody += _pluck(n, start, freq, 2.2, 0.12, 1412)
    return base, pulse, melody


def make_music_finale_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    base = make_pad((73.42, 110.0, 146.83, 174.61), seconds, 1509, 0.5) * 0.58
    pulse = _empty(n)
    for start in (0.0, 4.0, 8.0, 12.0):
        pulse += _pluck(n, start, 36.71, 1.6, 0.09, 1511)
    melody = _empty(n)
    for start, freq in ((0.0, 293.66), (4.0, 349.23), (8.0, 440.0), (12.0, 349.23)):
        melody += _pluck(n, start, freq, 3.0, 0.06, 1512)
    return base, pulse, melody


def make_ritual_offering() -> np.ndarray:
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    low = np.sin(2 * math.pi * 55 * t) * np.exp(-2.0 * t) * 0.35
    choir = np.sin(2 * math.pi * 220 * t) * 0.12 + np.sin(2 * math.pi * 330 * t) * 0.08
    wet = highpass(periodic_noise(n, 1601, 300, 3500), 700) * np.exp(-5.0 * t) * 0.25
    return fade_out(low + choir + wet, 0.25)


def make_ambience_city() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = lowpass(periodic_noise(n, 606, 30, 1600), 600) * 0.35
    out += lowpass(periodic_noise(n, 607, 80, 5000), 3200) * 0.10
    return out


def make_ambience_hum() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    return lowpass(periodic_noise(n, 707, 40, 900), 400) * 0.30 + tone(55.0, n, 0.08)


def make_ambience_wind() -> np.ndarray:
    return make_world("wind_loop")


def make_ambience_fire() -> np.ndarray:
    return make_world("fire_loop")


def make_ambience_void() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    return tone(73.42, n, 0.10) + tone(110.0, n, 0.05) + lowpass(periodic_noise(n, 808, 20, 500), 250) * 0.20


def make_ambience_water() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    t = np.arange(n) / SR
    surf = lowpass(periodic_noise(n, 909, 30, 1800), 700) * (0.45 + 0.25 * np.sin(2 * math.pi * 2 * t / seconds) ** 2)
    out = surf * 0.55 + tone(55.0, n, 0.06)
    for start in (2.0, 6.0, 10.0, 14.0):
        drip = make_world("water_drip")
        off = int(start * SR)
        out[off:off + len(drip)] += drip[: max(0, n - off)] * 0.12
    return out


def make_ambience_storm() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    wind = lowpass(periodic_noise(n, 1009, 40, 3500), 1800) * 0.55
    rumble = lowpass(periodic_noise(n, 1010, 20, 300), 160) * 0.35
    out = wind + rumble
    for start in (3.0, 11.0):
        thunder = make_storm_rumble()
        off = int(start * SR)
        out[off:off + len(thunder)] += thunder[: max(0, n - off)] * 0.35
    return out


def make_ambience_bone() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = lowpass(periodic_noise(n, 1109, 30, 900), 400) * 0.18 + tone(82.41, n, 0.08)
    for start, base in ((1.5, 1800), (5.5, 2100), (9.0, 1600), (13.0, 2300)):
        ring = metal_ring(0.22, base, int(start * 10), 24.0)
        off = int(start * SR)
        out[off:off + len(ring)] += ring[: max(0, n - off)] * 0.10
    return out


def make_ambience_coral() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((73.42, 110.0, 146.83), seconds, 1209, 0.6) * 0.22
    out += lowpass(periodic_noise(n, 1210, 80, 1600), 900) * 0.12
    for start in (3.0, 9.0, 14.0):
        drip = make_world("water_drip")
        off = int(start * SR)
        out[off:off + len(drip)] += drip[: max(0, n - off)] * 0.08
    return out


def make_music_labyrinth() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((73.42, 87.31, 110.0), seconds, 1309, 0.7) * 0.50
    # slow heartbeat-like pulse
    t = np.arange(n) / SR
    for start in (0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0):
        d = int(0.6 * SR)
        pulse = np.sin(2 * math.pi * 55 * np.arange(d) / SR) * np.exp(-7 * np.arange(d) / SR)
        off = int(start * SR)
        out[off:off + d] += pulse[: max(0, n - off)] * 0.22
    for start, base in ((1.0, 1600), (5.0, 1800), (9.0, 1500), (13.0, 1900)):
        ring = metal_ring(0.18, base, int(start * 7), 28.0)
        off = int(start * SR)
        out[off:off + len(ring)] += ring[: max(0, n - off)] * 0.07
    return out


def make_music_pilgrim() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    out = make_pad((110.0, 130.81, 164.81), seconds, 1409, 0.65) * 0.42
    for start, freq in ((2.0, 440.0), (6.0, 392.0), (10.0, 329.63), (13.0, 293.66)):
        d = int(2.2 * SR)
        t = np.arange(d) / SR
        bell = (np.sin(2 * math.pi * freq * t) + 0.3 * np.sin(2 * math.pi * freq * 2.01 * t)) * np.exp(-1.6 * t)
        off = int(start * SR)
        out[off:off + d] += bell[: max(0, n - off)] * 0.12
    return out


def make_storm_rumble() -> np.ndarray:
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    low = lowpass(periodic_noise(n, 1509, 15, 400), 180) * 0.65
    crack = noise_burst(0.18, 1510, 400, 5000, 16.0)
    out = low * (0.4 + 0.6 * np.exp(-1.5 * t))
    out[: len(crack)] += crack * 0.45
    return fade_out(out, 0.2)


def make_tide_surge() -> np.ndarray:
    n = int(2.5 * SR)
    t = np.arange(n) / SR
    wave = lowpass(periodic_noise(n, 1609, 40, 2200), 900) * (0.35 + 0.65 * np.sin(np.pi * np.clip(t / 2.5, 0, 1)) ** 2)
    low = lowpass(periodic_noise(n, 1610, 20, 300), 180) * 0.35
    return fade_out(wave * 0.6 + low, 0.3)


def make_bone_creak() -> np.ndarray:
    n = int(0.8 * SR)
    t = np.arange(n) / SR
    creak = np.sin(2 * math.pi * (220 + 80 * np.sin(2 * math.pi * 5 * t)) * t) * (0.35 + 0.65 * np.exp(-3 * t))
    noise = highpass(periodic_noise(n, 1709, 600, 4000), 600) * 0.18
    return fade_out(lowpass(creak * 0.4 + noise, 2600), 0.1)


def make_coral_groan() -> np.ndarray:
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    groan = np.sin(2 * math.pi * (48 + 6 * np.sin(2 * math.pi * 1.3 * t)) * t) * 0.35
    noise = lowpass(periodic_noise(n, 1809, 30, 700), 300) * 0.25
    return fade_out(groan + noise, 0.2)


def main() -> None:
    surfaces = ("snow_packed", "snow_soft", "ice", "stone", "mud", "bone", "wood", "metal", "coral")
    for surface in surfaces:
        for variation in range(1, 4):
            write_wav(AUDIO / "sfx" / "player" / "footsteps" / f"{surface}_{variation:02d}.wav", make_footstep(surface, variation))

    for name in ("hover", "click", "back", "tab", "slider", "toggle", "error", "confirm",
                 "open_map", "close_map", "quest_update", "item_pickup", "item_equip", "skill_unlock"):
        write_wav(AUDIO / "ui" / f"{name}_01.wav", make_ui(name))

    write_wav(AUDIO / "sfx" / "combat" / "swing_armed_01.wav", make_swing(901, 300, 6000))
    write_wav(AUDIO / "sfx" / "combat" / "swing_unarmed_01.wav", make_swing(902, 150, 3000))
    for kind in ("flesh", "bone", "carapace", "armor"):
        write_wav(AUDIO / "sfx" / "combat" / f"hit_{kind}_01.wav", make_hit(910 + len(kind), kind))
    write_wav(AUDIO / "sfx" / "combat" / "block_metal_01.wav", make_hit(920, "armor"))
    write_wav(AUDIO / "sfx" / "combat" / "block_leather_01.wav", make_hit(921, "flesh"))
    write_wav(AUDIO / "sfx" / "combat" / "guard_break_01.wav", make_hit(922, "carapace"))
    write_wav(AUDIO / "sfx" / "combat" / "dodge_01.wav", make_swing(923, 200, 4500, 0.20))
    write_wav(AUDIO / "sfx" / "combat" / "larva_screech_01.wav",
              fade_out(np.sin(2 * math.pi * np.linspace(900, 2400, int(0.45 * SR)) * np.arange(int(0.45 * SR)) / SR)
                       * np.exp(-4 * np.arange(int(0.45 * SR)) / SR) * 0.5, 0.03))
    n_roar = int(2.0 * SR)
    t_roar = np.arange(n_roar) / SR
    roar = (np.sin(2 * math.pi * (52 + 6 * np.sin(2 * math.pi * 3 * t_roar)) * t_roar)
            + 0.4 * np.sin(2 * math.pi * 26 * t_roar)) * (0.5 + 0.5 * np.sin(2 * math.pi * 0.7 * t_roar))
    write_wav(AUDIO / "sfx" / "combat" / "tyrant_roar_01.wav", fade_out(lowpass(roar, 900) * 0.7, 0.15))

    for name in ("door_metal", "door_stone", "key", "unlock", "pickup", "water_drip", "rockfall"):
        write_wav(AUDIO / "sfx" / "world" / f"{name}_01.wav", make_world(name))
    write_wav(AUDIO / "sfx" / "world" / "fire_loop_01.wav", make_world("fire_loop"))
    write_wav(AUDIO / "sfx" / "world" / "chain_loop_01.wav", make_world("chain_loop"))
    write_wav(AUDIO / "sfx" / "world" / "wind_loop_01.wav", make_world("wind_loop"))
    write_wav(AUDIO / "sfx" / "world" / "tide_surge_01.wav", make_tide_surge())
    write_wav(AUDIO / "sfx" / "world" / "storm_rumble_01.wav", make_storm_rumble())
    write_wav(AUDIO / "sfx" / "world" / "bone_creak_01.wav", make_bone_creak())
    write_wav(AUDIO / "sfx" / "world" / "coral_groan_01.wav", make_coral_groan())
    write_wav(AUDIO / "sfx" / "world" / "silver_bell_01.wav", make_world("silver_bell"))
    write_wav(AUDIO / "sfx" / "world" / "whip_01.wav", make_world("whip"))
    write_wav(AUDIO / "sfx" / "world" / "ritual_offering_01.wav", make_ritual_offering())

    layer_makers = {
        "menu": make_music_menu_layers,
        "park": make_music_park_layers,
        "caravan": make_music_caravan_layers,
        "camp": make_music_camp_layers,
        "sanctuary": make_music_sanctuary_layers,
        "labyrinth": make_music_labyrinth_layers,
        "pilgrim": make_music_pilgrim_layers,
        "finale": make_music_finale_layers,
    }
    for cue_name, maker in layer_makers.items():
        for layer_name, data in zip(("base", "pulse", "melody"), maker()):
            write_wav(AUDIO / "placeholder" / "music" / f"{cue_name}_{layer_name}.wav", data)

    write_wav(AUDIO / "placeholder" / "ambience" / "city_ambience_01.wav", make_ambience_city())
    write_wav(AUDIO / "placeholder" / "ambience" / "hum_ambience_01.wav", make_ambience_hum())
    write_wav(AUDIO / "placeholder" / "ambience" / "wind_ambience_01.wav", make_ambience_wind())
    write_wav(AUDIO / "placeholder" / "ambience" / "fire_ambience_01.wav", make_ambience_fire())
    write_wav(AUDIO / "placeholder" / "ambience" / "void_ambience_01.wav", make_ambience_void())
    write_wav(AUDIO / "placeholder" / "ambience" / "water_ambience_01.wav", make_ambience_water())
    write_wav(AUDIO / "placeholder" / "ambience" / "storm_ambience_01.wav", make_ambience_storm())
    write_wav(AUDIO / "placeholder" / "ambience" / "bone_ambience_01.wav", make_ambience_bone())
    write_wav(AUDIO / "placeholder" / "ambience" / "coral_ambience_01.wav", make_ambience_coral())


if __name__ == "__main__":
    main()

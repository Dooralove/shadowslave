"""Generate the project-owned audio layer used by the Labyrinth demo fragment.

These files are original procedural placeholders, not samples from third-party
libraries. They are registered in docs/ASSET_LICENSES.md as project-owned.
Run from the project root:

    python tools/audio/generate_demo_audio.py

Only files under assets/audio/demo/ are written. Existing assets are not
touched. Short 3D cues are mono 44.1 kHz WAV; ambience/music loops are stereo
OGG Vorbis with a crossfaded seam.
"""

from __future__ import annotations

import math
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "demo"


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR), dtype=np.float64) / SR


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x: np.ndarray, cutoff: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, cutoff, btype="lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, cutoff, btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def normalize(x: np.ndarray, peak: float = 0.84) -> np.ndarray:
    top = float(np.max(np.abs(x))) if x.size else 0.0
    return x / top * peak if top > 0 else x


def fade(x: np.ndarray, fade_in: float = 0.008, fade_out: float = 0.03) -> np.ndarray:
    out = np.asarray(x, dtype=np.float64).copy()
    n_in = min(len(out), max(1, int(fade_in * SR)))
    n_out = min(len(out), max(1, int(fade_out * SR)))
    if n_in:
        out[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out:
        out[-n_out:] *= np.linspace(1.0, 0.0, n_out)
    return out


def loop_seam(x: np.ndarray, crossfade: float = 0.35) -> np.ndarray:
    """Make a generated bed loop by crossfading the tail into the head."""
    n = int(crossfade * SR)
    if n <= 1 or len(x) < n * 3:
        return x
    body = x[:-n].copy()
    tail = x[-n:]
    ramp = np.linspace(0.0, 1.0, n)
    body[:n] = body[:n] * ramp + tail * (1.0 - ramp)
    # A short zero-edge fade guarantees no click even for broadband noise,
    # where adjacent samples can legitimately differ by a large amount.
    edge = min(int(0.012 * SR), len(body) // 8)
    if edge > 1:
        body[:edge] *= np.linspace(0.0, 1.0, edge)
        body[-edge:] *= np.linspace(1.0, 0.0, edge)
    return body


def write_mono(name: str, data: np.ndarray, peak: float = 0.84) -> None:
    path = OUT / "sfx" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = fade(normalize(data, peak))
    sf.write(str(path), data.astype(np.float32), SR, subtype="PCM_16")
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def write_stereo_loop(name: str, data: np.ndarray, peak: float = 0.76) -> None:
    path = OUT / "ambience" / f"{name}.ogg"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = normalize(loop_seam(np.asarray(data, dtype=np.float64)), peak)
    # Keep both channels identical: a circularly rolled "wide" copy moves the
    # loop seam to a non-crossfaded sample and produces an audible click.
    stereo = np.stack([data, data], axis=1)
    sf.write(str(path), stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def write_music_layer(name: str, data: np.ndarray, peak: float = 0.58) -> None:
    path = OUT / "music" / f"{name}.ogg"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = normalize(loop_seam(np.asarray(data, dtype=np.float64), 0.6), peak)
    stereo = np.stack([data, data], axis=1)
    sf.write(str(path), stereo.astype(np.float32), SR, format="OGG", subtype="VORBIS")
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def snap(t: np.ndarray, freq: float, decay: float) -> np.ndarray:
    return np.sin(2.0 * math.pi * freq * t) * np.exp(-decay * t)


def chitin_click(seconds: float, base: float, seed: int, decay: float = 55.0) -> np.ndarray:
    rng_ = rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    click = bandpass(rng_.normal(0.0, 1.0, n), 1800.0, 9000.0) * np.exp(-decay * t)
    ring = np.sin(2.0 * math.pi * base * t) * np.exp(-28.0 * t) * 0.35
    return click * 0.75 + ring


def carapace_chitter() -> np.ndarray:
    seconds = 0.95
    n = int(seconds * SR)
    out = np.zeros(n)
    rng_ = rng(701)
    # Irregular chitin clicks with a low, wet rasp underneath.
    for offset, freq, gain in (
        (0.04, 2100.0, 0.55),
        (0.12, 2600.0, 0.38),
        (0.23, 1850.0, 0.62),
        (0.37, 3050.0, 0.30),
        (0.49, 2300.0, 0.48),
        (0.63, 2750.0, 0.35),
        (0.78, 1950.0, 0.28),
    ):
        click = chitin_click(0.06, freq, int(rng_.integers(0, 9999)), 60.0) * gain
        start = int(offset * SR)
        out[start:start + len(click)] += click[: max(0, n - start)]
    rasp = bandpass(rng_.normal(0.0, 1.0, n), 280.0, 1400.0) * 0.14
    rasp *= 0.4 + 0.6 * np.sin(2.0 * math.pi * 7.0 * np.arange(n) / SR) ** 2
    return out + rasp


def carapace_click() -> np.ndarray:
    n = int(0.22 * SR)
    out = np.zeros(n)
    for i, offset in enumerate((0.0, 0.075)):
        click = chitin_click(0.07, 2400.0 + i * 320.0, 711 + i, 62.0) * (0.7 if i == 0 else 0.4)
        start = int(offset * SR)
        out[start:start + len(click)] += click[: max(0, n - start)]
    return out


def carapace_attack() -> np.ndarray:
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    rng_ = rng(721)
    whoosh = bandpass(rng_.normal(0.0, 1.0, n), 500.0, 4200.0)
    whoosh *= np.sin(np.pi * np.clip(t / 0.32, 0.0, 1.0)) ** 2 * 0.55
    snap = chitin_click(0.09, 1500.0, 722, 38.0) * 0.8
    out = whoosh
    out[: len(snap)] += snap
    return out


def carapace_death() -> np.ndarray:
    seconds = 1.45
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(731)
    crack = bandpass(rng_.normal(0.0, 1.0, n), 900.0, 9000.0) * np.exp(-30.0 * t) * 0.55
    shell = np.sin(2.0 * math.pi * 190.0 * t) * np.exp(-9.0 * t) * 0.28
    wet = lowpass(rng_.normal(0.0, 1.0, n), 900.0) * np.exp(-4.5 * t) * 0.42
    collapse = np.sin(2.0 * math.pi * 62.0 * np.clip(t - 0.28, 0.0, None)) * np.exp(-5.0 * t) * 0.30
    out = crack + shell + wet + collapse
    # A last few shell clicks as the body settles.
    for offset in (0.55, 0.77, 0.98):
        click = chitin_click(0.06, 2100.0, int(offset * 1000), 55.0) * 0.22
        start = int(offset * SR)
        out[start:start + len(click)] += click[: max(0, n - start)]
    return out


def tide_warning() -> np.ndarray:
    seconds = 3.2
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # Low signal horn: a fifth, slow swell, no melodic comfort.
    swell = np.clip(t / 1.1, 0.0, 1.0) * np.clip((seconds - t) / 1.2, 0.0, 1.0)
    horn = (np.sin(2.0 * math.pi * 55.0 * t) + 0.45 * np.sin(2.0 * math.pi * 82.5 * t)
            + 0.18 * np.sin(2.0 * math.pi * 110.0 * t))
    horn *= swell * 0.34
    rng_ = rng(741)
    water = lowpass(rng_.normal(0.0, 1.0, n), 500.0) * 0.18
    water *= 0.4 + 0.6 * np.clip(t / 1.3, 0.0, 1.0)
    return horn + water


def water_splash() -> np.ndarray:
    seconds = 0.85
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(751)
    burst = bandpass(rng_.normal(0.0, 1.0, n), 400.0, 7000.0) * np.exp(-7.0 * t) * 0.55
    bubbles = np.zeros(n)
    for offset, freq, gain in ((0.03, 620.0, 0.4), (0.12, 880.0, 0.25), (0.22, 440.0, 0.2)):
        start = int(offset * SR)
        length = int(0.18 * SR)
        tt = np.arange(length) / SR
        b = np.sin(2.0 * math.pi * (freq + 260.0 * tt) * tt) * np.exp(-16.0 * tt) * gain
        bubbles[start:start + length] += b
    low = lowpass(rng_.normal(0.0, 1.0, n), 300.0) * np.exp(-5.0 * t) * 0.28
    return burst + bubbles + low


def wind_gust() -> np.ndarray:
    seconds = 2.2
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(761)
    base = bandpass(rng_.normal(0.0, 1.0, n), 120.0, 3400.0)
    env = np.sin(np.pi * np.clip(t / seconds, 0.0, 1.0)) ** 1.6
    flutter = 0.72 + 0.28 * np.sin(2.0 * math.pi * 2.3 * t + 0.4) ** 2
    return base * env * flutter * 0.62


def azure_blade() -> np.ndarray:
    seconds = 2.4
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-2.4 * t)
    # Cold glass/steel partials, deliberately not a fanfare.
    partials = ((392.0, 0.28), (587.33, 0.20), (880.0, 0.13), (1174.66, 0.07))
    out = np.zeros(n)
    for freq, gain in partials:
        out += np.sin(2.0 * math.pi * freq * t + 0.2) * gain * env
    strike = bandpass(rng(771).normal(0.0, 1.0, n), 2200.0, 9000.0) * np.exp(-45.0 * t) * 0.18
    return out + strike


def soul_shard() -> np.ndarray:
    seconds = 1.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-3.0 * t)
    out = np.zeros(n)
    for freq, gain in ((1046.5, 0.26), (1568.0, 0.18), (2093.0, 0.10), (2637.0, 0.05)):
        out += np.sin(2.0 * math.pi * freq * t + 0.1) * gain * env
    breath = bandpass(rng(781).normal(0.0, 1.0, n), 500.0, 5000.0) * np.exp(-8.0 * t) * 0.12
    return out + breath


def echo_whisper() -> np.ndarray:
    seconds = 2.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(791)
    # Formant-like air, no intelligible words: the Echo is presence, not speech.
    air = bandpass(rng_.normal(0.0, 1.0, n), 300.0, 2600.0)
    formants = (np.sin(2.0 * math.pi * 196.0 * t) * 0.10
                + np.sin(2.0 * math.pi * 294.0 * t + 0.5) * 0.06
                + np.sin(2.0 * math.pi * 392.0 * t + 1.1) * 0.04)
    env = np.sin(np.pi * np.clip(t / seconds, 0.0, 1.0)) ** 2
    flutter = 0.55 + 0.45 * np.sin(2.0 * math.pi * 0.8 * t + 0.3) ** 2
    return (air * 0.32 + formants) * env * flutter


def stone_shift() -> np.ndarray:
    seconds = 1.7
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(801)
    grind = lowpass(rng_.normal(0.0, 1.0, n), 700.0) * (0.4 + 0.6 * np.exp(-2.0 * t)) * 0.45
    rubble = bandpass(rng_.normal(0.0, 1.0, n), 300.0, 5200.0) * np.exp(-9.0 * t) * 0.25
    thud = np.sin(2.0 * math.pi * 48.0 * t) * np.exp(-7.0 * t) * 0.35
    return grind + rubble + thud


def campfire_loop() -> np.ndarray:
    seconds = 8.0
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(811)
    bed = lowpass(rng_.normal(0.0, 1.0, n), 650.0) * 0.22
    bed += bandpass(rng_.normal(0.0, 1.0, n), 700.0, 2600.0) * 0.06
    out = bed
    for _ in range(26):
        start = int(rng_.uniform(0.0, seconds - 0.12) * SR)
        pop = bandpass(rng_.normal(0.0, 1.0, int(0.08 * SR)), 900.0, 7000.0)
        pop *= np.exp(-55.0 * np.arange(len(pop)) / SR) * rng_.uniform(0.12, 0.38)
        out[start:start + len(pop)] += pop[: max(0, n - start)]
    # Warm low body and a slow breathing modulation.
    out += np.sin(2.0 * math.pi * 55.0 * t) * 0.018
    out *= 0.82 + 0.18 * np.sin(2.0 * math.pi * 2.0 * t / seconds + 0.5) ** 2
    return out


def campfire_rest() -> np.ndarray:
    seconds = 1.9
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(815)
    flare = bandpass(rng_.normal(0.0, 1.0, n), 180.0, 3800.0)
    flare *= np.sin(np.pi * np.clip(t / 1.2, 0.0, 1.0)) ** 2 * 0.38
    breath = lowpass(rng_.normal(0.0, 1.0, n), 900.0) * np.exp(-3.0 * t) * 0.18
    out = flare + breath
    for offset in (0.2, 0.48, 0.72, 1.05):
        pop = bandpass(rng_.normal(0.0, 1.0, int(0.06 * SR)), 900.0, 6500.0)
        pop *= np.exp(-55.0 * np.arange(len(pop)) / SR) * 0.25
        start = int(offset * SR)
        out[start:start + len(pop)] += pop[: max(0, n - start)]
    out += np.sin(2.0 * math.pi * 55.0 * t) * np.exp(-2.0 * t) * 0.12
    return out


def storm_rain_loop() -> np.ndarray:
    seconds = 16.0
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(821)
    rain = highpass(rng_.normal(0.0, 1.0, n), 1200.0) * 0.22
    rain += bandpass(rng_.normal(0.0, 1.0, n), 300.0, 5000.0) * 0.12
    wind = bandpass(rng_.normal(0.0, 1.0, n), 60.0, 900.0) * 0.30
    gust = 0.55 + 0.45 * np.sin(2.0 * math.pi * 3.0 * t / seconds + 0.7) ** 2
    rumble = lowpass(rng_.normal(0.0, 1.0, n), 120.0) * 0.20
    # Two distant low thumps, placed inside the loop, not on the seam.
    thunder = lowpass(rng_.normal(0.0, 1.0, n), 90.0)
    thunder *= np.exp(-1.2 * np.arange(n) / SR) * 0.25
    out = rain + wind * gust + rumble
    for start_sec in (4.5, 12.0):
        start = int(start_sec * SR)
        length = min(n - start, int(2.0 * SR))
        out[start:start + length] += thunder[:length]
    return out


def storm_music_layers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    seconds = 16.0
    n = int(seconds * SR)
    t = np.arange(n) / SR
    # D minor-ish drone: D2, A2, F3, with a slow beating fifth.
    base = np.zeros(n)
    for freq, gain in ((73.42, 0.20), (110.0, 0.11), (174.61, 0.055)):
        base += np.sin(2.0 * math.pi * freq * t + 0.3) * gain
    base *= 0.72 + 0.28 * np.sin(2.0 * math.pi * 2.0 * t / seconds + 0.2) ** 2

    pulse = np.zeros(n)
    # Distant impacts, 3+3+2 feel, but sparse and not a battle drum.
    for start_sec in (0.0, 1.5, 2.8, 4.2, 6.0, 7.5, 8.8, 10.2, 12.0, 13.5, 14.8):
        start = int(start_sec * SR)
        length = min(n - start, int(0.5 * SR))
        tt = np.arange(length) / SR
        hit = np.sin(2.0 * math.pi * 48.0 * tt) * np.exp(-9.0 * tt) * 0.18
        pulse[start:start + length] += hit

    melody = np.zeros(n)
    # High, thin glass harmonics, more weather than tune.
    for start_sec, freq in ((1.5, 1174.66), (5.0, 987.77), (9.0, 880.0), (13.0, 783.99)):
        start = int(start_sec * SR)
        length = min(n - start, int(2.5 * SR))
        tt = np.arange(length) / SR
        ring = (np.sin(2.0 * math.pi * freq * tt)
                + 0.35 * np.sin(2.0 * math.pi * freq * 2.01 * tt)) * np.exp(-1.3 * tt) * 0.07
        melody[start:start + length] += ring
    return base, pulse, melody


def main() -> None:
    write_mono("creature_carapace_chitter_01", carapace_chitter(), 0.72)
    write_mono("creature_carapace_click_01", carapace_click(), 0.62)
    write_mono("creature_carapace_attack_01", carapace_attack(), 0.70)
    write_mono("creature_carapace_death_01", carapace_death(), 0.78)
    write_mono("world_tide_warning_01", tide_warning(), 0.70)
    write_mono("world_water_splash_01", water_splash(), 0.68)
    write_mono("world_wind_gust_01", wind_gust(), 0.60)
    write_mono("world_azure_blade_01", azure_blade(), 0.64)
    write_mono("world_soul_shard_01", soul_shard(), 0.60)
    write_mono("world_echo_whisper_01", echo_whisper(), 0.50)
    write_mono("world_stone_shift_01", stone_shift(), 0.72)
    write_mono("world_campfire_rest_01", campfire_rest(), 0.66)
    write_stereo_loop("campfire_loop_01", campfire_loop(), 0.62)
    write_stereo_loop("storm_rain_loop_01", storm_rain_loop(), 0.66)
    for layer_name, data in zip(("base", "pulse", "melody"), storm_music_layers()):
        write_music_layer(f"labyrinth_storm_{layer_name}", data, 0.56)


if __name__ == "__main__":
    main()

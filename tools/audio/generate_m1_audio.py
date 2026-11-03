"""Generate the project-owned M1 post-Nightmare audio layer.

This is a demo-quality procedural kit, not a final soundtrack. Every file is
synthesized here from oscillators/noise; no third-party samples are copied.
Run from the project root:

    python tools/audio/generate_m1_audio.py

Outputs:
    assets/audio/m1/sfx/*.wav       short mono cues and local loops
    assets/audio/m1/ambience/*.wav  stereo ambience beds (exact PCM loop)
    assets/audio/m1/music/*.ogg     stereo music layers
"""

from __future__ import annotations

import math
import subprocess
import wave
from pathlib import Path

import imageio_ffmpeg
import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "m1"


def t_axis(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * SR), dtype=np.float64) / SR


def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 3) -> np.ndarray:
    hi = min(hi, SR * 0.45)
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x: np.ndarray, cutoff: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, min(cutoff, SR * 0.45), btype="lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x: np.ndarray, cutoff: float, order: int = 3) -> np.ndarray:
    sos = signal.butter(order, max(20.0, cutoff), btype="highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def normalize(x: np.ndarray, peak: float = 0.84) -> np.ndarray:
    top = float(np.max(np.abs(x))) if x.size else 0.0
    return x / top * peak if top > 0.0 else x


def fade(x: np.ndarray, fade_in: float = 0.006, fade_out: float = 0.03) -> np.ndarray:
    out = np.asarray(x, dtype=np.float64).copy()
    n_in = min(len(out), max(1, int(fade_in * SR)))
    n_out = min(len(out), max(1, int(fade_out * SR)))
    if n_in:
        out[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out:
        out[-n_out:] *= np.linspace(1.0, 0.0, n_out)
    return out


def loop_seam(x: np.ndarray, crossfade: float = 0.35) -> np.ndarray:
    n = int(crossfade * SR)
    if n <= 1 or len(x) < n * 3:
        return x
    body = np.asarray(x, dtype=np.float64)[:-n].copy()
    tail = x[-n:]
    ramp = np.linspace(0.0, 1.0, n)
    body[:n] = body[:n] * ramp + tail * (1.0 - ramp)
    edge = min(int(0.012 * SR), len(body) // 8)
    if edge > 1:
        body[:edge] *= np.linspace(0.0, 1.0, edge)
        body[-edge:] *= np.linspace(1.0, 0.0, edge)
    return body


def write_sfx(name: str, data: np.ndarray, peak: float = 0.82) -> None:
    path = OUT / "sfx" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = fade(normalize(data, peak))
    sf.write(str(path), data.astype(np.float32), SR, subtype="PCM_16")
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def write_loop_wav(name: str, data: np.ndarray, peak: float = 0.78) -> None:
    path = OUT / "sfx" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = normalize(loop_seam(np.asarray(data, dtype=np.float64)), peak)
    sf.write(str(path), data.astype(np.float32), SR, subtype="PCM_16")
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def _encode_ogg(stereo: np.ndarray, path: Path) -> None:
    """Encode through ffmpeg; some libsndfile builds crash on long OGG files."""
    tmp = path.with_suffix(".tmp.wav")
    pcm = (np.clip(stereo, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(tmp), "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SR)
        wav_file.writeframes(pcm.tobytes())
    exe = imageio_ffmpeg.get_ffmpeg_exe()
    result = subprocess.run(
        [exe, "-y", "-loglevel", "error", "-i", str(tmp), "-c:a", "libvorbis", "-q:a", "4", str(path)],
        capture_output=True,
        text=True,
    )
    tmp.unlink(missing_ok=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed for {path}: {result.stderr}")


def write_ambience(name: str, data: np.ndarray, peak: float = 0.72) -> None:
    # Ambience stays PCM: Vorbis encoder pre-roll can move the decoded first
    # sample away from zero, producing a measurable seam on long beds. WAV is
    # larger but gives AmbienceDirector an exact forward loop.
    path = OUT / "ambience" / f"{name}.wav"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = normalize(loop_seam(np.asarray(data, dtype=np.float64)), peak)
    stereo = np.stack([data, data], axis=1)
    pcm = (np.clip(stereo, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SR)
        wav_file.writeframes(pcm.tobytes())
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def write_music(name: str, data: np.ndarray, peak: float = 0.55) -> None:
    path = OUT / "music" / f"{name}.ogg"
    path.parent.mkdir(parents=True, exist_ok=True)
    data = normalize(loop_seam(np.asarray(data, dtype=np.float64), 0.6), peak)
    stereo = np.stack([data, data], axis=1)
    _encode_ogg(stereo, path)
    print(f"{path.relative_to(ROOT)}  {len(data) / SR:.2f}s")


def noise_burst(seconds: float, seed: int, lo: float, hi: float, decay: float) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    return bandpass(rng(seed).normal(0.0, 1.0, n), lo, hi) * np.exp(-decay * t)


def tone(seconds: float, freq: float, decay: float = 0.0, phase: float = 0.0) -> np.ndarray:
    t = t_axis(seconds)
    out = np.sin(2.0 * math.pi * freq * t + phase)
    if decay > 0.0:
        out *= np.exp(-decay * t)
    return out


def thud(seconds: float, freq: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    body = np.sin(2.0 * math.pi * freq * t) * np.exp(-9.0 * t)
    grit = lowpass(rng(seed).normal(0.0, 1.0, n), 500.0) * np.exp(-11.0 * t) * 0.45
    return body + grit


def metal_ring(seconds: float, base: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, gain in ((1.0, 0.45), (2.37, 0.22), (3.91, 0.14), (5.13, 0.08)):
        out += np.sin(2.0 * math.pi * base * ratio * t) * gain * np.exp(-5.5 * t)
    out += highpass(rng(seed).normal(0.0, 1.0, n), 1800.0) * np.exp(-24.0 * t) * 0.2
    return out


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------


def p05_cell_door() -> np.ndarray:
    n = int(1.35 * SR)
    out = np.zeros(n)
    for offset, freq, seed in ((0.0, 74.0, 501), (0.18, 92.0, 502)):
        hit = thud(0.5, freq, seed) * 0.8
        start = int(offset * SR)
        out[start:start + len(hit)] += hit[:n - start]
    ring = metal_ring(1.1, 410.0, 503) * 0.32
    out[:len(ring)] += ring
    return out


def p05_radio_chatter() -> np.ndarray:
    seconds = 4.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(511)
    bed = bandpass(rng_.normal(0.0, 1.0, n), 280.0, 2600.0)
    syllables = np.zeros(n)
    for i, offset in enumerate(np.arange(0.18, seconds - 0.20, 0.23)):
        length = int(rng_.uniform(0.08, 0.18) * SR)
        start = int(offset * SR)
        env = np.sin(np.linspace(0.0, math.pi, length)) ** 1.5
        partial = bandpass(
            rng_.normal(0.0, 1.0, length),
            420.0 + 180.0 * (i % 3),
            1600.0 + 500.0 * ((i + 1) % 3),
        )
        syllables[start:start + length] += partial * env
    carrier = 0.55 + 0.45 * np.sin(2.0 * math.pi * 0.7 * t) ** 2
    return bed * 0.18 * carrier + syllables * 0.6


def p05_mirror_whisper() -> np.ndarray:
    seconds = 1.9
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.18, 0.0, 1.0) * np.clip((seconds - t) / 1.0, 0.0, 1.0)
    air = bandpass(rng(521).normal(0.0, 1.0, n), 650.0, 4200.0)
    flutter = 0.35 + 0.65 * np.sin(2.0 * math.pi * 5.4 * t) ** 2
    low = np.sin(2.0 * math.pi * 118.0 * t) * 0.16
    return (air * flutter * 0.35 + low) * env


def p05_paper_rustle() -> np.ndarray:
    n = int(0.55 * SR)
    t = np.arange(n) / SR
    rustle = bandpass(rng(531).normal(0.0, 1.0, n), 1800.0, 8500.0)
    crinkle = np.zeros(n)
    for offset in (0.06, 0.17, 0.28):
        start = int(offset * SR)
        length = int(0.04 * SR)
        crinkle[start:start + length] += bandpass(
            rng(532 + start).normal(0.0, 1.0, length), 2500.0, 9000.0
        ) * 0.6
    return rustle * (0.25 + 0.75 * np.exp(-4.0 * t)) + crinkle


def p06_car_idle() -> np.ndarray:
    seconds = 3.6
    n = int(seconds * SR)
    t = np.arange(n) / SR
    engine = (
        np.sin(2.0 * math.pi * 48.0 * t)
        + 0.45 * np.sin(2.0 * math.pi * 96.0 * t)
        + 0.2 * np.sin(2.0 * math.pi * 144.0 * t)
    )
    engine *= 0.6 + 0.4 * np.sin(2.0 * math.pi * 11.0 * t) ** 2
    hiss = lowpass(rng(541).normal(0.0, 1.0, n), 900.0) * 0.18
    return engine * 0.6 + hiss


def p06_car_door() -> np.ndarray:
    n = int(0.8 * SR)
    out = np.zeros(n)
    hit = thud(0.45, 88.0, 551) * 0.7
    out[:len(hit)] += hit
    ring = metal_ring(0.6, 520.0, 552) * 0.25
    out[:len(ring)] += ring
    return out


def p06_checkpoint_beep() -> np.ndarray:
    n = int(0.55 * SR)
    out = np.zeros(n)
    for offset, freq in ((0.02, 880.0), (0.20, 1174.66)):
        start = int(offset * SR)
        beep = tone(0.16, freq, 10.0) * 0.55
        out[start:start + len(beep)] += beep[:n - start]
    return out


def p07_gate_scan() -> np.ndarray:
    seconds = 1.25
    n = int(seconds * SR)
    t = np.arange(n) / SR
    sweep = np.sin(2.0 * math.pi * (260.0 + 720.0 * t / seconds) * t) * 0.35
    tick = np.zeros(n)
    for offset in (0.12, 0.48, 0.84):
        start = int(offset * SR)
        tick[start:start + int(0.025 * SR)] += bandpass(
            rng(561).normal(0.0, 1.0, int(0.025 * SR)), 1800.0, 7000.0
        ) * 0.7
    return sweep * np.exp(-1.8 * t) + tick


def p07_flag_flap() -> np.ndarray:
    # Long enough not to read as a mechanical 2-second flap loop.
    seconds = 6.5
    n = int(seconds * SR)
    t = np.arange(n) / SR
    air = bandpass(rng(571).normal(0.0, 1.0, n), 180.0, 2400.0)
    gust = 0.25 + 0.75 * np.sin(2.0 * math.pi * 0.9 * t + 0.2) ** 2
    flutter = 0.72 + 0.28 * np.sin(2.0 * math.pi * 2.8 * t + 0.5) ** 2
    return air * gust * flutter * 0.62


def p08_terminal_beep() -> np.ndarray:
    n = int(0.42 * SR)
    out = np.zeros(n)
    for offset, freq, gain in ((0.0, 1320.0, 0.5), (0.13, 1760.0, 0.3)):
        start = int(offset * SR)
        beep = tone(0.1, freq, 16.0) * gain
        out[start:start + len(beep)] += beep[:n - start]
    return out


def p08_crowd_walla() -> np.ndarray:
    seconds = 7.5
    n = int(seconds * SR)
    rng_ = rng(581)
    out = np.zeros(n)
    for i in range(11):
        offset = rng_.uniform(0.0, seconds - 0.6)
        length = int(rng_.uniform(0.25, 0.7) * SR)
        start = int(offset * SR)
        if start + length >= n:
            continue
        tt = np.arange(length) / SR
        env = np.sin(np.linspace(0.0, math.pi, length)) ** 1.2
        voice = bandpass(
            rng_.normal(0.0, 1.0, length),
            220.0 + 80.0 * (i % 4),
            900.0 + 240.0 * (i % 3),
        )
        voice += 0.35 * np.sin(2.0 * math.pi * (115.0 + 17.0 * i) * tt)
        out[start:start + length] += voice * env * rng_.uniform(0.25, 0.65)
    return out + lowpass(rng_.normal(0.0, 1.0, n), 500.0) * 0.12


def p09_hvac() -> np.ndarray:
    seconds = 6.5
    n = int(seconds * SR)
    t = np.arange(n) / SR
    hum = (
        np.sin(2.0 * math.pi * 60.0 * t)
        + 0.4 * np.sin(2.0 * math.pi * 120.0 * t)
        + 0.2 * np.sin(2.0 * math.pi * 180.0 * t)
    ) * 0.3
    air = lowpass(rng(591).normal(0.0, 1.0, n), 2200.0) * 0.22
    return hum + air


def p09_induction_tone() -> np.ndarray:
    seconds = 2.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.4, 0.0, 1.0) * np.clip((seconds - t) / 1.0, 0.0, 1.0)
    out = np.zeros(n)
    for freq, gain in ((55.0, 0.5), (82.5, 0.25), (110.0, 0.15), (220.0, 0.08)):
        out += np.sin(2.0 * math.pi * freq * t) * gain
    shimmer = bandpass(rng(601).normal(0.0, 1.0, n), 1200.0, 5000.0) * 0.12
    return (out + shimmer) * env


def p09_capsule_hiss() -> np.ndarray:
    n = int(1.4 * SR)
    t = np.arange(n) / SR
    hiss = highpass(rng(611).normal(0.0, 1.0, n), 1200.0)
    env = np.clip(t / 0.05, 0.0, 1.0) * np.exp(-2.2 * t)
    seal = thud(0.3, 105.0, 612) * 0.4
    out = hiss * env * 0.45
    out[:len(seal)] += seal
    return out


def p09_capsule_hum() -> np.ndarray:
    seconds = 3.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    hum = (
        np.sin(2.0 * math.pi * 70.0 * t)
        + 0.3 * np.sin(2.0 * math.pi * 140.0 * t)
        + 0.12 * np.sin(2.0 * math.pi * 210.0 * t)
    )
    return hum * (0.65 + 0.35 * np.sin(2.0 * math.pi * 0.9 * t) ** 2)


def b01_sea_lap() -> np.ndarray:
    seconds = 10.0
    n = int(seconds * SR)
    rng_ = rng(621)
    base = lowpass(rng_.normal(0.0, 1.0, n), 900.0)
    t = np.arange(n) / SR
    swell = 0.35 + 0.65 * np.sin(2.0 * math.pi * 0.11 * t + 0.8) ** 2
    wash = bandpass(rng_.normal(0.0, 1.0, n), 120.0, 2200.0) * 0.35
    return (base * 0.25 + wash) * swell


def b01_statue_groan() -> np.ndarray:
    seconds = 2.5
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.clip(t / 0.35, 0.0, 1.0) * np.clip((seconds - t) / 1.2, 0.0, 1.0)
    groan = np.sin(2.0 * math.pi * (48.0 + 18.0 * t / seconds) * t) * 0.4
    grit = bandpass(rng(631).normal(0.0, 1.0, n), 120.0, 900.0) * 0.25
    return (groan + grit) * env


def b01_shroud_flare() -> np.ndarray:
    seconds = 2.1
    n = int(seconds * SR)
    t = np.arange(n) / SR
    whoosh = bandpass(rng(641).normal(0.0, 1.0, n), 300.0, 5500.0)
    env = np.sin(np.pi * np.clip(t / seconds, 0.0, 1.0)) ** 1.8
    shimmer = np.zeros(n)
    for freq, gain in ((659.25, 0.18), (987.77, 0.12), (1318.5, 0.07)):
        shimmer += np.sin(2.0 * math.pi * freq * t) * gain * np.exp(-2.2 * t)
    return whoosh * env * 0.5 + shimmer


def b02_water_flow() -> np.ndarray:
    seconds = 8.0
    n = int(seconds * SR)
    rng_ = rng(651)
    flow = bandpass(rng_.normal(0.0, 1.0, n), 180.0, 3800.0)
    t = np.arange(n) / SR
    bubbles = 0.2 * np.sin(2.0 * math.pi * (1.7 + 0.4 * np.sin(0.4 * t)) * t)
    return flow * (0.3 + 0.2 * bubbles)


def b02_wave_crash() -> np.ndarray:
    seconds = 1.8
    n = int(seconds * SR)
    t = np.arange(n) / SR
    swell = np.sin(np.pi * np.clip(t / 1.0, 0.0, 1.0)) ** 1.6
    crash = bandpass(rng(661).normal(0.0, 1.0, n), 80.0, 6500.0) * swell * 0.55
    foam = highpass(rng(662).normal(0.0, 1.0, n), 2200.0) * np.exp(-2.5 * t) * 0.18
    return crash + foam


def b02_rockfall_small() -> np.ndarray:
    n = int(1.25 * SR)
    out = np.zeros(n)
    for i, offset in enumerate((0.02, 0.16, 0.29, 0.45, 0.63, 0.82)):
        start = int(offset * SR)
        hit = thud(0.18 + 0.03 * (i % 3), 150.0 + 24.0 * i, 671 + i) * (0.5 - 0.05 * i)
        out[start:start + len(hit)] += hit[:n - start]
    return out


def m1_camp_night_stinger() -> np.ndarray:
    seconds = 3.4
    n = int(seconds * SR)
    t = np.arange(n) / SR
    sub = np.sin(2.0 * math.pi * 43.65 * t) * np.exp(-1.8 * t) * 0.4
    glass = np.zeros(n)
    for freq, gain in ((523.25, 0.16), (783.99, 0.11), (1046.5, 0.06)):
        glass += np.sin(2.0 * math.pi * freq * t) * gain * np.exp(-2.6 * t)
    wind = bandpass(rng(681).normal(0.0, 1.0, n), 180.0, 1600.0) * np.exp(-1.0 * t) * 0.12
    return sub + glass + wind


# ---------------------------------------------------------------------------
# Music and ambience
# ---------------------------------------------------------------------------


def music_layers(seconds: float, root: float, pulse: float, seed: int):
    t = t_axis(seconds)
    rng_ = rng(seed)
    base = (
        np.sin(2.0 * math.pi * root * t)
        + 0.32 * np.sin(2.0 * math.pi * root * 1.5 * t)
        + 0.16 * np.sin(2.0 * math.pi * root * 2.0 * t)
    )
    air = lowpass(rng_.normal(0.0, 1.0, len(t)), 420.0) * 0.12
    base = (base * 0.22 + air) * (0.7 + 0.3 * np.sin(2.0 * math.pi * 0.05 * t) ** 2)
    pulse_layer = np.sin(2.0 * math.pi * pulse * t) * (0.5 + 0.5 * np.sin(2.0 * math.pi * 0.55 * t) ** 2)
    pulse_layer *= 0.22
    melody = np.zeros(len(t))
    # Sparse, non-resolving notes; deliberately not a trailer melody.
    notes = (1.0, 1.2, 1.5, 1.8, 1.2, 1.0)
    start = int(1.2 * SR)
    for i, ratio in enumerate(notes):
        length = min(int(2.2 * SR), len(t) - start)
        if length <= 0:
            break
        tt = np.arange(length) / SR
        env = np.exp(-1.7 * tt) * np.clip(tt / 0.08, 0.0, 1.0)
        melody[start:start + length] += np.sin(2.0 * math.pi * root * 4.0 * ratio * tt) * env * 0.08
        start += int(2.45 * SR)
    return base, pulse_layer, melody


def ambience_precinct(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    room = lowpass(rng_.normal(0.0, 1.0, n), 220.0) * 0.22
    hum = np.sin(2.0 * math.pi * 60.0 * t) * 0.06
    rain = bandpass(rng_.normal(0.0, 1.0, n), 900.0, 7000.0) * 0.12
    rain *= 0.45 + 0.55 * np.sin(2.0 * math.pi * 0.09 * t) ** 2
    radio = bandpass(rng_.normal(0.0, 1.0, n), 300.0, 1800.0) * 0.035
    radio *= 0.2 + 0.8 * (np.sin(2.0 * math.pi * 0.13 * t) > 0.7)
    return room + hum + rain + radio


def ambience_academy(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    wind = bandpass(rng_.normal(0.0, 1.0, n), 100.0, 2600.0)
    wind *= 0.35 + 0.65 * np.sin(2.0 * math.pi * 0.07 * t + 0.4) ** 2
    city = lowpass(rng_.normal(0.0, 1.0, n), 400.0) * 0.12
    snow = highpass(rng_.normal(0.0, 1.0, n), 3000.0) * 0.035
    hum = np.sin(2.0 * math.pi * 50.0 * t) * 0.035
    return wind * 0.25 + city + snow + hum


def ambience_sleeper(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    hvac = lowpass(rng_.normal(0.0, 1.0, n), 1800.0) * 0.14
    hum = np.sin(2.0 * math.pi * 70.0 * t) * 0.08 + np.sin(2.0 * math.pi * 140.0 * t) * 0.025
    clock = np.zeros(n)
    for offset in np.arange(0.4, seconds, 1.0):
        start = int(offset * SR)
        tick = tone(0.035, 1800.0, 70.0) * 0.08
        clock[start:start + len(tick)] += tick[:n - start]
    return hvac + hum + clock


def ambience_black_sea(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    sea = bandpass(rng_.normal(0.0, 1.0, n), 70.0, 1800.0)
    sea *= 0.25 + 0.75 * np.sin(2.0 * math.pi * 0.055 * t + 0.2) ** 2
    wind = bandpass(rng_.normal(0.0, 1.0, n), 120.0, 2600.0) * 0.09
    deep = np.sin(2.0 * math.pi * 43.0 * t) * 0.04
    return sea * 0.25 + wind + deep


def ambience_descent(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    water = bandpass(rng_.normal(0.0, 1.0, n), 160.0, 4200.0) * 0.16
    water *= 0.35 + 0.65 * np.sin(2.0 * math.pi * 0.11 * t + 0.6) ** 2
    wind = bandpass(rng_.normal(0.0, 1.0, n), 90.0, 1600.0) * 0.08
    stone = lowpass(rng_.normal(0.0, 1.0, n), 180.0) * 0.06
    return water + wind + stone


def ambience_camp_night(seconds: float, seed: int) -> np.ndarray:
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng_ = rng(seed)
    # Fire/crackle is the positional CampfireLoop; this bed is night wind and
    # the distant sea only, so the campfire is not doubled.
    wind = bandpass(rng_.normal(0.0, 1.0, n), 100.0, 1800.0)
    wind *= 0.4 + 0.6 * np.sin(2.0 * math.pi * 0.04 * t) ** 2
    sea = bandpass(rng_.normal(0.0, 1.0, n), 80.0, 900.0) * 0.04
    return wind * 0.22 + sea


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # SFX / local loops
    write_sfx("p05_cell_door_01", p05_cell_door())
    write_loop_wav("p05_radio_chatter_01", p05_radio_chatter())
    write_sfx("p05_mirror_whisper_01", p05_mirror_whisper())
    write_sfx("p05_paper_rustle_01", p05_paper_rustle())
    write_loop_wav("p05_hvac_01", p09_hvac())
    write_loop_wav("p06_car_idle_01", p06_car_idle())
    write_sfx("p06_car_door_01", p06_car_door())
    write_sfx("p06_checkpoint_beep_01", p06_checkpoint_beep())
    write_sfx("p07_gate_scan_01", p07_gate_scan())
    write_loop_wav("p07_flag_flap_01", p07_flag_flap())
    write_sfx("p08_terminal_beep_01", p08_terminal_beep())
    write_loop_wav("p08_crowd_walla_01", p08_crowd_walla())
    write_loop_wav("p09_hvac_01", p09_hvac())
    write_sfx("p09_induction_tone_01", p09_induction_tone())
    write_sfx("p09_capsule_hiss_01", p09_capsule_hiss())
    write_loop_wav("p09_capsule_hum_01", p09_capsule_hum())
    write_loop_wav("b01_sea_lap_01", b01_sea_lap())
    write_sfx("b01_statue_groan_01", b01_statue_groan())
    write_sfx("b01_shroud_flare_01", b01_shroud_flare())
    write_loop_wav("b02_water_flow_01", b02_water_flow())
    write_sfx("b02_wave_crash_01", b02_wave_crash())
    write_sfx("b02_rockfall_small_01", b02_rockfall_small())
    write_sfx("m1_camp_night_stinger_01", m1_camp_night_stinger())

    # Ambience beds
    write_ambience("m1_precinct", ambience_precinct(16.0, 1001))
    write_ambience("m1_academy", ambience_academy(18.0, 1002))
    write_ambience("m1_sleeper", ambience_sleeper(16.0, 1003))
    write_ambience("m1_black_sea", ambience_black_sea(20.0, 1004))
    write_ambience("m1_descent", ambience_descent(18.0, 1005))
    write_ambience("m1_camp_night", ambience_camp_night(20.0, 1006))

    # Music: base / pulse / melody for each cue
    cues = (
        ("m1_precinct", 16.0, 55.0, 41.0, 1101),
        ("m1_academy", 18.0, 65.41, 49.0, 1102),
        ("m1_sleeper", 16.0, 49.0, 36.7, 1103),
        ("m1_black_sea", 20.0, 43.65, 32.7, 1104),
        ("m1_descent", 18.0, 46.25, 34.65, 1105),
    )
    for cue, seconds, root, pulse, seed in cues:
        base, pulse_layer, melody = music_layers(seconds, root, pulse, seed)
        write_music(f"{cue}_base", base, 0.52)
        write_music(f"{cue}_pulse", pulse_layer, 0.44)
        write_music(f"{cue}_melody", melody, 0.38)

    print("M1 audio generation complete.")


if __name__ == "__main__":
    main()

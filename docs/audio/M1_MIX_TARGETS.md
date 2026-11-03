# M1 mix targets and validation notes

**Дата:** 2026-11-03  
**Статус:** target values; full mix **NOT TESTED**.

| Слой | Цель | Текущее доказательство |
|---|---|---|
| Voice | −18…−16 LUFS | VO files absent; text-only M1 |
| Music | −20…−18 LUFS | procedural layers generated, not auditioned |
| Ambience | −24…−20 LUFS | generated beds, not auditioned |
| SFX | peak −12…−6 dBFS | per-file peak/DC probe |
| UI | −20…−16 LUFS | existing UI cues unchanged |
| Master | −16…−14 LUFS; limiter −1 dB | existing bus compressor/limiter |
| Reverb | per-scene profile | `precinct_hall`, `academy_hall`, `sleeper_hall`, `black_sea`, `descent` |
| Ducking | music −8 dB, ambience −4 dB, local loops −4 dB | text dialogue line_started/finished hook |
| Loop seam | < 0.005 | `tools/audio/check_demo_audio.py` |

## Open items

- No human listening pass; do not claim final balance.
- SFX reverb send / full occlusion update remain P2.
- Final music and VO are not part of this demo layer.

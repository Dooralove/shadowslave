# M1 listening and mix protocol

**Дата:** 2026-11-03  
**Автор:** A09 / Chat 09 — Audio & VFX  
**Статус:** **PROTOCOL CREATED; LISTENING NOT PERFORMED — NOT TESTED.**  
**Связанные файлы:** `docs/audio/M1_MIX_TARGETS.md`, `tools/audio/check_demo_audio.py`, `tools/audio/validate_m1_audio.gd`.

## 1. Цель

Проверить не «файлы существуют», а слышимость, баланс и отсутствие режущих
артефактов в трёх опорных сценах M1. Автоматический probe проверяет cue,
профили, частицы и seams; только человек проверяет музыку, громкость и
утомляемость.

## 2. Сцены и проход

| # | Сцена | Что слушать | Время |
|---|---|---|---:|
| 1 | `police_precinct` | дождь за окном, гул, радио, зеркало, дверь | 3–4 мин |
| 2 | `academy_approach` → `academy_gate` | машина, КПП, ветер/снег, флаги, ворота | 5–6 мин |
| 3 | `academy_sleeper_center` → `black_sea_platform` → `tide_descent` | индукция, капсула, море, Плащ, прилив | 8–10 мин |

Проход выполнять в обычном режиме, без телепорта, с включёнными субтитрами.
Один повтор — с наушниками; один — с динамиками ноутбука.

## 3. Проверки

- [ ] P05: слышны дождь/радио, но они не перекрывают текст.
- [ ] P06/P07: машина и КПП читаются по позиции; КПП не звучит как UI.
- [ ] P08: толпа не маскирует терминал; терминал имеет отдельный cue.
- [ ] P09: индукция и капсула не играют одновременно; гул не «гудит» в голове.
- [ ] B01: море/ветер не поверх диалога; Плащ слышен один раз.
- [ ] B02: прилив предупреждает до гейта; wave/rockfall не клиппуют.
- [ ] Z10: после `camp_night_seen` музыка/фон меняются без обрыва.
- [ ] Нет двойного music/ambience на входе в сцену.
- [ ] Нет UI-клика на мировых объектах.
- [ ] Нет щелчка на loop seam (audible click).
- [ ] Субтитры ключевых неречевых cue видны и не перекрывают цель.

## 4. Технические измерения

```powershell
python tools/audio/check_demo_audio.py
python tools/audio/audit_voice_coverage.py
godot --headless --path . --script res://tools/audio/validate_m1_audio.gd
godot --headless --path . --script res://tools/audio/validate_m1_events.gd
```

Цели:

| Категория | Цель |
|---|---|
| Voice | −18…−16 LUFS integrated (когда появится) |
| Music | −20…−18 LUFS; duck −8 dB при диалоге |
| Ambience | −24…−20 LUFS; duck −4 dB при диалоге |
| SFX | peak −12…−6 dBFS per file; limiter ceiling −1 dB |
| Общий микс | −16…−14 LUFS |
| Loop seam | < 0.005 sample discontinuity |

## 5. Результат

Заполнить таблицу после прохода. До этого писать только **NOT TESTED**.

| Проверка | Результат | Комментарий |
|---|---|---|
| P05 | NOT TESTED | — |
| P06/P07 | NOT TESTED | — |
| P08 | NOT TESTED | — |
| P09 | NOT TESTED | — |
| B01 | NOT TESTED | — |
| B02 | NOT TESTED | — |
| Z10 | NOT TESTED | — |
| Наушники | NOT TESTED | — |
| Динамики | NOT TESTED | — |

**Подпись:** ожидается A00/A10/пользователь. A09 не объявляет PASS без
фактического прослушивания.

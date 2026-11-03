# M1 VO coverage — audit and policy

**Дата:** 2026-11-03  
**Автор:** A09 / Chat 09 — Audio & VFX  
**Статус:** **COVERAGE AUDIT ONLY. Финального VO нет.**  
**Основание:** `resources/dialogue/post_nightmare/*.tres`, `scripts/dialogue/dialogue_runner.gd`, `assets/audio/voice/lines/`.

## 1. Что проверено

`DialogueRunner` выводит voice ID как `<sequence_basename>_<index:03d>`, если
`DialogueLine.voice_id` пуст. Аудит повторил это правило и проверил наличие
`.wav`/`.ogg` в `assets/audio/voice/lines/`.

| Метрика | Значение |
|---|---:|
| M1-последовательностей | 12 |
| Реплик в них | 29 |
| Реплик с VO-файлом | 0 |
| Реплик без VO | **29** |

Манифест: `resources/audio/voice_manifest_m1.json` (импортная таблица, не
runtime-ассет). Он содержит `sequence`, `index`, `voice_id`, `speaker`,
`duration`, `has_voice`.

## 2. Последовательности

`academy_campus_guide`, `academy_capsule`, `academy_checkpoint`,
`academy_jet`, `academy_julius`, `black_sea_descent`, `black_sea_stars`,
`black_sea_sword`, `precinct_exit`, `precinct_mirror`, `precinct_wake`,
`tide_descent_warning`.

## 3. Политика M1

- M1 принимается с **text-only** диалогами: субтитры/панель HUD остаются,
  `VoiceDirector.play_line()` для отсутствующего ID — тихий no-op.
- SAPI и любые синтезированные голоса — **только dev-placeholder**, не
  финальный VO и не release-ассет без отдельного решения A00/пользователя.
- Нельзя писать «VO готов» или добавлять SAPI-файлы в `assets/audio/voice`
  без лицензионного решения и маркировки.
- Финальный VO — P1/M2–M3; кандидаты должны быть записаны/лицензированы и
  внесены в `docs/ASSET_LICENSES.md` до импорта.

## 4. Что делает A09

1. Держит манифест в актуальном состоянии при изменении A01-диалогов.
2. Обеспечивает captions для ключевых неречевых cue (см. `SfxCue.caption`).
3. Не блокирует M1 из-за VO; текстовая подача — согласованный fallback.
4. При появлении файлов проверяет: ID совпадает с `DialogueRunner`, формат
   48 kHz mono, peak ≤ −3 dBTP, громкость Voice-шины.

## 5. Проверка

```powershell
python tools/audio/audit_voice_coverage.py
```

Ожидаемо для текущего среза: `sequences=12 lines=29 missing=29`.
Слуховой тест VO — **NOT TESTED**; файлов нет.

# Voice pipeline (ShadowSlave)

Статус на 2026-11-02: **pipeline готов; 146 реплик пролога/каравана + 30 барков озвучены временным Windows SAPI (Microsoft Irina, ru-RU); 83 реплики ещё без файлов.** Это не финальное VO.

## Текущие SAPI-плейсхолдеры

- `assets/audio/voice/lines/*.wav` — 146 реплик из `resources/dialogue/prologue` и `resources/dialogue/caravan`.
- `assets/audio/voice/barks/*.wav` — все 30 барков из `data/dialogues/sunny_barks.json`.
- Голос: Microsoft Irina Desktop (ru-RU), синтез через Windows `System.Speech`.
- Это временные файлы для проверки pipeline/ducking, не финальное VO. Условия использования голоса Windows/SAPI действуют; при релизе заменить на лицензированное TTS/запись.
- Пересобрать source-таблицу: `godot --headless --path . --script res://tools/audio/export_voice_lines.gd`.
- Генерация SAPI: `powershell -ExecutionPolicy Bypass -File tools/audio/generate_sapi_voice.ps1 -Voice "Microsoft Irina Desktop"`, либо заменить своим TTS.

## ID

- Сюжетная реплика: `<имя_файла_sequence>_<индекс_строки:03d>`, например `sip_1_000` или `pilgrim_bell_003`.
- Барк: `bark_<id_из_json>`, например `bark_CARAVAN_THREAT_03`.

`resources/audio/voice_manifest.json` — импортная таблица ID (229 реплик + 30 барков), не игровые данные. Пересобрать:

```powershell
python tools/audio/build_voice_manifest.py
```

## Файлы

Положить запись в один из путей:

```text
assets/audio/voice/lines/<line_id>.wav
assets/audio/voice/lines/<line_id>.ogg
assets/audio/voice/barks/<bark_id>.wav
assets/audio/voice/barks/<bark_id>.ogg
```

`VoiceDirector.play_line()` сначала ищет файл по ID, затем регистрирует его в памяти. Если файла нет — тихий no-op, диалог продолжается по субтитрам. `DialogueRunner` не автопродвигает реплику по голосу; тайминг остаётся за `DialogueLine.duration` и вводом игрока.

## Запись

- Один файл — одна реплика; не склеивать сцены.
- 48 kHz / 24 bit или 44.1 kHz / 16 bit, mono, пик не выше −1 dBFS.
- Нормализовать к −16…−18 LUFS для речи; музыку не подмешивать в VO.
- Имена файлов — только из manifest; при смене текста/порядка строк пересобрать manifest.
- Перед релизом проверить: все ID имеют файл, нет missing, нет клиппинга, субтитры совпадают.

## Ducking

`AudioDirector` при `voice_started` опускает музыку на −8 dB и возвращает после `voice_finished`. Ambience пока не дакается отдельно; это следующий шаг.

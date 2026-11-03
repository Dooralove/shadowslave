# Blind listening test — P2

Статус: **NOT TESTED**. AI-агент не слышит звук и не может субъективно оценить тембр, разборчивость SAPI, loop seam или приятность микса. Этот документ — протокол для человеческого слушателя; объективные проверки выполняются отдельно.

## Подготовка

1. Запустить проект с реальным аудиовыходом (не `--headless`).
2. Сбросить настройки: `user://settings.cfg` удалить или нажать «Сброс».
3. Проверить, что в Sound-вкладке доступны:
   - субтитры важных звуков;
   - моно-сведение;
   - динамический диапазон (полный/сниженный).
4. Второй человек (ведущий теста) выбирает порядок A/B и не сообщает listener, какой вариант включён.

## Сессии

| Сессия | Сцена | Что слушать |
|---|---|---|
| S1 | Main menu → prologue | hover/click/focus UI, меню-музыка, голос, отсутствие щелчков |
| S2 | Caravan arrival → camp | три слоя музыки, ambience, шаги, переходы, loop seam |
| S3 | Shadow Sanctuary → finale | ritual offering, sanctuary ambience, finale theme, финальный микс |
| S4 | Labyrinth first fragment, Z01→Z05→Z10→Z13→Z17 | 18 зон, storm/tide, random details, reverb, occlusion |

## A/B

- A — full stereo, full dynamic range, captions on.
- B — mono downmix, reduced dynamic range, captions on.
- Для S3–S4 дополнительно: pause → музыка/ambience/UI продолжаются, gameplay SFX и voice замирают; unpause возвращает.

Порядок A/B для каждой сессии выбирается случайно и записывается ведущим после прослушивания.

## Оценки (1–5)

- разборчивость голоса;
- баланс music/ambience/SFX/voice/UI;
- слышимость loop seam и повторов;
- комфорт при длительном слушании;
- полезность captions;
- приемлемость mono;
- разница full/reduced dynamic range.

## Критерии приёмки

- нет клиппинга и резких скачков громкости;
- voice слышен поверх музыки и ambience;
- SFX не маскируют голос;
- loop seam не слышен на 16-секундных петлях;
- captions появляются для важных звуков и не мешают;
- mono остаётся разборчивым;
- paused-состояние не оставляет зацикленных SFX/voice.

## Объективные проверки перед тестом

```powershell
godot --headless --path . --import
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_system.gd -gexit
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_playback.gd -gexit
python tools/audio/measure_loudness.py
```

Результаты теста записывать с датой, версией сборки, headphones/speakers и именем listener. Без этой записи тест считается **NOT TESTED**.

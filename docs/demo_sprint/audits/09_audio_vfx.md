# 09 — Audio & VFX: аудит

**Дата:** 2026-11-02  
**Автор:** Chat 09 — Lead Audio Designer / VFX Artist  
**Полный отчёт:** [`audits/audio_vfx.md`](audio_vfx.md)  
**Дизайн:** [`design/audio_vfx_design.md`](../design/audio_vfx_design.md)  
**QA:** [`qa/audio_vfx_report.md`](../qa/audio_vfx_report.md)

## Сводка

- До сессии у Лабиринта был каркас `AudioDirector`, но без creature/storm/campfire/tide-warning слоя и почти без VFX.
- Добавлено 12 SFX, 1 music-cue (3 слоя), 2 ambience-петли, 6 VFX-сцен; всё project-owned.
- Подключены бой, смерть, подборы, NPC, костёр, прилив, шторм и квестовые сигналы.
- Исправлены: отсутствующий autoload `AudioDirector`, приоритеты `SfxPool`, UI-клик на мировых объектах, hit+death дубль, loop seam.
- Целевые 77 тестов зелёные (53 audio/VFX + 24 combat regression); сцена и probe работают; слуховой тест и полный ручной проход — **NOT TESTED**.
- Полный GUT не завершён (внешний тест); это зафиксировано в QA-отчёте.


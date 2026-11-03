# 07 Environment Art — sprint report

**Дата:** 2026-11-02  
**Статус:** первый целостный environment-art pass по `labyrinth_first_fragment`; см. полный аудит и доказательства.

- **Основной аудит:** [`environment_art.md`](environment_art.md)
- **Art direction:** [`../design/environment_art_direction.md`](../design/environment_art_direction.md)
- **Implementation specification (Stage 2):** [`../implementation/environment_art_implementation.md`](../implementation/environment_art_implementation.md)
- **Превью:** `docs/art/previews/forgotten_shore/environment_art/`

**Охват этого прохода:** `labyrinth_first_fragment` (18 зон), коралловый кит C1/C2, статуя, свет/небо/вода/дождь, приливная отмель, сет-дрессинг, проверка 1080p.  
**Вне охвата:** полный повторный аудит S00–S15 и P2–P5; Soul Sea kit; `coral_labyrinth` как sandbox.  
**Ключевой результат:** targeted GUT 13/13 (332 assert), 123,8 FPS при 1920×1080, 857 МБ VRAM; коллизии/маршруты не изменены.  
**Открыто:** Z15/Z18 — скальные полки; hero-туша/скелет; decals/водоросли/ракушки; полный ручной проход; draw calls 1593 (чуть выше 1500).

# ShadowSlave — Audio Design Document (ADD)

**Версия:** 1.0  
**Дата:** 2026-11-01  
**Статус:** аудит + концепция. Игровые сцены, скрипты, ресурсы, настройки и Git не изменялись.  
**Назначение:** практическое ТЗ на звуковое оформление игры, а не коллекция общих идей.

### Содержание

0. Как читать этот документ
1. Executive summary
2. Аудит текущего состояния
3. Глобальное направление звука
4. Аудиоконцепции локаций (включая 18 зон Лабиринта)
5. Сводная таблица музыкальных референсов
6. Сводная таблица звуков окружения
7. Каталог SFX
8. AI Voice Acting
9. AI-генерация музыки и звуков
10. Архитектура аудиосистемы в Godot
11. Приоритетный план внедрения
12. Риски и критерии приёмки
13. Приложения
14. Источники

---

## 0. Как читать этот документ

### 0.1. Статусы

| Статус | Значение |
|---|---|
| **РЕАЛИЗОВАНО** | Есть в текущем дереве проекта и может быть увидено/услышано игроком. |
| **ЗАПЛАНИРОВАНО** | Есть сцена, маркер, персонаж или механика, но контент ещё не подключён. |
| **ПРЕДЛОЖЕНИЕ** | Авторская рекомендация этого ADD; в проекте пока отсутствует. |
| **НЕ ПРОВЕРЕНО** | Факт не подтверждён прослушиванием, запуском или замером. |

### 0.2. Приоритеты

| Приоритет | Что означает | Пример |
|---|---|---|
| **Critical** | Без этого звук игры не работает как система; делать первым. | Audio Bus Layout, AudioDirector, базовые SFX, настройки громкости. |
| **High** | Сильно влияет на атмосферу и качество первого прохождения. | Музыка пролога/каравана, ambience ключевых локаций, голос Санни. |
| **Medium** | Заметно улучшает погружение, но не блокирует прохождение. | Вариации шагов, reverb-зоны, редкие supernatural-звуки. |
| **Low** | Полировка, необязательные детали, sandbox. | Дальние шумы, UI-анимации звука, dev-арены. |

### 0.3. Границы аудита

- Аудит **не является** юридическим заключением по лицензиям.
- Все ссылки на музыку и фильмы — **референсы для личного некоммерческого проекта**, а не разрешение на распространение чужих записей.
- Ни один существующий аудиофайл не был прослушан в рамках этого аудита: в проекте нет DAW/плеера, а запуск игры не выполнялся. Всё, что касается качества на слух, помечено **НЕ ПРОВЕРЕНО**.
- Полный ручной проход игры не выполнялся; выводы о сценах сделаны по коду, `.tscn`, `.tres` и документации.

### 0.4. Ключевое разделение

1. **Референс** — существующая композиция/звук, на который мы ориентируемся. Хранится ссылкой в документе, не аудиофайлом в репозитории.
2. **Temp track** — чужая музыка, временно поставленная в личную сборку. Не коммитится, не распространяется.
3. **Оригинальный AI/записанный ассет** — то, что становится финальным звуком игры и регистрируется в `docs/ASSET_LICENSES.md`.

---

## 1. Executive summary

### 1.1. Главный вывод

Сейчас у игры **нет аудиосистемы в игровом смысле**. Есть пять аудиофайлов, три из которых играют в одной сцене (подход к храму), а два лежат в компоненте, который в кампании фактически молчит. Музыки нет нигде. Боевых, шаговых, интерфейсных и голосовых звуков нет. Шины `Music` и `SFX` создаются кодом только после применения настроек и ни одним проигрывателем не используются — все текущие звуки идут в `Master`.

Это не «мало звука». Это **нулевая точка**, из которой нужно строить систему. Хорошая новость: объём контента для первого полноценного прохождения невелик — около 226 реплик и 30 барков, примерно 12 тысяч знаков, то есть 13–16 минут чистой речи. Это позволяет сделать полное озвучивание, а не «озвучить только главное».

### 1.2. Что уже есть

| Элемент | Факт |
|---|---|
| Аудиофайлы | 5 файлов, ≈1,56 MiB: 2 WAV + 3 OGG. |
| Где играют | `pilgrim_path.gd`: ветер, присутствие стража, каменный скрип. `condition_feedback.gd`: дыхание холода, шорох. |
| Музыка | Нет. |
| Ambience | Один глобальный ветер в сцене подхода к храму; в остальных сценах — тишина. |
| SFX | Нет шагов, боя, взаимодействий, UI, способностей. |
| Голос | Нет. Все диалоги текстовые. |
| Шины | `Master` + создаваемые в рантайме пустые `Music`/`SFX`. Нет `default_bus_layout.tres`. |
| Настройки | Master/Music/SFX; нет Voice/Ambience/UI; `CONFIG_VERSION = 1`. |
| 3D-звук | Один `AudioStreamPlayer3D` (страж), `max_distance = 14`, без окклюзии и reverb-зон. |
| Полифония | Нигде не задана; у каждого плеера по умолчанию `max_polyphony = 1`. |
| Приоритеты | Нет. |
| Ducking | Нет. |
| Сохранение аудио | Только громкость Master/Music/SFX в `user://settings.cfg`. |

### 1.3. Что это значит для игрока

- Пролог, караван, лагерь, святилище, оценка и финал **проходят в тишине**, если не считать трёх звуков у храма.
- Бой ощущается только визуально: удар, попадание, смерть и личинка не звучат.
- Шаги не зависят от поверхности: снег, лёд, камень, грязь, кости и мрамор звучат одинаково — то есть никак.
- Интерфейс не подтверждает действия звуком; игрок не получает аудиальной обратной связи о меню, карте, инвентаре, диалоге.
- Персонажи не звучат; интонация, паузы и дыхание отсутствуют.
- При прямом запуске сцены (F6) шины `Music`/`SFX` могут не существовать, и любой будущий звук упадёт в `Master` — это скрытая мина для всей дальнейшей работы.

### 1.4. Что делать в первую очередь

| # | Действие | Приоритет | Почему |
|---:|---|---|---|
| 1 | Зафиксировать `default_bus_layout.tres` и маршрутизацию всех плееров | **Critical** | Без этого любая музыка и SFX будут смешаны в один неуправляемый поток. |
| 2 | Ввести `AudioDirector` (autoload) и `MusicDirector` | **Critical** | Единая точка запуска музыки, ambience, SFX и voice; иначе звук расползётся по сценам. |
| 3 | Расширить настройки до Master/Music/Ambience/SFX/Voice/UI + миграция | **Critical** | Игрок должен управлять речью отдельно от музыки; текущая схема этого не позволяет. |
| 4 | Сделать `SurfaceDetector` и базовые шаги по 6–8 поверхностям | **Critical** | Шаги — самый частый звук в игре; без них любая другая работа почти не слышна. |
| 5 | Закрыть боевой и интерактивный SFX-минимум | **Critical** | Удар, попадание, блок, уклонение, подбор, дверь, ключ, костёр. |
| 6 | Поставить музыку и ambience в пролог и караван | **High** | Это первая часовая сессия игрока; она задаёт ожидания. |
| 7 | Сделать голосовой pipeline и озвучить 226 реплик + 30 барков | **High** | Объём мал; голос радикально меняет восприятие истории. |
| 8 | Закрыть святилище, оценку и финал | **High** | Кульминация без звука теряет смысл. |
| 9 | Подключить Labyrinth First Fragment (18 зон) | **Medium** | Сцена большая, но контент пока greybox; звук должен следовать за геймплеем. |
| 10 | Полировка: reverb-зоны, окклюзия, вариации, доступность | **Medium/Low** | Делает систему профессиональной, но не блокирует первый проход. |

### 1.5. Целевая звуковая идентичность

**«Холодный свет, тёплая кровь».**

Мир звучит как огромное пустое место, в котором люди пытаются согреться: ветер, камень, вода, металл, дыхание. Музыка не «сопровождает» — она **редко появляется** и каждый раз означает, что кто-то жив или что-то древнее проснулось. Никакого постоянного эпического хора, никаких трейлерных барабанов, никакого «тёмного эмбиента» на все случаи. Тишина — полноценный инструмент. Чем страшнее сцена, тем меньше в ней музыки и тем важнее один точный звук.

---

## 2. Аудит текущего состояния

### 2.1. Карта реализованного контента

| Область | Сцена / файл | Статус | Что слышно сейчас |
|---|---|---|---|
| Главное меню | `scenes/ui/main_menu/main_menu.tscn` | Реализовано | Ничего. Нет ни музыки, ни UI-звуков. |
| Пролог B01–B07: парк, улица, станция | `scenes/slice/prologue.tscn`, `park_street.tscn`, `station_lobby.tscn` | Реализовано | Ничего. |
| Пролог B08–B12: участок, изолятор | `station_lobby.tscn`, `containment_room.tscn` | Реализовано | Ничего. |
| Пролог B13–B14: пустота Заклятия, горное видение | `spell_void.tscn`, `mountain_vision.tscn` | Реализовано | Ничего. |
| Пролог B15 / S01: марш каравана | `caravan_road.tscn` | Реализовано | Ничего. |
| S02–S06: стоянка, нападение, личинка, повозка, ночь, рассвет | `caravan_site.tscn`, `caravan_site_arrival.tscn` | Реализовано | Ничего. |
| S07–S12: дорога, альков, пещера, Герой, храм | `pilgrim_path.tscn`, `pilgrim_path_arrival.tscn` | Реализовано | Ветер (2D loop), присутствие стража (3D one-shot), каменный скрип (2D one-shot). |
| S13: святилище, алтарь, Тиран, смерть | `shadow_sanctuary.tscn`, `sanctuary_arrival.tscn` | Реализовано | Ничего. |
| S14: звёздная оценка | `appraisal_arrival.tscn` | Реализовано | Ничего. |
| S15: пробуждение, финальная карточка | `finale_arrival.tscn` | Реализовано | Ничего. |
| Пост-Кошмар: участок → академия → общежитие → Чёрное море → спуск → старый лабиринт | `scenes/locations/post_nightmare/*` | Реализовано как greybox-цепочка | Ничего. |
| Лабиринт First Fragment: 18 зон | `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn` | Реализовано как standalone greybox | Ничего. |
| Море Души | `scenes/soul_sea/soul_sea.tscn` | Реализовано | Ничего. |
| RPG-меню, карта, инвентарь | `scenes/ui/*` | Реализовано | Ничего. |
| Sandbox-арены | `combat_arena.tscn`, `larva_arena.tscn`, `test_level.tscn`, `main.tscn`, `caravan_ambush.tscn`, `ambush_site_demo.tscn` | Реализовано, вне канона | `ConditionFeedback` присутствует, но не управляется; боевых звуков нет. |

**Вывод:** звук сейчас — это одна сцена с тремя файлами и один неактивный компонент. Всё остальное — визуальный greybox.

### 2.2. Инвентарь аудиофайлов

| Файл | Формат | Длительность | Размер | Источник / лицензия | Где используется | Проблема |
|---|---|---:|---:|---|---|---|
| `assets/audio/combat/breath_cold_loop.wav` | WAV, 22,05 кГц, моно, 16 бит | 2,00 с | 88 244 B | Процедурный, проект | `ConditionFeedback` (cold) | Низкая частота дискретизации; в кампании `set_cold()` не вызывается; играет в `Master`. |
| `assets/audio/combat/noise_rustle_loop.wav` | WAV, 22,05 кГц, моно, 16 бит | 1,00 с | 44 144 B | Процедурный, проект | `ConditionFeedback` (noise) | Слишком короткий цикл; слышимый паттерн; в кампании не управляется; `Master`. |
| `assets/audio/sanctuary/guard_presence_ambience_1.wav` | WAV, 44,1 кГц, стерео, 24 бит | 4,63 с | 1 226 118 B | OpenGameArt, Ogrebane, CC0 | `PilgrimPath` — `AudioStreamPlayer3D` у стража | One-shot, не зациклен; `max_distance = 14`; не прослушан; `Master`. |
| `assets/audio/sanctuary/stone_door_large_001.ogg` | Ogg Vorbis, 44,1 кГц | 3,51 с | 28 454 B | Freesound, DWOBoyle, **CC BY 4.0** | `PilgrimPath` — порог храма | Требуется атрибуция; в игре нет титров; `Master`. |
| `assets/audio/sanctuary/wind_whoosh_loop.ogg` | Ogg Vorbis, 48 кГц | 5,96 с | 251 584 B | OpenGameArt, SketchMan3, CC0 | `PilgrimPath` — глобальный ветер | 2D, без позиции; **очень короткий loop** (5,96 с), слышимый паттерн; `loop=false` в импорте, loop задаётся кодом; `Master`. |

**Итого:** 5 файлов, 1 638 544 B (≈1,56 MiB). Три файла — святилище/подход к храму, два — боевой компонент. Музыки нет.

### 2.3. Как устроен звук в коде

| Место | Что делает | Проблема |
|---|---|---|
| `scripts/world/condition_feedback.gd` | Создаёт `AudioStreamPlayer` для дыхания и шороха, дублирует WAV и включает loop, меняет `volume_db` от 0 до 1. | Не вызывается в кампании; оба плеера идут в `Master`; 22,05 кГц; нет приоритета и cooldown. |
| `scripts/slice/locations/pilgrim_path.gd` | Создаёт `AudioStreamPlayer` ветра (`-12 dB`), `AudioStreamPlayer3D` стража (`-12 dB`, `max_distance=14`) и `AudioStreamPlayer` скрипа (`-6 dB`). | Ветер — глобальный 2D, не привязан к позиции; страж — one-shot; скрип — one-shot; все в `Master`; нет затухания/окклюзии. |
| `scripts/settings/game_settings.gd` | Создаёт шины `Music` и `SFX`, применяет громкость Master/Music/SFX. | Шины создаются только при `apply_audio()`; ни один плеер их не использует; нет Voice/Ambience/UI; `CONFIG_VERSION=1`. |
| `scenes/characters/sunny.tscn` | Содержит `ConditionFeedback`. | Компонент наследуется `sunny_waking_poc.tscn`, но в кампании не управляется. |
| `.import` файлы | `wind_whoosh_loop.ogg`: `loop=false`; `breath_cold_loop.wav`: `edit/loop_mode=0`. | Loop задаётся кодом, а не импортом; рассинхронизация настроек и поведения. |

### 2.4. Шины и настройки: фактическое состояние

```
Сейчас:
Master
  ├── (все AudioStreamPlayer / AudioStreamPlayer3D)
  ├── Music  — создаётся в рантайме, пустая, никто не слушает
  └── SFX    — создаётся в рантайме, пустая, никто не слушает

Эффектов на шинах нет.
Send/return нет.
Reverb-зон нет.
Ducking нет.
Ограничения полифонии нет.
```

| Настройка | Есть | Комментарий |
|---|---|---|
| Master volume | Да | `GameSettings.master_volume`, по умолчанию 0,8. |
| Music volume | Да | По умолчанию 0,7; но музыки нет. |
| SFX volume | Да | По умолчанию 0,8; но SFX в эту шину не маршрутизированы. |
| Voice volume | Нет | Критично для озвучки. |
| Ambience volume | Нет | Нужна отдельно от SFX. |
| UI volume | Нет | Нужна отдельно от игрового SFX. |
| Сохранение | Да, `user://settings.cfg` | Только Master/Music/SFX; версия 1. |
| Применение при старте | Только из меню | Прямой запуск сцены не гарантирует шины. |
| Пауза/фокус | Нет | Музыка/ambience не приглушаются при паузе/потере фокуса. |
| Субтитры | Да, текстовые | Нет аудио-описаний важных неречевых сигналов. |

### 2.5. Матрица пробелов

| # | Пробел | Серьёзность | Последствие | Где закрывать |
|---:|---|---|---|---|
| 1 | Нет `default_bus_layout.tres`; шины создаются кодом | **Critical** | Прямой запуск сцены — всё в `Master`; нельзя микшировать. | `default_bus_layout.tres`, `AudioDirector`. |
| 2 | Нет музыки и музыкального директора | **Critical** | Игра не имеет эмоциональной драматургии. | `MusicDirector`, `MusicCue`. |
| 3 | Нет шагов и surface detection | **Critical** | Самый частый звук отсутствует; мир «пластиковый». | `SurfaceDetector`, `SurfaceType`. |
| 4 | Нет боевых SFX | **Critical** | Бой не читается; попадания и смерть не ощущаются. | `CombatAudio`, SFX-каталог. |
| 5 | Нет интерактивных/UI SFX | **Critical** | Игрок не получает подтверждения действий. | `UIAudio`, `Interactable` signals. |
| 6 | Нет озвучки и pipeline | **High** | Персонажи без голоса; эмоции только текст. | `VoiceDirector`, voice manifest. |
| 7 | Нет ambience в 90% сцен | **High** | Локации не различаются на слух. | `AmbienceDirector`, zone beds. |
| 8 | Нет 3D-окклюзии/reverb-зон | **High** | Пещера, зал и улица звучат одинаково. | `ReverbZone`, occlusion raycast. |
| 9 | Нет приоритетов/полифонии | **High** | Звуки обрывают друг друга; нет управления густотой. | `SfxPool`. |
| 10 | Нет вариаций | **Medium** | Повторы быстро надоедают. | `AudioStreamRandomizer`. |
| 10a | Ветер — loop всего 5,96 с | **Medium** | Слышимый паттерн, усталость за 1–2 минуты. | Новый 30–60 с loop + 2–3 вариации. |
| 11 | Нет loop-настроек в импорте | **Medium** | Щелчки/разрывы на стыках. | Import presets. |
| 12 | Нет loudness-стандарта | **Medium** | Диалог/музыка/SFX скачут по громкости. | LUFS-нормализация. |
| 13 | Нет ducking | **Medium** | Речь тонет в музыке/SFX. | Sidechain/скриптовый ducking. |
| 14 | Нет аудио-телеметрии | **Medium** | Нельзя проверить, сколько голосов играет. | Audio debug overlay. |
| 15 | Нет титров/атрибуции | **Medium** | CC BY 4.0 файл используется без атрибуции. | Credits screen / замена. |
| 16 | Нет аудио-описаний | **Low/Medium** | Игроки с нарушениями слуха теряют сюжетные сигналы. | Sound captions. |
| 17 | Нет Doppler для движущихся объектов | **Low** | Падающие камни/повозка менее убедительны. | `doppler_tracking`. |
| 18 | Нет random ambience playlists | **Low** | Однообразие. | `AudioStreamPlaylist`. |

### 2.6. Что уже реализовано, что запланировано, что предлагается

| Категория | Реализовано | Запланировано (есть маркеры/сцены, нет контента) | Предложение ADD |
|---|---|---|---|
| Музыка | — | — | Полный саундтрек по локациям, лейтмотивы, слои. |
| Ambience | Ветер у храма | — | 20+ ambience-профилей, weather/tide/storm. |
| SFX | 3 звука у храма, 2 в `ConditionFeedback` | — | ~100–140 SFX-событий. |
| Голос | — | 226 реплик + 30 барков в `.tres`/JSON | Полное AI-озвучивание + pipeline. |
| Музыкальные события | — | Фазы каравана, святилища, оценка, финал | MusicDirector + event hooks. |
| Боевые звуки | — | `MountainKing`, `Larva`, `MeleeAttack`, `Hurtbox` | Полный боевой набор. |
| UI | — | Меню, карта, RPG-меню | UI-набор + микшер. |
| Лабиринт | Greybox 18 зон | Маркеры врагов/спутников/Эхо | Зональная аудиоконцепция. |
| Пост-Кошмар | Greybox-цепочка | Арт, NPC, сюжет | Городской/академический/морской звук. |
| Sandbox | Арены | — | Переиспользовать боевые SFX; не делать отдельный саундтрек. |

### 2.7. Расхождения в документации

1. `README.md` (строка 100) утверждает: «звуковых файлов для шин Music/SFX нет». Это **устарело**: пять файлов есть, но они не маршрутизированы в Music/SFX и не образуют музыку/SFX-систему.
2. `docs/DECISIONS.md` (2026-11-01) фиксирует, что `Music`/`SFX` создаются в рантайме и «звуковых файлов для Music/SFX шин пока нет». Это ближе к истине, но формулировка скрывает, что три файла уже играют в `Master`.
3. `docs/ASSET_LICENSES.md` честно отмечает, что `guard_presence_ambience_1.wav` «на слух не проверен», а `stone_door_large_001.ogg` требует атрибуции CC BY 4.0. В игре нет экрана титров — это **открытый долг**, а не деталь.
4. `README.md` называет настройки звука «шаблоном». Это точно; но после добавления голоса шаблон нужно расширять, иначе Voice будет регулироваться вместе с SFX.

### 2.8. Ограничения аудита

- **НЕ ПРОВЕРЕНО:** фактическое звучание пяти файлов, их громкость, шум, артефакты, стереообраз.
- **НЕ ПРОВЕРЕНО:** реальная работа `AudioStreamPlayer3D` стража в оконном режиме (дистанция, затухание, панорама).
- **НЕ ПРОВЕРЕНО:** прямой запуск сцен F6 и поведение шин без меню.
- **НЕ ПРОВЕРЕНО:** производительность аудио на целевом ноутбуке (RTX 3060 Laptop).
- **НЕ ПРОВЕРЕНО:** полный ручной проход и синхронизация звука с анимациями/камерой.
- **НЕ ПРОВЕРЕНО:** качество AI-генерации на русском тексте данного проекта; все рекомендации по инструментам требуют слепого прослушивания.

---

## 3. Глобальное направление звука

### 3.1. Пять опор

1. **Холодный свет, тёплая кровь.** Мир — камень, соль, ветер, вода и металл. Люди — дыхание, ткань, огонь, голос. Музыка возникает там, где эти две температуры встречаются.
2. **Тишина — инструмент.** В игре не должно быть «фоновой музыки на всякий случай». В среднем 60–70% времени игрок слышит только ambience и собственные шаги.
3. **Один точный звук сильнее десяти слоёв.** Скрип камня, один удар колокола, обрыв дыхания — это драматургия. Не заглушать её «эпиком».
4. **Мир старше игрока.** Музыка не объясняет мир; она показывает его возраст. Отсюда — низкие струнные, горловое пение, камень, рог, гул, а не современный «кинематографический» оркестр.
5. **Заклятие — не интерфейс, а присутствие.** Его звук всегда один и тот же в основе (чистый тон/хор), но искажается средой. Игрок узнаёт Заклятие раньше, чем понимает слова.

### 3.2. Лейтмотивы

| Лейтмотив | Образ | Инструменты | Где появляется | Правило |
|---|---|---|---|---|
| **Санни** | Мальчик, который слишком долго терпит | Детунированное пианино, виолончель, дыхание | Меню, пролог, лагерь, финал | 4-звуковая нисходящая фраза; никогда не звучит «героически». |
| **Цепь** | Несвобода, караван, общая судьба | Металл 3+3+2, низкие струнные, шаги | Марш, стоянка, святилище (искажённо) | Ритм цепи — основа, а не украшение. |
| **Заклятие** | Древняя система, которая говорит с людьми | Синус/хор в квинту, стеклянная гармоника, суб-бас | Пустота, руны, оценка, финал | Один и тот же интервал; меняется только среда и громкость. |
| **Горный Король** | Погода, а не персонаж | Суб-бас, контрафагот, низкий хор, удар | Видение, нападение, святилище | Не «босс-тема», а нарастающее давление; мелодия из 5 нот. |
| **Нефис** | Свет, который слишком далёк | Соло-скрипка, гармоники, высокий хор | Лабиринт (запланировано) | Нежная, но незавершённая фраза; всегда чуть вдали. |
| **Кассия** | Хрупкость и доверие | Музыкальная шкатулка, челеста, детский голос без слов | Лабиринт (запланировано) | Расстроенная шкатулка; тепло, которое может сломаться. |
| **Тень** | Древняя сила, которая не злая, а безразличная | Инфразвук, обратный хор, камень | Святилище, оценка | Не «скример»; скорее давление и отсутствие дыхания. |
| **Дом/NQSC** | Мир, где Санни не был нужен | Синт-пэд, радио, городской гул, пианино | Пролог, меню, пост-Кошмар | Узнаваемый городской тембр; без мелодической ностальгии. |

### 3.3. Инструментальный словарь

**Основа:**
- виолончель (сухая, близкая, без большого зала);
- альт/скрипка (соло, не секция);
- контрабас/контрафагот/бас-кларнет (низ);
- детунированное пианино, препарированное пианино;
- стеклянная гармоника, поющие чаши, челеста;
- низкий мужской хор (без слов, на «м»/«о»);
- горловой/обертонный голос (использовать редко);
- рамочные барабаны, тайко, анвил, цепь, камень, металл;
- бас-флейта, рог, тромбон (для древности и масштаба).

**Запрещено как основа:**
- эпический трейлерный оркестр с «braam»;
- постоянные дроны «dark ambient» без событий;
- стандартные хоррор-скримеры (удар + визг);
- современные биты/EDM/lo-fi hip-hop;
- слащавое фэнтези с арфами и флейтами «в стиле эльфов»;
- прямое копирование Witcher 3, Bloodborne или Elden Ring.

### 3.4. Громкость и микширование

| Категория | Целевая громкость | True peak | Комментарий |
|---|---|---|---|
| Диалог/voice | −18…−16 LUFS integrated | ≤ −1 dBTP | Речь всегда разборчива; музыка ducking −6…−9 dB. |
| Музыка | −20…−18 LUFS | ≤ −1 dBTP | Музыка не должна «выигрывать» у речи. |
| Ambience | −24…−20 LUFS | ≤ −1 dBTP | Фон не маскирует шаги и опасность. |
| SFX | Пики −12…−6 dBFS | ≤ −1 dBTP | Короткие события; не клиппить. |
| UI | −20…−16 LUFS | ≤ −1 dBTP | Тише игрового SFX; не раздражать. |
| Общий микс | −16…−14 LUFS | ≤ −1 dBTP | Для личного прохождения; не «война громкости». |

**Правила:**
- Нормализовать каждый ассет до импорта, а не «на слух в сцене».
- Не использовать `volume_db` как единственный инструмент баланса; сначала править ассет, потом шину, потом сцену.
- Все \( \text{loop} \)-ассеты проверять на щелчок: 2–5 мс fade на стыке, zero-crossing.
- Для 3D-звуков использовать моно-ассеты; стерео — только для музыки/ambience/UI.
- Для голоса — mono 48 кГц, без реверба в файле; реверб добавлять в движке.

### 3.5. Политика тишины

| Ситуация | Музыка | Ambience | Что остаётся |
|---|---|---|---|
| Исследование, нет угрозы | Нет или 1 слой | Полный | Шаги, ветер, вода, дыхание. |
| Первое раскрытие локации | 20–40 с cue, затем уход | Полный | Cue заканчивается, не «висит». |
| Диалог | Ducking −8 dB или стоп | −3 dB | Голос, дыхание, комната. |
| Бой | Слои нарастают | −6 dB | Удары, крики, металл. |
| Смерть/шок | Резкий стоп | −12 dB / low-pass | Один звук: колокол, треск, тишина. |
| Скрытность/туннель | Нет | Приглушённый | Дыхание, капли, шаги. |
| Финал сцены | Последняя нота + 3–8 с тишины | Остаётся | Ветер/огонь. |

**Правило:** после каждого крупного события (смерть, удар Тирана, звон колокола, появление Тени) должно быть **не менее 2–3 секунд без музыки**, чтобы событие «осело».

### 3.6. Модель динамической музыки

**Вертикальные слои (внутри одной сцены):**
```
base      — всегда играет, тихо; задаёт гармонию/тембр
mid       — добавляется при исследовании/приближении к цели
high      — бой/опасность/погоня
stinger   — короткое событие, не зациклен
silence   — принудительная тишина на 2–8 с
```

**Горизонтальные переходы (между сценами):**
- crossfade 2–4 с для обычных переходов;
- 0,3–0,8 с для резких сюжетных срезов;
- «на следующем такте» — для музыки с ритмом;
- «после конца фразы» — для сольных инструментов;
- жёсткий стоп + тишина — для смерти/шока.

**Технически:**
- `AudioStreamSynchronized` — для сэмпл-точного старта слоёв одного cue; если громкость слоёв меняется постоянно, практичнее отдельные `AudioStreamPlayer` на слой (см. §10.5).
- `AudioStreamInteractive` — для авторских переходов между фрагментами одного cue.
- `AudioStreamPlaylist` — для случайных/последовательных ambience-фрагментов.
- `AudioStreamRandomizer` — для вариаций one-shot SFX.
- Два `AudioStreamPlayer` (A/B) в `MusicDirector` — для crossfade между разными cue.

### 3.7. Референс-индекс

Ссылки — на официальные страницы композиторов/альбомов или крупные каталоги. Доступность отдельных страниц не гарантируется; проверять перед использованием. Все композиции — **референсы**, не аудиоассеты проекта.

| ID | Произведение | Автор/композитор | Год | Ссылка | Основные треки для нас |
|---|---|---|---|---|---|
| R01 | Disco Elysium | Sea Power (British Sea Power) | 2019 | https://store.steampowered.com/app/1233220/Disco_Elysium_The_Final_Cut_Soundtrack/ | Instrument of Surrender; Whirling-In-Rags, 8 AM; Precinct 41 Major Crime Unit; Martinaise, Terminal B |
| R02 | The Last of Us | Gustavo Santaolalla | 2013 | https://classical.music.apple.com/us/album/655118434 | The Last of Us; The Choice; Vanishing Grace; All Gone (No Escape); The Path |
| R03 | Shadow of the Colossus: Roar of the Earth | Kow Otani | 2005 | https://www.ost.co/996-shadow-of-the-colossus.html | Prologue; The Opened Way; A Violent Encounter; The End of the Battle; The Farthest Land |
| R04 | Bloodborne | SIE Sound Team (R. Amon, T. Saitoh, Y. Kitamura и др.) | 2015 | https://www.deezer.com/en/album/206840502 | The Hunter; Cleric Beast; Ebrietas, Daughter of the Cosmos; The First Hunter |
| R05 | Journey | Austin Wintory | 2012 | https://austinwintory.bandcamp.com/album/journey | Nascence; The Road of Trials; Apotheosis |
| R06 | The Revenant | Ryuichi Sakamoto, Alva Noto, Bryce Dessner | 2015 | https://www.ryuichisakamoto.com/ | The Revenant Main Theme; Killing Hawk; Goodbye to Hawk |
| R07 | Sicario | Jóhann Jóhannsson | 2015 | https://johannjohannsson.com/ | The Beast; Sicario; Desert Music |
| R08 | Chernobyl | Hildur Guðnadóttir | 2019 | https://hildurness.com/ | Pump Room; Bridge of Death; Gallows |
| R09 | Annihilation | Ben Salisbury & Geoff Barrow | 2018 | https://www.invada.co.uk/ | The Alien; Lighthouse; The Shimmer |
| R10 | Blade Runner 2049 | Hans Zimmer & Benjamin Wallfisch | 2017 | https://www.hanszimmer.com/ | 2049; Mesa; Sea Wall |
| R11 | Ghost in the Shell (1995) | Kenji Kawai | 1995 | https://www.kenjikawai.com/ | Nightstalker; Floating Museum; Making of Cyborg |
| R12 | 2001: A Space Odyssey | György Ligeti; Richard Strauss | 1968 | https://www.warnerclassics.com/ | Requiem; Lux Aeterna; Also Sprach Zarathustra |
| R13 | Interstellar | Hans Zimmer | 2014 | https://www.hanszimmer.com/ | Mountains; Detach; No Time for Caution |
| R14 | Dune (2021) | Hans Zimmer | 2021 | https://www.hanszimmer.com/ | Paul's Dream; Gom Jabbar; Ripples in the Sand |
| R15 | Arrival | Jóhann Jóhannsson; Max Richter | 2016 | https://johannjohannsson.com/ | On the Nature of Daylight; Heptapod B; Arrival |
| R16 | Severance | Theodore Shapiro | 2022 | https://www.theodorashapiro.com/ | Main Titles; The Macrodata Refinement Team; The Break Room |
| R17 | Deus Ex: Human Revolution | Michael McCann | 2011 | https://www.michaelmccannmusic.com/ | Icarus; Everybody Lies; Detroit City Ambient |
| R18 | Alien | Jerry Goldsmith | 1979 | https://www.jerrygoldsmith.com/ | Main Title; The Face Hugger; Acid Test |
| R19 | The Thing (1982) | Ennio Morricone | 1982 | https://www.enniomorricone.org/ | Humanity Part II; The Thing; Despair |
| R20 | Under the Skin | Mica Levi | 2013 | https://micalevi.com/ | Love; Death; The Seduction |
| R21 | The Lord of the Rings | Howard Shore | 2001–2003 | https://www.howardshore.com/ | The Ring Goes South; The Bridge of Khazad-dûm; The Grey Havens; The Uruk-hai |
| R22 | Conan the Barbarian | Basil Poledouris | 1982 | https://www.basilpoledouris.com/ | The Riders of Doom; Battle of the Mounds; Anvil of Crom |
| R23 | Apocalypto | James Horner | 2006 | https://www.jameshorner.com/ | The Chase; The Jaguar; Sacrifice |
| R24 | Mad Max: Fury Road | Junkie XL (Tom Holkenborg) | 2015 | https://www.junkiexl.com/ | Brothers in Arms; Storm Is Coming; The Wasteland |
| R25 | God of War (2018) | Bear McCreary | 2018 | https://www.bearmccreary.com/ | The Stranger; God of War; Deliverance |
| R26 | Doom (2016) | Mick Gordon | 2016 | https://www.mickgordon.com/ | BFG Division; Rip & Tear; At Doom's Gate |
| R27 | Pacific Rim | Ramin Djawadi | 2013 | https://www.ramindjawadi.com/ | Pacific Rim; Kaiju; Go Big or Go Extinct |
| R28 | King Kong (2005) | James Newton Howard | 2005 | https://www.jamesnewtonhoward.com/ | The Canyon; King Kong; Beauty Killed the Beast |
| R29 | The Grey | Marc Streitenfeld | 2011 | https://www.marcstreitenfeld.com/ | The Grey; Into the Fray; A Good Death |
| R30 | Frostpunk | Piotr Musiał | 2018 | https://www.piotrmusial.com/ | The City Must Survive; The Storm; Hope |
| R31 | Red Dead Redemption 2 | Woody Jackson; Daniel Lanois; D'Angelo | 2018 | https://www.rockstargames.com/reddeadredemption2/soundtrack | That's the Way It Is; Unshaken; Outlaws from the West |
| R32 | Baldur's Gate 3 | Borislav Slavov | 2023 | https://borislavslavov.bandcamp.com/ | The Camp; Down by the River; The Power |
| R33 | Kingdom Come: Deliverance | Jan Valta | 2018 | https://www.janvalta.com/ | Sleeping; Camp; Main Theme |
| R34 | The Green Mile | Thomas Newman | 1999 | https://www.thomasnewman.com/ | The Green Mile; Coffey's Hands; The Mouse |
| R35 | No Country for Old Men | Carter Burwell | 2007 | https://www.carterburwell.com/ | Blood Trail; The Coin Toss |
| R36 | The Assassination of Jesse James… | Nick Cave & Warren Ellis | 2007 | https://www.nickcave.com/ | Song for Jesse; The Money Train; What Must Be Done |
| R37 | The Road | Nick Cave & Warren Ellis | 2009 | https://www.nickcave.com/ | The Road; The Boy; The Cellar |
| R38 | The Descent | David Julyan | 2005 | https://www.davidjulyan.com/ | The Descent; The Cave; The Crawlers |
| R39 | Aliens | James Horner | 1986 | https://www.jameshorner.com/ | Main Title; Sub-Level; Ripley's Rescue |
| R40 | Pan's Labyrinth | Javier Navarrete | 2006 | https://www.javiernavarrete.com/ | Long, Long Time Ago; The Labyrinth; The Faun |
| R41 | Berserk (1997) | Susumu Hirasawa | 1997 | https://www.susumuhirasawa.com/ | Guts; Behelit; Forces |
| R42 | The Fountain | Clint Mansell | 2006 | https://www.clintmansell.com/ | Death Is the Road to Awe; Together We Will Live Forever |
| R43 | Requiem for a Dream | Clint Mansell | 2000 | https://www.clintmansell.com/ | Lux Aeterna; Summer Overture |
| R44 | Mass Effect 3 | Clint Mansell, Sam Hulick, Christopher Lennertz и др. | 2012 | https://www.ea.com/games/mass-effect | An End, Once and for All; Leaving Earth; The Fleets Arrive |
| R45 | The Leftovers | Max Richter | 2014 | https://maxrichtermusic.com/ | The Departure; Dona Nobis Pacem |
| R46 | Outer Wilds | Andrew Prahlow | 2019 | https://andrewprahlow.bandcamp.com/ | Timber Hearth; Final Voyage; End Times |
| R47 | Death Stranding | Ludvig Forssell | 2019 | https://www.playstation.com/games/death-stranding/ | BB's Theme; The Timefall; Path |
| R48 | Subnautica | Simon Chylinski | 2018 | https://simonchylinski.bandcamp.com/ | Abandon Ship; Salutations; Precursor |
| R49 | The Abyss | Alan Silvestri | 1989 | https://www.varesesarabande.com/ | The Abyss; The Pseudopod; Finale |
| R50 | Primal (2003) | 16 Volt | 2003 | https://16volt.bandcamp.com/ | Aquis; Rift; Volcano |
| R51 | Control | Petri Alanko | 2019 | https://www.remedygames.com/games/control | The Ashtray Maze; Control; The Foundation |
| R52 | Mirror's Edge | Solar Fields | 2008 | https://www.solarfields.com/ | Introduction; Edge & Flight; The Shard |
| R53 | Persona 5 | Shoji Meguro | 2016 | https://atlus.com/persona5/ | Beneath the Mask; Life Will Change |
| R54 | NieR: Automata | Keiichi Okabe | 2017 | https://www.square-enix.com/ | Weight of the World; City Ruins |
| R55 | Hollow Knight | Christopher Larkin | 2017 | https://christopherlarkin.bandcamp.com/ | Dirtmouth; City of Tears; Radiance |
| R56 | The Elder Scrolls V: Skyrim | Jeremy Soule | 2011 | https://www.jeremysoule.com/ | Secunda; The Streets of Whiterun; Sovngarde |
| R57 | Ori and the Blind Forest | Gareth Coker | 2015 | https://garethcoker.bandcamp.com/ | Ori, Lost in the Storm; Restoring the Light |
| R58 | Hellblade: Senua's Sacrifice | David Garcia | 2017 | https://www.davidgarciamusic.com/ | Hellblade; The Northmen; Sea of Corpses |
| R59 | A Plague Tale: Innocence | Olivier Deriviere | 2019 | https://olivierderiviere.com/ | A Plague Tale; The Rats; Brother |
| R60 | Ghost of Tsushima | Ilan Eshkeri & Shigeru Umebayashi | 2020 | https://www.playstation.com/games/ghost-of-tsushima/ | Jin Sakai; The Way of the Ghost |
| R61 | Cyberpunk 2077 | Marcin Przybyłowicz, P.T. Adamczyk, Paul Leonard-Morgan | 2020 | https://www.cyberpunk.net/ | The Rebel Path; Never Fade Away; Night City |
| R62 | Horizon Zero Dawn | Joris de Man | 2017 | https://www.guerrilla-games.com/ | Prologue; Aloy's Theme; The Embrace |
| R63 | Death's Door | David Fenn | 2021 | https://davidfenn.bandcamp.com/ | Death's Door; The Hall of Doors |
| R64 | Tunic | Lifeformed & Janice Kwan | 2022 | https://lifeformed.bandcamp.com/ | Overworld; The Ruin; Secrets |
| R65 | Signalis | 1000 Eyes | 2022 | https://1000eyes.bandcamp.com/ | Signalis; Replik; The Tower |
| R66 | The Lighthouse | Mark Korven | 2019 | https://www.markkorven.com/ | The Lighthouse; Fog; Madness |
| R67 | Silent Hill 2 | Akira Yamaoka | 2001 | https://www.akira-yamaoka.com/ | Theme of Laura; Promise; Heaven's Night |
| R68 | The Witcher 3: Wild Hunt | Marcin Przybyłowicz | 2015 | https://www.marcinprzybylowicz.com/ | The Trail; Hunt or Be Hunted; The Nightingale |
| R69 | Elden Ring | FromSoftware sound team | 2022 | https://www.eldenring.jp/ | Elden Ring; Godskin Apostles; Final Battle |
| R70 | Dark Souls III | Yuka Kitamura / FromSoftware | 2016 | https://www.darksouls3.com/ | Soul of Cinder; Main Theme; Epilogue |

---

## 4. Аудиоконцепции локаций

> В этом разделе **все музыкальные и звуковые решения — ПРЕДЛОЖЕНИЕ**, если не указано иное. Ссылки R01–R70 — из референс-индекса §3.7. Конкретные BPM/тональности — стартовые ориентиры для композитора, а не догма.  
> ID в локационных таблицах могут быть сокращены; канонический список — §7. Если ID нет в §7, он считается черновым и должен быть добавлен в каталог перед реализацией.

### 4.1. Главное меню и экран кампании

**Статус:** РЕАЛИЗОВАНО (меню), музыка/звук — ПРЕДЛОЖЕНИЕ.  
**Что делает игрок:** выбирает «Играть», «Настройки», «Выход»; настраивает графику/звук; запускает кампанию.  
**Эмоциональная цель:** «ты уже опоздал; этот мир жил без тебя и будет жить дальше».

#### Музыка

- **Стиль:** камерный космический ламент, без оркестрового эпика.
- **Настроение:** одиноко, древне, сдержанно; не «хоррор», а предчувствие.
- **BPM/тональность:** 52 BPM, D minor; размер 4/4 с мягкой пульсацией.
- **Инструменты:** виолончель соло, детунированное пианино, суб-бас, далёкий низкий хор, стеклянная гармоника.
- **Аранжировка:** 4-звуковая нисходящая фраза (D–C–A–F) у виолончели; пианино отвечает на 3-й доле; хор входит только на 2-м проведении; никаких барабанов.
- **Слои:**
  - `base` — виолончель + суб-бас + стеклянный звон;
  - `press` — пианино и хор при наведении на «Играть»;
  - `glitch` — короткий расстроенный импульс при открытии настроек/ошибки;
  - `silence` — 4–6 с после выбора «Выход».
- **Начало/конец:** начинается сразу при загрузке меню, без вступления; при уходе в игру — fade 2,5 с, последняя нота виолончели остаётся.
- **Тишина:** если игрок бездействует 45–60 с, убрать пианино и хор, оставить суб-бас и редкий стеклянный звон; через 2 минуты — почти полная тишина с одним далёким ударом.

#### Референсы

1. **R01, «Instrument of Surrender» (Sea Power, Disco Elysium).** Почему: медленная, усталая, «после катастрофы»; нет героики. Что взять: соло-виолончель, неровный тембр, ощущение комнаты. Как применить: основа главной темы; не копировать мелодию, а взять фразировку и воздух.
2. **R02, «The Last of Us» (Gustavo Santaolalla).** Почему: интимный, близкий, человеческий звук. Что взять: минимализм, один инструмент, паузы. Как применить: пианино/гитара в меню, чтобы игрок не чувствовал «эпическую игру».
3. **R03, «Prologue ~To the Ancient Land~» (Kow Otani, Shadow of the Colossus).** Почему: древность и простор без пафоса. Что взять: низкие струнные, медленный подъём, хор на «м». Как применить: подложка при первом запуске и при выборе «Играть».
4. **R04, «The Night Unfurls» (Ryan Amon, Bloodborne).** Почему: готическое предчувствие, а не скример. Что взять: низкий хор, суб-бас, отсутствие ритма. Как применить: только в слое `glitch`/при повторном запуске после смерти.
5. **R46, «Timber Hearth» (Andrew Prahlow, Outer Wilds).** Почему: тёплая камерность в космической пустоте. Что взять: акустический инструмент, мягкую реверберацию, чувство дома. Как применить: пианино/гитара в меню, чтобы у игрока была причина остаться.

#### Ambience (5–10)

- тихий «комнатный» гул меню (не пустота, а присутствие);
- далёкий ветер, будто за стеной;
- очень низкий суб-бас, почти инфразвук;
- редкий стеклянный звон (1 раз в 20–40 с);
- далёкий металлический скрип цепи (намёк на караван);
- шорох бумаги/ткани при переключении вкладок;
- мягкий гул сервера/экрана (современный слой);
- едва слышный хор на «м» под музыкой;
- при бездействии — один далёкий удар колокола.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| UI_HOVER | Наведение | Короткий стеклянный/войлочный тик, −24 dB | 1 раз на кнопку, без повтора при движении внутри. |
| UI_CLICK | Нажатие | Мягкий деревянный/каменный щелчок + короткий тон | Все основные кнопки. |
| UI_BACK | Назад | Обратный тик, чуть ниже | Escape/назад. |
| UI_TAB | Вкладка | Шорох бумаги + тихий тон | Графика/Звук/Управление. |
| UI_SLIDER | Ползунок | Тихий щелчок на шаг, без «писка» | Громкость/разрешение. |
| UI_ERROR | Ошибка | Сухой низкий тон, без скримера | Неверное значение/недоступно. |
| UI_START | «Играть» | Один удар колокола + вдох | Переход в кампанию. |
| UI_QUIT | «Выход» | Затухающий выдох/ветер | Выход. |

#### Голоса

- Прямой речи нет.
- **ПРЕДЛОЖЕНИЕ:** при самом первом запуске — одна реплика Заклятия шёпотом, без текста на экране: «Аспирант…». Это создаёт вопрос и не мешает меню. Если это ощущается как «дешёвый хоррор», убрать.

#### Общая концепция

Меню — это не «титульный экран», а первая комната игры. Музыка должна быть тише, чем ожидает игрок, и оставлять чувство, что где-то рядом есть другой, более древний звук. После нажатия «Играть» — короткая тишина перед прологом, чтобы городской шум ударил контрастом.

---

### 4.2. Пролог: парк, улица, станция (B01–B07)

**Статус:** РЕАЛИЗОВАНО (сцены), звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни сидит на скамейке, пьёт кофе, засыпает, просыпается, выбрасывает стаканчик, переходит улицу, входит в полицейский участок.  
**Эмоциональная цель:** обыденность, усталость, бедность, предчувствие; мир уже давит, но ещё не показывает клыков.

#### Музыка

- **Стиль:** городской ламент / медленный инди-эмбиент с живыми инструментами.
- **Настроение:** серое утро, похмелье без алкоголя, жизнь, которая прошла мимо.
- **BPM/тональность:** 66 BPM, E minor / E Dorian; лёгкая «хромая» пульсация.
- **Инструменты:** детунированное пианино, щёточные барабаны, контрабас, синт-пэд, полевая запись улицы, приглушённая труба (редко).
- **Аранжировка:** 2-тактовый пианинный остинато; бас входит на 4-м такте; барабаны — только щётки, без бочки; труба — один короткий вздох в конце фразы.
- **Слои:**
  - `base` — пианино + пэд + улица;
  - `mid` — контрабас + щётки;
  - `drowse` — фильтр высоких, замедление, суб-бас (когда Санни засыпает);
  - `spell` — один стеклянный тон/хор при пробуждении;
  - `silence` — 3 с перед входом в участок.
- **Начало/конец:** начинается с 2 с уличного шума, затем пианино; заканчивается на входе в участок, не доходя до двери.
- **Тишина:** когда Санни засыпает, музыка уходит в низкий гул и почти исчезает; после пробуждения возвращается только пианино.

#### Референсы

1. **R01, «Whirling-In-Rags, 8 AM» (Sea Power, Disco Elysium).** Почему: утренний город, усталость, ирония без слов. Что взять: ленивый грув, детунированный инструмент, уличный фон. Как применить: основа сцены скамейки.
2. **R17, «Icarus» (Michael McCann, Deus Ex: Human Revolution).** Почему: корпоративный/dystopian город, синтетическая тревога. Что взять: холодный пэд, низкий пульс, стеклянные тембры. Как применить: подложка при переходе к участку; не делать всю сцену «киберпанком».
3. **R10, «2049» (Hans Zimmer & Benjamin Wallfisch, Blade Runner 2049).** Почему: мегаполис как давление, суб-бас и сирены. Что взять: суб-бас, далёкие сирены, огромное пространство. Как применить: только при взгляде на город/станцию; тихо, почти на грани.
4. **R11, «Nightstalker» (Kenji Kawai, Ghost in the Shell).** Почему: ритуальная перкуссия в современном городе. Что взять: рамочный барабан, синт-хор, аскетичную мелодию. Как применить: сцена перехода через улицу; не для скамейки.
5. **R16, «Main Titles» (Theodore Shapiro, Severance).** Почему: стерильная корпоративная неправильность. Что взять: маримба/пианино, ровный пульс, пустая комната. Как применить: вход в станцию/лобби, а не парк.

#### Ambience (5–10)

- городской гул: далёкий транспорт, вентиляция, электричество;
- ветер в кронах/кустах парка (сухой, городской);
- шаги прохожих по асфальту и плитке;
- обрывки разговоров без слов (walla, −30 dB);
- редкий велосипедный звонок/самокат;
- гул вывески автобусной остановки;
- скрип скамейки;
- шелест стаканчика/бумаги;
- далёкая сирена (1 раз в 60–90 с);
- приглушённая музыка/объявление из станции через стекло;
- голуби/птицы — очень сдержанно, только в парке;
- «дрон» наблюдения — почти неслышимый тон при взгляде на камеры.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| PL_SIT | Сесть на скамейку | Скрип дерева + ткань + выдох | B01. |
| PL_STAND | Встать | Скрип + шаг + вдох | B04. |
| PL_DRINK | Глоток | Керамика/крышка + глоток + выдох | B02, B04. |
| PL_THROW_CUP | Бросок стаканчика | Пластик/бумага, короткий свист, удар в урну | B05. |
| PL_WALK_ASPHALT | Шаги по асфальту | Сухой, с песком, не «цокающий» | Улица. |
| PL_WALK_CONCRETE | Шаги по бетону | Плотный, с лёгким эхом | Станция/тротуар. |
| PL_WALK_TILE | Шаги по плитке | Чистый, звонкий, с ревербом | Лобби. |
| ENV_DOOR_STATION | Дверь станции | Металл/стекло, шипение, короткий скрип | B07. |
| ENV_TURNSTILE | Турникет | Металлический щелчок + мотор | Вход. |
| ST_CODE_BLACK | Code Black | Сирена + тревожный тон + двери | B09. |

#### Голоса

- **Desk officer** (6 реплик): усталый, процедурный, без интереса; средний возраст, немного гнусавый; не «злодей».
- **Policeman** (11 реплик): спокойный, тяжёлый, говорит короткими фразами; низкий грудной голос; без угрозы, но с давлением.
- **Sunny** (реплики + наррация): тихий, ироничный, немного хриплый; внутренний голос — ближе к микрофону, медленнее, без театра.
- **Crowd walla:** без разборчивых слов; 3–5 голосов, далеко.
- **ПРЕДЛОЖЕНИЕ:** объявление станции — женский синтетический голос, искажённый, неразборчивый; создаёт звук «системы».

#### Общая концепция

Сцена должна звучать **скучно и правдоподобно**, чтобы сон и переход в Кошмар были страшнее. Не добавлять мистику в парк. Единственные «неправильные» звуки — почти неслышимый дрон камеры и один стеклянный тон при засыпании. Контраст с караваном должен быть оглушительным: из города — в ветер и цепь.

---

### 4.3. Пролог: лобби полицейского участка (B08–B09)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни у стойки, короткий разговор, затем Code Black, тревога, турели, дверь.  
**Эмоциональная цель:** бюрократия, контроль, холод; затем резкий слом в тревогу.

#### Музыка

- **Стиль:** институциональный минимализм / процедурный эмбиент.
- **Настроение:** «здесь всё работает, но не для тебя».
- **BPM/тональность:** 60 BPM, C minor; почти без мелодии.
- **Инструменты:** маримба/пианино, низкий синт-пэд, металлические перкуссии, приглушённая труба, HVAC-гул.
- **Аранжировка:** 2-нотный остинато; каждый 8-й такт — один металлический удар; при Code Black — слой сирены и низких струнных.
- **Слои:**
  - `base` — гул + маримба;
  - `procedure` — пианино + труба;
  - `alarm` — сирена + струнные + удар;
  - `silence` — после закрытия двери.
- **Начало/конец:** начинается после входной двери; заканчивается на затемнении.
- **Тишина:** между репликами — только HVAC и терминал; не заполнять паузы музыкой.

#### Референсы

1. **R16, «Main Titles» / «The Macrodata Refinement Team» (Theodore Shapiro, Severance).** Почему: стерильная корпоративная среда, которая пугает без монстров. Что взять: маримба, ровный пульс, пустые паузы. Как применить: основа лобби.
2. **R07, «The Beast» (Jóhann Jóhannsson, Sicario).** Почему: процедура под давлением, низкий гул. Что взять: суб-бас, виолончель, отсутствие мелодии. Как применить: подложка при разговоре у стойки.
3. **R08, «Pump Room» (Hildur Guðnadóttir, Chernobyl).** Почему: бетон, промышленность, обречённость. Что взять: металлические пульсы, гул, резонанс. Как применить: Code Black и коридор.
4. **R01, «Precinct 41 Major Crime Unit» (Sea Power, Disco Elysium).** Почему: полицейский участок как место усталой бюрократии. Что взять: бас, щётки, пианино, иронию. Как применить: сцена у стойки, чтобы не было «стерильного sci-fi».
5. **R18, «Main Title» (Jerry Goldsmith, Alien).** Почему: холодная институциональная тревога. Что взять: диссонирующие струнные, низкий деревянный духовой, тишину. Как применить: момент, когда турели активируются.

#### Ambience (5–10)

- флуоресцентный гул (50/100 Гц) + лёгкий звон;
- вентиляция, поток воздуха через решётки;
- вентиляторы терминалов и серверов;
- принтер/сканер, редкие щелчки;
- шаги по плитке с ревербом;
- далёкие двери, лифт, коридор;
- радио/переговоры без слов, приглушённо;
- тест сирены, один раз;
- сервопривод турели, металлический поворот;
- стекло, пластик, бумага;
- людской гул за стеклом (walla).

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ENV_TERMINAL | Терминал | Писк/клик, очень тихо | У стойки. |
| ENV_DOOR_METAL | Дверь | Тяжёлый металл, шипение, замок | Вход/выход. |
| ST_CODE_BLACK | Code Black | Сирена + низкий гул + металлические ставни | B09. |
| ST_TURRET | Турель | Сервопривод, металлический лязг, заряд | При активации. |
| UI_DESK | Стойка | Тихий звонок/подтверждение | Разговор. |
| PL_WALK_TILE | Шаги | Чистая плитка, реверб | Лобби. |

#### Голоса

- **Desk officer:** вежливо-усталый, автоматический; не повышает голос.
- **Policeman:** появляется позже; в лобби — только по радио/из-за стекла, искажённый.
- **Commander:** 2 реплики; командный, сухой, без эмоций; может звучать через PA с лёгкой перегрузкой.
- **Sunny:** внутренний голос, тихо.
- **Crowd walla:** 4–6 голосов, без слов.

#### Общая концепция

Лобби — самая «нормальная» сцена, поэтому она должна быть самой стерильной. Музыка почти отсутствует; всё держится на HVAC, шагах и терминале. Code Black — первый громкий момент игры: сирена должна быть резкой, но не болезненной; после неё — не музыка, а звон в ушах.

---

### 4.4. Пролог: изолятор / карантинный бокс (B10–B12)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни пристёгнут к креслу, входит полицейский, брифинг, сонливость, затемнение.  
**Эмоциональная цель:** клаустрофобия, беспомощность, субъективное замедление; страх не монстра, а собственного тела.

#### Музыка

- **Стиль:** почти без музыки; дрон и субъективный звон.
- **Настроение:** «комната давит; время течёт».
- **BPM/тональность:** 44 BPM (пульс), A minor; без ритма.
- **Инструменты:** суб-бас, стеклянная гармоника, обратное пианино, сердцебиение, вентиляция.
- **Аранжировка:** один дрон A; каждые 8–12 с — тихий резонанс; к концу — высокий звон, который вытесняет всё.
- **Слои:**
  - `room` — HVAC + суб;
  - `body` — сердцебиение + дыхание;
  - `tinnitus` — высокий синус, медленно растёт;
  - `spell` — один нарушенный импульс перед сном;
  - `silence` — обрыв в тишину на затемнении.
- **Начало/конец:** начинается с щелчка фиксаторов; заканчивается обрывом.
- **Тишина:** после каждого щелчка — 1–2 с без музыки, только комната.

#### Референсы

1. **R08, «Pump Room» (Hildur Guðnadóttir, Chernobyl).** Почему: бетонная комната, промышленный гул, обречённость. Что взять: низкий резонанс, металл, медленное давление. Как применить: основа комнаты.
2. **R09, «The Alien» (Ben Salisbury & Geoff Barrow, Annihilation).** Почему: органическое, дышащее присутствие. Что взять: обратные тоны, дыхание, текстуры. Как применить: слой `body`, очень тихо.
3. **R18, «Main Title» (Jerry Goldsmith, Alien).** Почему: клинический ужас. Что взять: высокий струнный кластер, низкий дрон. Как применить: момент, когда Санни понимает, что не может встать.
4. **R16, «The Break Room» (Theodore Shapiro, Severance).** Почему: институциональное принуждение без насилия. Что взять: мягкий корпоративный пэд, часы, неловкую тишину. Как применить: брифинг полицейского.
5. **R43, «Lux Aeterna» (Clint Mansell, Requiem for a Dream).** Почему: нарастающий звон/пульс, субъективная деградация. Что взять: только высокий кластер и медленный пульс, не всю тему. Как применить: слой `tinnitus` перед сном.

#### Ambience (5–10)

- HVAC: низкий гул 55 Гц + 120 Гц;
- поток воздуха через решётку, без свиста;
- редкие реле/контакторы терминала;
- щелчок фиксатора кресла;
- натяжение ремня/кожи;
- сервопривод полукожуха;
- щелчок замка двери;
- шаги полицейского по бетону за дверью;
- приглушённое радио/коридор;
- здание «садится»: редкий металлический резонанс;
- звон в ушах (субъективный);
- дыхание Санни, неровное.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_RESTRAIN | Фиксация | Металл + ткань + щелчок замка | B10. |
| PL_RESTRAINED_IDLE | Натяжение ремней | Кожа/металл, тихо, при движении | Idle. |
| ST_DOOR_LOCK | Замок | Один тяжёлый щелчок | B10/B12. |
| ST_POLICEMAN_STEPS | Шаги | Бетон, реверб, медленно | B11. |
| ST_TERMINAL | Терминал | Реле, писк, ошибка | B10/B12. |
| ST_DROWSINESS | Сонливость | Высокий звон + приглушение внешнего | B12, по репликам. |
| PL_BREATH_COLD | Дыхание | Холодное, неровное, близко | Если cold > 0. |
| PL_HEARTBEAT | Сердце | Низкий, медленный, субъективный | B12. |

#### Голоса

- **Policeman:** близко, но без тепла; читает процедуру, как инструкцию; паузы между пунктами; лёгкая усталость.
- **Sunny:** внутренний голос, всё тише; к концу — почти шёпот, обрывающийся.
- **Desk officer:** только за стеклом, искажённый, без слов.
- **ПРЕДЛОЖЕНИЕ:** голос Заклятия на переходе — не слова, а один низкий хоровой аккорд, который «не хочет заканчиваться».

#### Общая концепция

Звук должен **не усиливаться, а сжиматься**: чем ближе сон, тем меньше высоких частот и больше звона. Не делать скример. После обрыва — 2–3 с полной тишины, затем пустота Заклятия.

---

### 4.5. Пролог: пустота Заклятия (B13)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни исчезает, появляется приветствие Заклятия, переход к видению.  
**Эмоциональная цель:** космическая пустота, благоговение, отсутствие тела.

#### Музыка

- **Стиль:** космический хор / спектральный дрон; без темпа.
- **Настроение:** не страх, а «ты слишком мал, чтобы бояться».
- **BPM/тональность:** без BPM; дрон на D, квинта A; медленные глиссандо.
- **Инструменты:** хор на «м», синус, стеклянная гармоника, суб-бас, обратное дыхание.
- **Аранжировка:** один аккорд, который медленно расстраивается; никакой мелодии; хор входит слоями.
- **Слои:** `void` (дрон), `voice` (хор), `spell` (стеклянный тон), `sub` (инфразвук).
- **Начало/конец:** резкий вход после тишины изолятора; выход — через нарастающий хор в горное видение.
- **Тишина:** внутри пустоты — 1–2 с полной тишины перед первой «фразой» Заклятия.

#### Референсы

1. **R12, «Requiem» / «Lux Aeterna» (György Ligeti, 2001).** Почему: хор как космическая материя, без человеческой эмоции. Что взять: кластеры, глиссандо, отсутствие ритма. Как применить: основа пустоты.
2. **R13, «Mountains» (Hans Zimmer, Interstellar).** Почему: огромность, тиканье времени, благоговение. Что взять: орган, медленный пульс, низкие струнные. Как применить: подложка при переходе к видению.
3. **R14, «Paul's Dream» (Hans Zimmer, Dune).** Почему: ритуал, пророчество, пустыня. Что взять: женский голос без слов, рамочный барабан, суб. Как применить: намёк на древность мира, не на Санни.
4. **R05, «Nascence» (Austin Wintory, Journey).** Почему: духовное, интимное, без пафоса. Что взять: соло-виолончель/голос, воздух. Как применить: момент, когда Заклятие обращается лично.

#### Ambience (5–10)

- низкий дрон, почти инфразвук;
- высокий синус, едва слышимый;
- хоровые кластеры без слов;
- обратное дыхание;
- стеклянный звон;
- далёкий горный ветер (предвестие);
- удар сердца, очень медленный;
- «треск» реальности — короткий, сухой;
- тишина между слоями.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| SP_GREETING | Приветствие | Хоровой аккорд + стеклянный тон | B13. |
| SP_MESSAGE | Текст Заклятия | Тихий тик/шёпот на появление строки | Каждая строка. |
| ST_VOID_IMPACT | Вход в пустоту | Обратный вдох + суб-удар | Переход. |
| ST_VISION_ORBIT | Переход к видению | Нарастающий хор + ветер | B14. |

#### Голоса

- **Spell:** бесполый, многослойный, спокойный; не «робот» и не «бог»; темп медленный, паузы длинные; лёгкий хор/реверб, но слова разборчивы. Русский язык, без английского акцента.
- **Sunny:** нет; он вне тела.
- **ПРЕДЛОЖЕНИЕ:** на фразе «Приготовься к Первому испытанию» — лёгкий сдвиг высоты вниз, будто система сомневается.

#### Общая концепция

Пустота — это не «место», а **состояние**. Музыка не должна быть громкой; она должна быть **больше**, чем игрок. После пустоты горное видение даёт первый «физический» звук — ветер, камень, цепь.

---

### 4.6. Пролог: горное видение (B14)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** орбитальный облёт горы, караван, храм; предвестие Первого Кошмара.  
**Эмоциональная цель:** благоговение, древность, обречённость; «это уже случилось».

#### Музыка

- **Стиль:** древний оркестровый лAMENT с хором и низкими духовыми.
- **Настроение:** холодное величие; не героика.
- **BPM/тональность:** 50 BPM, D minor; медленные такты, 3-дольность.
- **Инструменты:** низкие струнные, рог, тромбон, мужской хор, рамочный барабан, бас-флейта.
- **Аранжировка:** 3-нотный мотив у рога; хор отвечает; барабан только на кульминации; в конце — обрыв.
- **Слои:** `mountain` (дрон/струнные), `caravan` (барабан/цепь), `temple` (хор/колокол), `silence`.
- **Начало/конец:** вход из пустоты; кульминация на храме; обрыв в белый шум/тишину.
- **Тишина:** после показа храма — 2 с только ветер, затем обрыв.

#### Референсы

1. **R03, «Prologue ~To the Ancient Land~» (Kow Otani, Shadow of the Colossus).** Почему: древняя земля, меланхолия, масштаб. Что взять: низкий рог, струнные, медленный подъём. Как применить: основа видения.
2. **R13, «Mountains» (Hans Zimmer, Interstellar).** Почему: грандиозность и время. Что взять: орган/струнные, тикающий пульс, нарастание. Как применить: облёт горы.
3. **R14, «Paul's Dream» (Hans Zimmer, Dune).** Почему: пророчество и ритуал. Что взять: голос, барабан, суб. Как применить: момент, когда камера проходит над караваном.
4. **R21, «The Ring Goes South» (Howard Shore, LOTR).** Почему: поход через холодные горы, величие без пафоса. Что взять: низкие струнные, рог, медленное нарастание. Как применить: облёт горного массива; не полную тему.
5. **R15, «On the Nature of Daylight» (Max Richter, Arrival).** Почему: меланхолия времени, струнный секстет. Что взять: медленную гармонию, человеческую печаль. Как применить: финальные 10 с перед обрывом.

#### Ambience (5–10)

- высокий ветер, свист в скалах;
- далёкий камнепад;
- снежная пыль, шелест;
- горный гул (низкий);
- далёкий звон цепи/бубенцов;
- храмовый гул/колокол (предвестие);
- ворон/птица? На высоте — редко; можно один далёкий крик;
- треск льда;
- обрыв в тишину.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ENV_WIND_GUST | Порыв | Широкий, с свистом, не «вакуум» | Постоянно. |
| ENV_ROCKFALL_SMALL | Камнепад | Далёкий, короткий | 1–2 раза. |
| ENV_ICE_CRACK | Лёд | Сухой треск | 1 раз. |
| ST_CARAVAN_BELL | Бубенцы | Далёкий, металлический | При проходе каравана. |
| ST_TEMPLE_HUM | Храм | Низкий гул/хор | При виде храма. |
| ST_VISION_END | Обрыв | Резкая тишина/белый шум | Переход. |

#### Голоса

- **Spell:** нет, только музыка/хор.
- **Sunny:** нет.
- **ПРЕДЛОЖЕНИЕ:** далёкий голос Ауро/команды, неразборчиво, как часть ветра. Не вводить новых реплик.

#### Общая концепция

Видение должно ощущаться как **воспоминание мира**, а не как кат-сцена игрока. Музыка идёт от низкого гула к хору и обрывается; после неё — цепь и ветер каравана, уже «внутри» сна.

---

### 4.7. Марш каравана / горная тропа (B15, S01)

**Статус:** РЕАЛИЗОВАНО (сцена и марш), звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни в цепи идёт по узкой горной тропе; ветер, снег, обрыв; впереди Ауро на белом коне; прибытие к стоянке.  
**Эмоциональная цель:** несвобода, холод, истощение, страх высоты; цепь — главный метроном.

#### Музыка

- **Стиль:** grim dark folk / оркестровый марш без героики.
- **Настроение:** усталость, холод, принуждение.
- **BPM/тональность:** 72 BPM, G minor; 4/4 с рудиментарной триолью.
- **Инструменты:** виолончель, контрабас, бас-флейта, рог, рамочный барабан, цепь/анвил, мужской хор без слов.
- **Аранжировка:** ритм цепи 3+3+2; низкие струнные играют остинато; рог — редкие зовы; хор — только на подъёме; никакой мелодии «героя».
- **Слои:**
  - `chain` — цепь/шаги, всегда;
  - `march` — струнные/барабан;
  - `auro` — светлый мотив (скрипка/рог) при виде Ауро;
  - `dread` — суб-бас/хор при взгляде в обрыв;
  - `silence` — при прибытии к лагерю.
- **Начало/конец:** начинается с первого шага цепи; заканчивается на подходе к стоянке, уступая место camp ambience.
- **Тишина:** в узких местах убрать музыку, оставить ветер/цепь/дыхание; Ауро — единственный «светлый» звук.

#### Референсы

1. **R06, «The Revenant Main Theme» (Ryuichi Sakamoto, Alva Noto, Bryce Dessner).** Почему: холод, выживание, минимализм. Что взять: виолончель, суб-дрон, дыхание, пространство. Как применить: основа марша.
2. **R22, «The Riders of Doom» (Basil Poledouris, Conan the Barbarian).** Почему: караван, древность, жестокость. Что взять: низкие духовые, мужской хор, барабаны; сдержанно. Как применить: момент, когда караван появляется целиком.
3. **R21, «The Ring Goes South» (Howard Shore, LOTR).** Почему: поход, холод, товарищество. Что взять: низкие струнные, рог, медленное нарастание. Как применить: подъём по тропе.
4. **R30, «The City Must Survive» (Piotr Musiał, Frostpunk).** Почему: мрачный марш выживания. Что взять: виолончельное остинато, низкие духовые, industrial percussion. Как применить: ритм цепи/шагов.
5. **R29, «The Grey» (Marc Streitenfeld, The Grey).** Почему: холод, усталость, отсутствие надежды. Что взять: эмбиент, далёкое пианино, ветер. Как применить: паузы между музыкальными фразами.

#### Ambience (5–10)

- ветер в скалах: свист 400–1200 Гц, порывы;
- снег под ногами: скрип/хруст, разный на утоптанном и рыхлом;
- цепь: звон 3+3+2, натяжение, трение о камень;
- дыхание Санни и соседей;
- копыта белого коня, кожа седла, металл копья;
- скрип кожаных ремней/кандалов;
- далёкий камнепад, треск льда;
- снежная пыль по кромке обрыва;
- «пустота» за краем: без дна, без эха;
- далёкий бубен/колокол каравана.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| PL_WALK_SNOW | Шаг по снегу | Скрип, мягкий удар, лёгкий ветер | Утоптанный снег. |
| PL_WALK_ICE | Шаг по льду | Осторожный, с проскальзыванием | Ледяные пятна. |
| PL_WALK_STONE | Шаг по камню | Сухой, с эхом | Мостовая. |
| PL_CHAIN_STEP | Цепь в шаге | Металл, 3+3+2, не каждый шаг | Постоянно. |
| PL_CHAIN_TENSION | Натяжение | Металл/кожа, короткий | При остановке колонны. |
| PL_BREATH_EXERT | Дыхание | Холодное, с усилием | Постоянно. |
| ENV_HORSE | Конь | Копыта, храп, седло | Ауро. |
| ENV_ROCKFALL_SMALL | Камнепад | Далёкий, предупреждение | 2–3 раза. |
| ENV_ICE_CRACK | Лёд | Сухой треск | 1–2 раза. |
| ENV_WIND_GUST | Порыв | Широкий, с снегом | По погоде. |
| ST_WHIP | Удар кнута | Резкий, но не громче ветра | Сюжетный beat. |

#### Голоса

- **Sunny:** барки (30 штук) — тихо, с одышкой, без пафоса; внутренний голос — ближе, медленнее.
- **Auro:** в текущих диалогах нет реплик; **ПРЕДЛОЖЕНИЕ** — 2–3 короткие команды, если будет добавлен. Голос молодой, чистый, с лёгкой надменностью, но без злодейства.
- **Crowd:** стоны, выдохи, шёпот, без слов.
- **ПРЕДЛОЖЕНИЕ:** команды надсмотрщика — грубый, хриплый, далёкий; без разборчивых слов.

#### Общая концепция

Цепь — это не звуковой эффект, а **ритм сцены**. Музыка должна подстраиваться под шаг, а не наоборот. Ауро звучит светлее и чище, но не громче; его голос/конь — островок другого мира. К концу марша музыка уходит, остаётся облегчение от того, что цепь остановилась.

---

### 4.8. Стоянка каравана: лагерь (S02, CAMP)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** еда, Bloodbane, осмотр повозки, разговоры; игрок исследует лагерь.  
**Эмоциональная цель:** ложная безопасность, тепло, усталость; на границе — страх.

#### Музыка

- **Стиль:** камерный фолк / тёмный лирический эмбиент.
- **Настроение:** «мы живы ещё один вечер».
- **BPM/тональность:** 60 BPM, A minor; 3/4 или 6/8.
- **Инструменты:** нейлоновая гитара, виолончель, флейта, контрабас, женский голос без слов, костёр.
- **Аранжировка:** гитара — 4-тактовый круг; виолончель — длинные ноты; голос — только на второй половине; без барабанов.
- **Слои:** `fire` (костёр/ветер), `camp` (гитара/виолончель), `night` (дрон/голос), `danger` (низкий пульс при приближении к Тирану/повозке).
- **Начало/конец:** начинается с прибытия, когда цепь снята; заканчивается при начале атаки.
- **Тишина:** между репликами — костёр и ветер; музыка не должна заполнять каждую паузу.

#### Референсы

1. **R02, «The Choice» (Gustavo Santaolalla, The Last of Us).** Почему: хрупкое тепло, горе, близость. Что взять: нейлоновая гитара, виолончель, паузы. Как применить: основа лагеря.
2. **R31, «That's the Way It Is» (Daniel Lanois, RDR2).** Почему: лагерная элегия, усталость, дорога. Что взять: акустическая гитара, pedal steel, тёплый бас; инструментал, без вокала. Как применить: ночная сцена.
3. **R32, «The Camp» (Borislav Slavov, Baldur's Gate 3).** Почему: убежище, характеры, тепло. Что взять: струнные, флейту, мягкую перкуссию. Как применить: день/разговоры.
4. **R33, «Sleeping» (Jan Valta, Kingdom Come).** Почему: средневековый лагерь, тишина. Что взять: лютню/арфу, низкие струнные. Как применить: ночь, сон.
5. **R34, «The Green Mile» (Thomas Newman).** Почему: милосердие и печаль. Что взять: пианино, струнные, без перкуссии. Как применить: сцена с ветераном (после).

#### Ambience (5–10)

- костёр: потрескивание, шипение, редкие хлопки;
- ветер в ткани/палатке;
- лошади: храп, копыта, седло;
- цепь: редкое звяканье;
- далёкий камнепад;
- кипящая вода/котелок;
- кожа/ремни/ткань;
- дыхание спящих;
- ночной камень: редкий низкий скрип;
- шаги по утоптанной земле/снегу;
- (без насекомых — высокогорье).

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ENV_FIRE_LOOP | Костёр | Потрескивание, шипение, без «газового» гула | Постоянно. |
| ENV_FIRE_POP | Хлопок | Короткий, случайный | 1 раз в 3–8 с. |
| PL_PICKUP_RATIONS | Еда | Ткань/дерево/металл | S02. |
| PL_DRINK | Фляга | Металл/вода/выдох | S02. |
| ENV_WAGON_CREAK | Повозка | Дерево, металл, скрип | Осмотр. |
| ENV_CHAIN_HIT | Цепь | Металл, короткий | Движение. |
| PL_SIT | Сесть | Ткань/дерево/выдох | У костра. |
| PL_BREATH_COLD | Дыхание | Холодное, тихое | Ночь. |
| ST_NIGHT_FALL | Ночь | Ветер меняется, звуки глохнут | Переход. |

#### Голоса

- **Hero:** 37 реплик; молодой, уставший, благородный; не «паладин», а человек, который держится; низкий-средний тембр, медленный темп.
- **Shifty:** 18 реплик; молодой, нервный, быстрый; лёгкий хрип; часто дышит.
- **Scholar:** 16 реплик; образованный, спокойный, чуть снисходительный; средний тембр, чёткая артикуляция.
- **Broad slave:** 5 реплик; грубый, громкий, агрессивный; низкий.
- **Veteran:** 4 реплики; сломленный, тихий, хриплый; говорит с паузами.
- **Sunny:** внутренний голос; ирония, усталость.
- **Crowd:** 4–6 голосов, без слов.

#### Общая концепция

Лагерь — единственное место, где музыка может быть тёплой. Но тепло должно быть **хрупким**: один низкий пульс при взгляде на повозку/Тирана напоминает, что это не безопасность. Костёр — главный «инструмент»; он должен звучать ближе, чем музыка.

---

### 4.9. Стоянка каравана: нападение и личинка (S03–S04)

**Статус:** РЕАЛИЗОВАНО (события), звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** камнепад, появление Тирана, смерть широкоплечего, личинка, ключ, освобождение от цепи.  
**Эмоциональная цель:** паника, физическая угроза, хаос; затем точечный ужас личинки.

#### Музыка

- **Стиль:** ритуальная перкуссия + низкий оркестр + industrial.
- **Настроение:** катастрофа, а не «бой».
- **BPM/тональность:** 140 BPM, D minor; 4/4, но сбивчивый.
- **Инструменты:** тайко/рамочные барабаны, низкие струнные, тромбоны, мужской хор, дисторшн-виолончель, металл.
- **Аранжировка:** начинается с одного удара; барабаны входят слоями; хор — только на появлении Тирана; мелодии нет, только ритм/кластеры.
- **Слои:** `impact` (удары/камни), `tyrant` (низкий хор/бас), `larva` (высокие струнные/щелчки), `panic` (барабаны), `silence` (после падения).
- **Начало/конец:** резкий вход на первом камне; заканчивается на освобождении от цепи/ключе.
- **Тишина:** после падения Тирана — 3–5 с только пыль/камни; затем личинка.

#### Референсы

1. **R25, «The Stranger» (Bear McCreary, God of War).** Почему: brutal, percussive, giant; бой как стихия. Что взять: низкие барабаны, брас, струнные, резкие акценты. Как применить: появление Тирана.
2. **R04, «Cleric Beast» (Tsukasa Saitoh, Bloodborne).** Почему: monstrous chaos, choir, strings. Что взять: низкий хор, струнные, неровный ритм. Как применить: атака/личинка.
3. **R03, «A Violent Encounter» (Kow Otani, Shadow of the Colossus).** Почему: гигант, трагедия, масштаб. Что взять: рог, струнные, тайко. Как применить: момент, когда Тиран встаёт.
4. **R27, «Kaiju» (Ramin Djawadi, Pacific Rim).** Почему: гигантский монстр, суб-бас. Что взять: суб, брас, industrial percussion. Как применить: удар/падение; не весь трек.
5. **R26, «BFG Division» (Mick Gordon, Doom).** Почему: relentless industrial chaos. Что взять: дисторшн-бас, металлические удары, драйв. Как применить: короткий слой `panic` для личинки, не для всего боя.

#### Ambience (5–10)

- камни/лёд падают: удар, осколки, свист;
- Тир: низкий рёв, шаги, вдох/выдох, шерсть/мышцы;
- земля/снег: глухой удар, дрожь;
- дерево повозки: треск, скрип, удар;
- цепь: натяжение, лязг, разрыв;
- люди: крики, приказы, паника, без слов;
- снежная пыль/ветер;
- личинка: влажные щелчки, скрежет, высокий визг;
- сердцебиение Санни;
- после — тишина/пыль.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ENV_ROCKFALL_LARGE | Камнепад | Удар + осколки + свист | Beat 1. |
| ENV_ICE_SHATTER | Лёд | Осколки, резкий | Beat 1. |
| CB_TYRANT_ROAR | Рёв | Низкий, с суб-гармониками, не «лев» | Появление. |
| CB_TYRANT_STEP | Шаг | Глухой, с дрожью земли | Движение. |
| CB_TYRANT_SWIPE | Удар лапой | Свист + удар + треск | Атака. |
| ST_BROAD_DEATH | Смерть широкоплечего | Тяжёлый удар, хрип, обрыв | Beat 2. |
| CB_LARVA_WRITHE | Личинка | Влажные щелчки, дрожь | Появление. |
| CB_LARVA_SCREECH | Визг | Высокий, короткий, не «птица» | Атака. |
| ST_KEY_THROW | Ключ | Металл по снегу/камню | Beat 4. |
| ST_UNLOCK | Освобождение | Замок, цепь, выдох | Beat 5. |

#### Голоса

- **Sunny:** барки/крики, с одышкой; не «героические» реплики.
- **Hero:** команды/предупреждения, если есть в диалоге; голос должен перекрывать хаос, но не орать.
- **Shifty:** паника, высокий, быстрый.
- **Scholar:** холодный анализ, ровный, даже в хаосе.
- **Broad slave:** агрессия/страх, низкий.
- **Crowd:** крики, стоны, приказы; без разборчивых слов.
- **Tyrant:** без речи; только дыхание/рёв/щелчки.
- **Larva:** без речи; визг/щелчки.

#### Общая концепция

Атака должна быть **физически громкой**, но не «стеной шума»: у каждого слоя есть своя роль, и между ударами есть микро-паузы. Тиран — не музыкальная тема, а **погодное явление**; его появление должно изменить акустику (больше низа, меньше верха). Личинка — контраст: маленькая, мокрая, точечная, почти интимная.

---

### 4.10. Стоянка каравана: повозка (S05, WAGON)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** снятие клиньев, петля, толчок, падение повозки, падение Тирана.  
**Эмоциональная цель:** физическое усилие, надежда, затем шок и тишина.

#### Музыка

- **Стиль:** mechanical tension / ancient battle.
- **Настроение:** «сейчас или никогда».
- **BPM/тональность:** 100 BPM, C minor; 4/4.
- **Инструменты:** анвил/металл, низкие струнные, хурди-гарди, мужской хор, барабаны.
- **Аранжировка:** остинато на анвиле; струнные поднимаются; хор входит на толчке; после падения — резкий стоп.
- **Слои:** `plan` (низкий пульс), `effort` (анвил/струнные), `fall` (удар/хор), `silence`.
- **Начало/конец:** начинается после плана; заканчивается на падении Тирана.
- **Тишина:** 3–5 с после падения, только пыль/камни/дыхание.

#### Референсы

1. **R06, «Killing Hawk» (The Revenant).** Почему: физическое напряжение, преследование, холод. Что взять: низкие струнные, удары, дыхание. Как применить: снятие клиньев/толчок.
2. **R23, «The Chase» (James Horner, Apocalypto).** Почему: tribal percussion, chase, physicality. Что взять: рамочные барабаны, флейту, крики. Как применить: толчок/бег.
3. **R21, «The Uruk-hai» (Howard Shore, LOTR: Two Towers).** Почему: siege, industrial war, male choir. Что взять: низкий брас, барабаны, хор. Как применить: падение повозки.
4. **R24, «Brothers in Arms» (Junkie XL, Mad Max: Fury Road).** Почему: mechanical chaos, engines, metal. Что взять: дисторшн-бас, металлические удары, драйв. Как применить: движение повозки.
5. **R22, «Battle of the Mounds» (Basil Poledouris, Conan).** Почему: ancient battle, brass, drums. Что взять: брас, барабаны, хор. Как применить: падение Тирана.

#### Ambience (5–10)

- дерево: скрип, треск, трение;
- металл: клинья, обручи, цепь;
- колесо: скрип, удар, качение;
- камни/снег: осыпь, удар;
- люди: дыхание, команды, крики;
- Тиран: рёв, шаги, дыхание;
- ветер/пыль;
- после падения: глухой удар, эхо, тишина.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_WEDGE_REMOVE | Клинья | Дерево/металл, короткий | S05. |
| ST_LOOP_CHAIN | Петля | Цепь, натяжение | S05. |
| ST_WAGON_PUSH | Толчок | Дерево, усилие, дыхание | S05. |
| ENV_WAGON_WHEEL | Колесо | Скрип, качение | Движение. |
| ENV_WAGON_CRASH | Падение | Треск, удар, обломки | Кульминация. |
| CB_TYRANT_FALL | Падение Тирана | Низкий удар, дрожь, хор-стоп | Кульминация. |
| ENV_DUST | Пыль | Шелест, кашель | После. |

#### Голоса

- **Sunny:** усилие, короткие фразы, без пафоса.
- **Hero:** команда/предупреждение.
- **Scholar:** расчёт, холодно.
- **Crowd:** крики/усилие.
- **Tyrant:** без речи.

#### Общая концепция

Сцена должна звучать как **работа**, а не как бой: дерево, металл, дыхание, усилие. Музыка поддерживает темп, но не заглушает физику. Падение повозки — самый громкий момент; после него — тишина, в которой игрок слышит собственное дыхание.

---

### 4.11. Стоянка каравана: последствия, ночь, рассвет (S06)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** выжившие, совет, задачи, фляги; ветеран и Silver Bell; ночь у огня; отравление фляг; рассвет и уход.  
**Эмоциональная цель:** горе, милосердие, тревога, хрупкая надежда.

#### Музыка

- **Стиль:** камерная элегия / тёмный фолк.
- **Настроение:** «мы пережили ночь, но что-то в нас умерло».
- **BPM/тональность:** 48 BPM, E minor; 4/4, свободный темп.
- **Инструменты:** виолончель, пианино, нейлоновая гитара, контрабас, женский голос без слов, далёкий хор.
- **Аранжировка:** 8-тактовые фразы; виолончель ведёт; пианино отвечает; голос — только на рассвете; без барабанов.
- **Слои:** `grief` (виолончель/пианино), `night` (дрон/огонь), `dawn` (струнные/голос), `silence`.
- **Начало/конец:** начинается после падения Тирана; заканчивается на уходе с стоянки.
- **Тишина:** после смерти ветерана — 4–6 с только огонь; после отравления — тишина/дыхание; рассвет — без победного аккорда.

#### Референсы

1. **R02, «All Gone (No Escape)» (Gustavo Santaolalla, The Last of Us).** Почему: горе, пустота, отсутствие утешения. Что взять: гитара, низкий дрон, паузы. Как применить: после смерти ветерана.
2. **R31, «That's the Way It Is» (Daniel Lanois, RDR2).** Почему: лагерная элегия, прощание. Что взять: акустическая гитара, pedal steel, тёплый бас; без вокала. Как применить: ночь у огня.
3. **R36, «Song for Jesse» (Nick Cave & Warren Ellis, The Assassination of Jesse James).** Почему: траурный пейзаж, красота смерти. Что взять: скрипка, пианино, эмбиент. Как применить: тело ветерана/Silver Bell.
4. **R37, «The Road» (Nick Cave & Warren Ellis, The Road).** Почему: опустошение, родитель/ребёнок, серость. Что взять: разреженное пианино, дрон. Как применить: ночь/яд.
5. **R45, «The Departure» (Max Richter, The Leftovers).** Почему: утрата и трансценденция. Что взять: струнные, пианино, голос без слов. Как применить: рассвет; не делать «победный» финал.

#### Ambience (5–10)

- костёр: тише, чем днём; угли, редкие хлопки;
- ветер, изменивший направление;
- дыхание спящих, храп;
- цепь, редкое звяканье;
- далёкий камнепад;
- ночной камень: низкий скрип;
- фляги: металл/пробка/вода;
- яд: тихий вливание/капли;
- рассвет: ветер стихает, снег подтаивает, капель;
- шаги по замёрзшей земле.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_VETERAN_APPROACH | Подход к ветерану | Хрип, ткань, металл | S06. |
| ST_VETERAN_KILL | Милосердие | Короткий, тяжёлый, без смакования | S06. |
| ST_BELL_OBTAIN | Silver Bell | Маленький колокольчик, чистый, тихий | S06. |
| ST_NIGHT_FALL | Ночь | Ветер, огонь, приглушение | Переход. |
| ST_POISON_POUR | Яд | Жидкость, металл, тихий звук | S06. |
| ST_DAWN | Рассвет | Ветер, капель, дальний колокол | Переход. |
| PL_BREATH_COLD | Дыхание | Холодное, ночь | Постоянно. |

#### Голоса

- **Veteran:** 4 реплики; сломленный, тихий, хриплый; говорит медленно, с паузами; не «монстр».
- **Hero:** усталый, но держится; тише, чем днём.
- **Shifty:** тихо, тревожно; если жив.
- **Scholar:** холодный, расчётливый; в ночи — почти шёпот.
- **Sunny:** внутренний голос; горе без пафоса.
- **Silver Bell:** не голос; звук колокольчика — лейтмотив.

#### Общая концепция

Ночь должна быть **тише**, чем день, но не спокойнее. Костёр — единственный тёплый звук; всё остальное — дыхание, металл, ветер. Рассвет не приносит облегчения: музыка остаётся минорной, просто становится светлее по тембру. Silver Bell — первый «святой» звук в игре; он должен быть чистым, но одиноким.

---

### 4.12. Тропа паломника: разрушенная дорога и подъём (S07)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** разрушенная дорога, старая тропа, брошенный меч, подъём, альков впереди.  
**Эмоциональная цель:** усталость, холод, упрямство; впереди — что-то древнее.

#### Музыка

- **Стиль:** pilgrimage / dark folk / камерный оркестр.
- **Настроение:** путь, испытание, тихая решимость.
- **BPM/тональность:** 64 BPM, D minor; 4/4, но фразы неровные.
- **Инструменты:** виолончель, бас-флейта, рог, рамочный барабан, арфа, мужской голос без слов.
- **Аранжировка:** 3-нотный мотив у бас-флейты; виолончель — остинато; барабан — только на подъёме; арфа — редкие капли.
- **Слои:** `road` (виолончель/флейта), `ascent` (барабан/рог), `temple` (далёкий хор), `silence`.
- **Начало/конец:** начинается после стоянки; заканчивается у алькова.
- **Тишина:** на разрушенной дороге — только ветер/шаги; музыка появляется на подъёме.

#### Референсы

1. **R21, «The Ring Goes South» (Howard Shore, LOTR).** Почему: поход, холод, товарищество. Что взять: низкие струнные, рог, медленное нарастание. Как применить: подъём.
2. **R40, «Gabriel's Oboe» (Ennio Morricone, The Mission).** Почему: духовное восхождение, надежда. Что взять: соло-обой, струнные; очень сдержанно. Как применить: момент, когда вдали показывается храм.
3. **R05, «The Road of Trials» (Austin Wintory, Journey).** Почему: паломничество, испытание, минимализм. Что взять: виолончель, арфу, перкуссию. Как применить: основная тема пути.
4. **R30, «We Are All Guests Upon the Land» (Austin Wintory, The Banner Saga).** Почему: северный поход, меланхолия. Что взять: низкие струнные, мужской голос, барабан. Как применить: вид на горы.
5. **R06, «The Revenant Main Theme» (Sakamoto/Noto/Dessner).** Почему: холод, выживание. Что взять: виолончель, дрон, ветер. Как применить: паузы между фразами.

#### Ambience (5–10)

- ветер в скалах, свист;
- снег/лёд под ногами;
- треск льда, камнепад;
- далёкий Тиран (низкий гул/рёв, почти неразличимый);
- ворон/птица? Редко; можно один далёкий крик;
- вода: капель/ручей;
- камень: скрип/осыпь;
- дыхание Санни;
- звон Silver Bell (если есть);
- храм: далёкий гул/хор.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_ROAD_GAP | Разрушенная дорога | Камень/треск, ветер в провале | S07. |
| ST_SWORD_DISCARD | Брошенный меч | Металл по камню, короткий | S07. |
| PL_WALK_ICE | Шаги по льду | Осторожные, скольжение | Подъём. |
| PL_WALK_SNOW | Шаги по снегу | Скрип, усталость | Подъём. |
| ENV_ROCKFALL_SMALL | Камнепад | Далёкий/близкий | 2–3 раза. |
| ENV_ICE_CRACK | Лёд | Треск | 1–2 раза. |
| ST_TEMPLE_HUM | Храм | Низкий гул | Приближение. |

#### Голоса

- **Sunny:** внутренний голос; усталость, ирония, но без шуток.
- **Hero:** команды/поддержка; тише, чем в лагере.
- **Shifty:** жалобы/страх.
- **Scholar:** анализ, расчёт.
- **ПРЕДЛОЖЕНИЕ:** далёкий голос Тирана — не слова, а низкий выдох в ветре.

#### Общая концепция

Подъём — это **работа ног**, а не героический марш. Музыка должна быть экономной; главный ритм — шаги и дыхание. Храм вдали — единственный «светлый» звук; он должен быть тише, чем ожидает игрок.

---

### 4.13. Тропа паломника: альков и рассвет (S08)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** альков, слепота, смерть Шифти, рассвет, решение идти дальше.  
**Эмоциональная цель:** горе, беспомощность, тишина; затем — холодная решимость.

#### Музыка

- **Стиль:** камерная элегия / музыкальная шкатулка.
- **Настроение:** «мы потеряли кого-то, и это не будет последней потерей».
- **BPM/тональность:** 42 BPM, A minor; без ритма.
- **Инструменты:** музыкальная шкатулка, виолончель, пианино, дыхание, далёкий ветер.
- **Аранжировка:** шкатулка — 4-нотный мотив; виолончель входит на 2-м проведении; пианино — одна нота; никаких барабанов.
- **Слои:** `alcove` (шкатулка/пианино), `grief` (виолончель), `dawn` (струнные/свет), `silence`.
- **Начало/конец:** начинается при входе в альков; заканчивается на выходе к рассвету.
- **Тишина:** после смерти Шифти — 5–8 с только ветер/дыхание; рассвет — без музыки 10 с, затем одна нота.

#### Референсы

1. **R02, «Vanishing Grace» (Gustavo Santaolalla, The Last of Us).** Почему: тихое горе, человечность. Что взять: гитара, виолончель, паузы. Как применить: смерть Шифти.
2. **R37, «The Boy» (Nick Cave & Warren Ellis, The Road).** Почему: хрупкость, родитель/ребёнок, потеря. Что взять: пианино, скрипку, дрон. Как применить: альков.
3. **R05, «Pi's Lullaby» (Mychael Danna, Life of Pi).** Почему: рассвет, духовность, колыбельная. Что взять: голос без слов, арфу, струнные. Как применить: рассвет.
4. **R06, «Goodbye to Hawk» (The Revenant).** Почему: смерть, отпускание. Что взять: виолончель, низкий дрон. Как применить: момент смерти.
5. **R55, «Sweden» (C418, Minecraft).** Почему: горько-сладкая простота. Что взять: мягкое пианино; использовать осторожно, чтобы не звучало «по-игровому». Как применить: рассвет, если нужна человеческая теплота.

#### Ambience (5–10)

- ветер в алькове, приглушённый;
- капель/ручей;
- снег, тающий на рассвете;
- дыхание Шифти (слабое, неровное);
- ткань/кожа;
- далёкий камнепад;
- утро: птицы? На высокогорье — редко; можно один далёкий крик;
- храм: гул/хор;
- тишина после смерти.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_ALCOVE_REST | Отдых | Ткань, выдох, камень | S08. |
| ST_SHIFTY_DEATH | Смерть Шифти | Слабый выдох, обрыв, тишина | S08. |
| PL_BREATH_COLD | Дыхание | Холодное, неровное | Постоянно. |
| ENV_DAWN | Рассвет | Ветер стихает, капель | Переход. |
| ST_TEMPLE_HUM | Храм | Далёкий гул | При взгляде. |

#### Голоса

- **Shifty:** 18 реплик; к смерти — слабее, тише, с паузами; не «красиво умирает», а боится.
- **Hero:** тихо, устало; поддерживает, но не утешает.
- **Scholar:** холодно, отстранённо.
- **Sunny:** внутренний голос; гнев/горе, без мелодрамы.

#### Общая концепция

Альков — самая тихая сцена игры. Музыка не должна «оплакивать» Шифти; она должна **оставить место** для игрока. После смерти — почти полная тишина, в которой слышно дыхание Санни. Рассвет — не катарсис, а необходимость идти дальше.

---

### 4.14. Тропа паломника: Учёный и пещера (S09–S10)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** приманка, разоблачение Учёного, пещера, признание, яд, ранение, побег.  
**Эмоциональная цель:** паранойя, клаустрофобия, предательство, физическая боль.

#### Музыка

- **Стиль:** атональный камерный эмбиент / prepared piano.
- **Настроение:** «здесь никому нельзя верить».
- **BPM/тональность:** 70 BPM, без тонального центра; свободные такты.
- **Инструменты:** препарированное пианино, бас-кларнет, металлические перкуссии, виолончель sul ponticello, капли.
- **Аранжировка:** короткие мотивы, которые не завершаются; паузы; металлические удары; никакой гармонической опоры.
- **Слои:** `scholar` (пианино/кларнет), `cave` (дрон/капли), `pain` (высокие струнные/сердце), `escape` (ритм/дыхание), `silence`.
- **Начало/конец:** начинается при разоблачении; заканчивается на выходе из пещеры.
- **Тишина:** после признания — 2–3 с только капли; после ранения — обрыв в звон.

#### Референсы

1. **R38, «The Descent» (David Julyan, The Descent).** Почему: клаустрофобная пещера, темнота. Что взять: низкие дроны, капли, дыхание. Как применить: пещера.
2. **R39, «Sub-Level» (James Horner, Aliens).** Почему: industrial/military tension. Что взять: металлические пульсы, низкие струнные. Как применить: коридор/пещера.
3. **R19, «Humanity Part II» (Ennio Morricone, The Thing).** Почему: паранойя, изоляция. Что взять: сердцебиение, диссонирующие струнные. Как применить: разговор с Учёным.
4. **R20, «Love» (Mica Levi, Under the Skin).** Почему: alien, unsettling, телесность. Что взять: глиссандо, суб, голосовые текстуры. Как применить: момент признания/яда.
5. **R08, «Pump Room» (Hildur Guðnadóttir, Chernobyl).** Почему: бетон, промышленность, обречённость. Что взять: гул, металл. Как применить: узкий проход.

#### Ambience (5–10)

- капли: разные интервалы, эхо;
- низкий гул пещеры;
- влажный камень, скрип;
- дыхание, эхо шагов;
- металл: пряжка, нож, фляга;
- вода: ручей/лужа;
- далёкий камнепад;
- ткань/кожа;
- сердцебиение Санни;
- тишина между каплями.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_SCHOLAR_CONFRONT | Разоблачение | Тихий металл/ткань, без музыки | S09. |
| ST_CAVE_ENTER | Вход | Гул, капли, эхо | S10. |
| ST_CONFESSION | Признание | Дыхание, пауза, тишина | S10. |
| ST_WOUND | Ранение | Резкий вдох, ткань, капли | S10. |
| ST_CAVE_ESCAPE | Побег | Шаги, дыхание, камни | S10. |
| PL_WALK_STONE | Шаги | Эхо, влажный камень | Пещера. |
| PL_WALK_WATER | Шаги | Всплеск, мелководье | Лужи. |

#### Голоса

- **Scholar:** 16 реплик; спокойный, умный, манипулятивный; к признанию — быстрее, неровнее; не «злодейский смех».
- **Hero:** тихо, с болью; не героический.
- **Shifty:** если жив — паника; если мёртв — тишина.
- **Sunny:** внутренний голос; страх/гнев, дыхание.
- **ПРЕДЛОЖЕНИЕ:** голос Тирана в пещере — не слова, а низкий резонанс в камне.

#### Общая концепция

Пещера должна звучать **телесно**: дыхание, капли, сердце, металл. Музыка почти отсутствует; её заменяет ритм капель и шагов. После ранения — резкий переход в субъективный звон, как в изоляторе, но короче.

---

### 4.15. Тропа паломника: смерть Героя и подход к храму (S11–S12)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Silver Bell, смерть Героя, подход к храму, невидимый страж, порог.  
**Эмоциональная цель:** жертва, благоговение, страх; «мы дошли, но цена слишком высока».

#### Музыка

- **Стиль:** трагический оркестровый лAMENT / хор.
- **Настроение:** жертва, древность, порог.
- **BPM/тональность:** 58 BPM, D minor; 4/4.
- **Инструменты:** мужской хор, низкие струнные, рог, тромбон, виолончель соло, колокол.
- **Аранжировка:** хор входит на захвате Героя; струнные поднимаются; колокол — один удар; после — тишина.
- **Слои:** `bell` (колокол), `hero` (виолончель), `tyrant` (низкий хор/бас), `temple` (хор/гул), `silence`.
- **Начало/конец:** начинается со звона Silver Bell; заканчивается на пороге храма.
- **Тишина:** после смерти Героя — 4–6 с только ветер/колокол; на пороге — гул/скрип.

#### Референсы

1. **R21, «The Bridge of Khazad-dûm» (Howard Shore, LOTR).** Почему: жертва, хор, обрушение. Что взять: мужской хор, низкий брас, барабаны, трагический подъём. Как применить: захват Героя.
2. **R04, «Father Gascoigne» (Tsukasa Saitoh, Bloodborne).** Почему: трагическая охота, ярость. Что взять: струнные, хор, неровный ритм. Как применить: борьба с Тираном.
3. **R03, «The End of the Battle» (Kow Otani, Shadow of the Colossus).** Почему: трагическая победа. Что взять: соло-скрипку, низкие струнные, тишину. Как применить: после смерти Героя.
4. **R41, «Guts» (Susumu Hirasawa, Berserk).** Почему: dark fantasy elegy, человеческая боль. Что взять: голос, гитару, синт; только для темы Героя. Как применить: момент, когда Герой понимает, что умрёт.
5. **R40, «Long, Long Time Ago» (Javier Navarrete, Pan's Labyrinth).** Почему: тёмная сказка, потеря. Что взять: музыкальную шкатулку, струнные. Как применить: подход к храму.

#### Ambience (5–10)

- ветер, сильнее; снег;
- колокол Silver Bell: чистый, с долгим хвостом;
- Тиран: низкий рёв, шаги, дыхание;
- храм: гул, хор, каменный скрип;
- страж: низкий гул/искажение воздуха;
- шаги по камню/снегу;
- дыхание Санни;
- далёкий камнепад;
- тишина после.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_BELL_RING | Silver Bell | Чистый колокол, долгий хвост | S11. |
| ST_HERO_CONFRONT | Герой | Металл, ткань, дыхание | S11. |
| CB_TYRANT_ROAR | Тиран | Низкий рёв | S11. |
| ST_HERO_TAKEN | Захват | Тяжёлый удар, хор-стоп | S11. |
| ST_HERO_DEATH | Смерть | Тишина, ветер, колокол | S11. |
| ST_GUARD_PRESENCE | Страж | Низкий гул, искажение, без слов | S12. |
| ST_THRESHOLD_CREAK | Порог | Каменный скрип/трение | S12. |

#### Голоса

- **Hero:** 37 реплик; к смерти — тише, с болью; последние фразы почти шёпот.
- **Sunny:** внутренний голос; гнев/горе, без пафоса.
- **Tyrant:** без речи.
- **Guard:** без речи; только звук присутствия.
- **ПРЕДЛОЖЕНИЕ:** голос Silver Bell — не голос, а чистый тон; он должен быть слышен даже в бою.

#### Общая концепция

Сцена должна быть **жертвой**, а не победой. Музыка поднимается до захвата и обрывается; после — только ветер и колокол. Порог храма — самый тихий момент: игрок слышит скрип камня и собственное дыхание, прежде чем войти.

---

### 4.16. Святилище Тени (S13)

**Статус:** РЕАЛИЗОВАНО, звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** вход в храм, алтарь, семь подношений, появление Тирана, тени, смерть Тирана, тишина.  
**Эмоциональная цель:** благоговение, ложный покой, ужас, божественное вмешательство, опустошение.

#### Музыка

- **Стиль:** sacred dark ambient / хор / камерный оркестр.
- **Настроение:** «место, где тебя не спасут, но, возможно, заметят».
- **BPM/тональность:** 40 BPM, D minor; без ритма до Тирана.
- **Инструменты:** низкий хор, виолончель, стеклянная гармоника, орган, суб-бас, колокол, тёмные струнные.
- **Аранжировка:** один аккорд Dm; хор на «м»; стеклянные капли; при Тиране — низкий пульс; при тенях — обратный хор/кластер; после — тишина.
- **Слои:** `altar` (дрон/хор), `tyrant` (низкий пульс/брас), `shadow` (обратный хор/инфразвук), `silence`.
- **Начало/конец:** начинается на входе; заканчивается после смерти Тирана, тишиной.
- **Тишина:** после разрыва Тирана — 8–12 с только капли/ветер; не добавлять победный аккорд.

#### Референсы

1. **R04, «Ebrietas, Daughter of the Cosmos» (Yuka Kitamura, Bloodborne).** Почему: космический хор, священный ужас. Что взять: низкий хор, струнные, орган; не полную тему. Как применить: алтарь/появление Тирана.
2. **R70, «Soul of Cinder» (Yuka Kitamura, Dark Souls III).** Почему: элегия, апокалипсис, пианино/струнные. Что взять: пианино, струнные, хор. Как применить: момент, когда Санни ложится на алтарь.
3. **R69, «Godskin Apostles» (FromSoftware, Elden Ring).** Почему: ритуал, неправильный метр, хор. Что взять: нечётный метр, струнные, хор. Как применить: семь подношений.
4. **R12, «Requiem» (György Ligeti, 2001).** Почему: космическая пустота, хор как материя. Что взять: кластеры, глиссандо. Как применить: появление теней.
5. **R42, «Death Is the Road to Awe» (Clint Mansell, The Fountain).** Почему: трансценденция, смерть, свет. Что взять: струнные, хор, нарастание; использовать на пробуждении Тени. Как применить: теневые щупальца.

#### Ambience (5–10)

- ветер через проломы крыши;
- снег/лёд: шорох, капли;
- каменный гул/скрип;
- эхо шагов в зале;
- лунный свет: «тишина» как звук;
- ткань/плащ Санни;
- алтарь: сухой камень, впитывание крови;
- тени: низкий шёпот/дыхание без слов;
- Тиран: рёв, шаги, дыхание;
- после: капли, ветер.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ST_ALTAR_LIE | Ложиться на алтарь | Ткань, камень, выдох | S13. |
| ST_BLOOD_ABSORB | Кровь впитывается | Тихий впитывающий звук, без «смака» | S13. |
| ST_TYRANT_ENTER | Вход Тирана | Шаги, низкий рёв, эхо | S13. |
| ST_SHADOW_TENDRILS | Тени | Обратный хор, шёпот, инфразвук | S13. |
| ST_TYRANT_TORN | Разрыв | Тяжёлый треск, хор-стоп, тишина | S13. |
| ST_SILENCE | Тишина | 8–12 с без музыки | После. |
| ENV_STONE_GROAN | Камень | Низкий скрип | Постоянно. |

#### Голоса

- **Sunny:** внутренний голос; к алтарю — тише, медленнее; без героики.
- **Tyrant:** без речи.
- **Shadow:** без речи; голос Тени — не слова, а дыхание/шёпот.
- **ПРЕДЛОЖЕНИЕ:** на моменте, когда кровь впитывается, — один низкий женский голос без слов, очень далеко. Не объяснять, что это.

#### Общая концепция

Святилище — **самая тихая и самая громкая** сцена одновременно. До Тирана — почти без музыки, только камень и дыхание. После — божественное вмешательство как **превышение** допустимого: хор, инфразвук, обратные голоса. Но после разрыва — не победа, а пустота: игрок должен услышать, как капает вода.

---

### 4.17. Звёздная оценка (S14)

**Статус:** РЕАЛИЗОВАНО (UI/сцена), звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** звёздное поле, оценка `glorious`, True Name `Lost from Light`, Aspect `Shadow Slave`, Shadow Bond, First Seal.  
**Эмоциональная цель:** благоговение, трансценденция, холодное величие; не «победа», а «тебя увидели».

#### Музыка

- **Стиль:** cosmic sacred / оркестровый эмбиент.
- **Настроение:** «ты стоишь перед чем-то, что больше тебя».
- **BPM/тональность:** 60 BPM, C major / Lydian; медленные такты.
- **Инструменты:** хор, орган, арфа, струнные, стеклянная гармоника, суб-бас, колокол.
- **Аранжировка:** один аккорд C; хор входит слоями; арфа — капли; на True Name — соло-виолончель; на First Seal — удар/тишина.
- **Слои:** `stars` (дрон/хор), `judgment` (орган/струнные), `name` (виолончель), `seal` (удар/тишина).
- **Начало/конец:** начинается с тишины после святилища; заканчивается на финальной карточке/переходе.
- **Тишина:** между строками оценки — 1–2 с; после First Seal — 3–5 с.

#### Референсы

1. **R13, «Detach» (Hans Zimmer, Interstellar).** Почему: космический масштаб, освобождение. Что взять: орган, струнные, тикающий пульс. Как применить: звёздное поле.
2. **R12, «Also Sprach Zarathustra» (Richard Strauss, 2001).** Почему: трансценденция. Что взять: короткий Brass-жест, не полную тему. Как применить: момент `glorious`.
3. **R42, «Death Is the Road to Awe» (Clint Mansell, The Fountain).** Почему: духовный climax. Что взять: струнные, хор. Как применить: True Name.
4. **R44, «An End, Once and for All» (Clint Mansell et al., Mass Effect 3).** Почему: космический финал, меланхолия. Что взять: пианино, струнные, голос. Как применить: Shadow Bond/First Seal.
5. **R05, «Apotheosis» (Austin Wintory, Journey).** Почему: вознесение. Что взять: голос, струнные, арфу. Как применить: финальный свет.

#### Ambience (5–10)

- звёздный «звон»: высокие синусы, очень тихо;
- хоровой дрон;
- органный гул;
- стеклянные капли;
- суб-бас;
- колокол;
- тишина между слоями;
- «дыхание» вселенной — обратный вдох.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| SP_APPRAISAL | Оценка | Хоровой аккорд + звон | S14. |
| SP_TRUE_NAME | True Name | Соло-виолончель + удар | S14. |
| SP_ASPECT | Aspect | Низкий хор + стекло | S14. |
| SP_BOND | Shadow Bond | Суб-бас + цепь | S14. |
| SP_SEAL | First Seal | Удар + тишина | S14. |
| UI_TEXT | Строки | Тихий тик/шёпот | Появление текста. |

#### Голоса

- **Spell:** главный голос сцены; нейтральный, медленный, многослойный; слова — как приговор, но без злобы.
- **Sunny:** нет или только дыхание.
- **ПРЕДЛОЖЕНИЕ:** True Name произносится не Заклятием, а **хором** — много голосов, неразборчиво, но слышно «Lost from Light». Это должно быть страшно и красиво.

#### Общая концепция

Оценка — не экран достижений, а **ритуал**. Музыка должна быть огромной, но не громкой; текст — не «читать», а «слышать». После First Seal — тишина, в которой игрок понимает, что стал чем-то другим.

---

### 4.18. Финал: пробуждение и Flaw (S15)

**Статус:** РЕАЛИЗОВАНО (UI/сцена), звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** пробуждение, Flaw без имени, финальная карточка, `R` → сброс.  
**Эмоциональная цель:** катарсис, опустошение, тихая решимость; «это только начало».

#### Музыка

- **Стиль:** камерный финал / элегия.
- **Настроение:** «ты выжил, но не стал прежним».
- **BPM/тональность:** 50 BPM, E minor → C major; медленно.
- **Инструменты:** пианино, виолончель, струнные, женский голос без слов, мягкий синт.
- **Аранжировка:** пианино — 4-нотный мотив; виолончель — ответ; голос — только в конце; никаких барабанов.
- **Слои:** `awake` (пианино/виолончель), `flaw` (низкий дрон/стекло), `card` (струнные/голос), `silence`.
- **Начало/конец:** начинается после оценки; заканчивается на финальной карточке, с тишиной после.
- **Тишина:** после карточки — 3–5 с; при `R` — резкий вдох/ветер, затем меню.

#### Референсы

1. **R45, «The Departure» (Max Richter, The Leftovers).** Почему: утрата и трансценденция. Что взять: пианино, струнные, голос. Как применить: пробуждение.
2. **R15, «On the Nature of Daylight» (Max Richter, Arrival).** Почему: эмоциональное разрешение. Что взять: струнный секстет, медленную гармонию. Как применить: финальная карточка.
3. **R42, «Together We Will Live Forever» (Clint Mansell, The Fountain).** Почему: элегия, принятие. Что взять: пианино, струнные. Как применить: Flaw.
4. **R46, «Final Voyage» (Andrew Prahlow, Outer Wilds).** Почему: космический финал, горько-сладко. Что взять: акустическую гитару, мягкий синт. Как применить: финальный кадр.
5. **R44, «An End, Once and for All» (Mass Effect 3).** Почему: финал, прощание. Что взять: пианино, струнные. Как применить: карточка.

#### Ambience (5–10)

- пробуждение: резкий вдох, сердцебиение;
- больничный/комнатный гул? Финал абстрактный; используем «пустоту»;
- ветер/пыль;
- стеклянный звон;
- низкий дрон;
- тишина;
- при `R` — звук перезапуска/вдоха.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| SP_AWAKENING | Пробуждение | Вдох + удар сердца + стекло | S15. |
| SP_FLAW | Flaw | Низкий дрон + трещина | S15. |
| ST_FINAL_CARD | Карточка | Тихий удар/хор | S15. |
| ST_RESTART | `R` | Вдох/ветер/перезапуск | S15. |

#### Голоса

- **Spell:** последняя фраза — спокойно, почти нежно; без угрозы.
- **Sunny:** внутренний голос; тихо, с усталой иронией; не «эпический герой».
- **ПРЕДЛОЖЕНИЕ:** Flaw не произносится вслух; только текст. Это усиливает пустоту.

#### Общая концепция

Финал не должен быть «победным». Музыка возвращается к теме Санни, но в другой гармонии: он тот же, но изменился. После карточки — тишина, а не фанфары. `R` — не «рестарт», а новый вдох.

---

### 4.19. Пост-Кошмар: участок, академия, общежитие (8 сцен)

**Статус:** РЕАЛИЗОВАНО как greybox-цепочка; звук — ПРЕДЛОЖЕНИЕ.  
**Сцены:** `police_precinct` → `academy_approach` → `academy_gate` → `academy_campus` → `academy_sleeper_center` → `black_sea_platform` → `tide_descent` → `coral_labyrinth`.  
**Эмоциональная цель:** «нормальный» мир, который не стал домом; бюрократия, зима, академия, сны.

#### Музыка

- **Стиль:** modern dystopian ambient / neoclassical / urban.
- **Настроение:** холодный порядок, одиночество в толпе.
- **BPM/тональность:** 70 BPM, F minor / Dorian; 4/4.
- **Инструменты:** синт-пэд, пианино, струнные, muted trumpet, marimba, field recordings.
- **Аранжировка:** 4-тактовый пэд; пианино — редкие ноты; струнные — только в академии; без больших барабанов.
- **Слои:** `city` (пэд/улица), `academy` (струнные/marimba), `sleeper` (дрон/часы), `sea` (см. 4.20).
- **Переходы:** короткие crossfade 1,5–2,5 с; между академией и сном — 3–4 с, с потерей высоких.

#### Референсы

1. **R17, «Icarus» (Michael McCann, Deus Ex: HR).** Почему: корпоративная антиутопия. Что взять: синт/струнные, холодный пэд. Как применить: участок/академия.
2. **R52, «Introduction» (Solar Fields, Mirror's Edge).** Почему: чистый, холодный город. Что взять: эмбиент, пианино, воздух. Как применить: улица/кампус.
3. **R11, «Nightstalker» (Kenji Kawai, Ghost in the Shell).** Почему: футуристический город, ритуал. Что взять: перкуссию, хор. Как применить: участок/ворота.
4. **R53, «Beneath the Mask» (Shoji Meguro, Persona 5).** Почему: городская ночь, одиночество. Что взять: jazzy/bossa инструментал; использовать в общежитии/кампусе. Как применить: «нормальная» жизнь.
5. **R16, «Main Titles» (Theodore Shapiro, Severance).** Почему: корпоративная стерильность. Что взять: marimba, синт, пустоту. Как применить: Sleeper Center.

#### Ambience по сценам

| Сцена | 5–10 звуков |
|---|---|
| `police_precinct` | флуоресцентный гул; шаги по плитке; радио; двери; бумаги; принтер; лифт; далёкие голоса; металл наручников; гул серверов. |
| `academy_approach` | зимний ветер; снег; автобусная вывеска; машина; шаги; далёкий город; КПП; металл; ткань; дыхание. |
| `academy_gate` | ветер; флаги; снег; ворота; турели; шаги; металл; далёкая толпа; гул купола; птицы? редко. |
| `academy_campus` | снег; шаги; студенты (walla); флаги; стекло; двери; далёкий спортзал; ветер; гул отопления. |
| `academy_sleeper_center` | HVAC; капсулы/мониторы; шаги; двери; шёпот; вода в душе; кровать; часы; далёкий сон; тишина. |
| `black_sea_platform` | см. 4.20. |
| `tide_descent` | см. 4.21. |
| `coral_labyrinth` | см. 4.22. |

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| UI_* | Меню/карта/инвентарь | См. 4.24. | Все UI. |
| PL_WALK_CONCRETE | Шаги | Бетон/плитка | Город/академия. |
| PL_WALK_SNOW | Шаги | Снег | Улица/кампус. |
| ENV_DOOR_METAL | Двери | Металл/стекло | Академия. |
| ST_CHECKPOINT | Чекпоинт | Мягкий колокол/тон | Переходы. |
| ST_SLEEPER_POD | Капсула | Гул/шипение/монитор | Общежитие. |
| ST_GATE | Ворота | Металл/мотор | Академия. |
| ST_TURRET | Турель | Сервопривод | Ворота. |

#### Голоса

- **Sunny:** внутренний голос; усталый, наблюдательный; в академии — более социальный, но всё равно отстранённый.
- **NPC академии:** пока нет реплик в проекте; **ПРЕДЛОЖЕНИЕ** — 5–10 фоновых голосов (студенты, инструкторы, охрана) без сюжетных реплик.
- **ПРЕДЛОЖЕНИЕ:** голос Джулиуса/Касси/Нефис — только после появления сцен и диалогов; не озвучивать маркеры.

#### Общая концепция

Пост-Кошмар должен звучать **чище и холоднее**, чем Кошмар: больше порядка, меньше жизни. Это не «награда», а другой лабиринт — бюрократический. Музыка может быть более мелодичной, но не тёплой. После Кошмара игрок должен почувствовать, что мир людей тоже не безопасен.

---

### 4.20. Чёрное море и платформа-шея (Black Sea)

**Статус:** РЕАЛИЗОВАНО как greybox; звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** Санни на шее колоссальной статуи; чёрная вода без луны и звёзд; голова отсутствует; семь звёзд; меч; вокруг — море.  
**Эмоциональная цель:** одиночество, масштаб, страх глубины; «мир умер, но не до конца».

#### Музыка

- **Стиль:** dark cosmic / drone / одинокий оркестр.
- **Настроение:** безлюдность, вечность, холод.
- **BPM/тональность:** 45 BPM, D minor; без ритма.
- **Инструменты:** суб-бас, низкие струнные, соло-виолончель, далёкий хор, металл, вода.
- **Аранжировка:** один дрон; виолончель — 4-нотная фраза; хор — только на горизонте; никаких барабанов.
- **Слои:** `sea` (суб/вода), `statue` (струнные/металл), `stars` (хор/стекло), `silence`.
- **Начало/конец:** начинается с воды; заканчивается на спуске.
- **Тишина:** 5–10 с между фразами; вода — главный «инструмент».

#### Референсы

1. **R03, «The Farthest Land» (Kow Otani, Shadow of the Colossus).** Почему: одинокий, древний, огромный мир. Что взять: соло-скрипку, низкие струнные, ветер. Как применить: статуя/горизонт.
2. **R41, «Behelit» (Susumu Hirasawa, Berserk).** Почему: dark fantasy, dread. Что взять: голос, синт, перкуссию. Как применить: семь звёзд/меч.
3. **R69, «Elden Ring» (FromSoftware).** Почему: эпическое одиночество. Что взять: низкий хор, струнные; не полную тему. Как применить: масштаб статуи.
4. **R10, «Sea Wall» (Hans Zimmer & Benjamin Wallfisch, Blade Runner 2049).** Почему: монолит, тёмная вода. Что взять: суб-бас, брас. Как применить: чёрная вода.
5. **R66, «The Lighthouse» (Mark Korven).** Почему: изоляция, безумие. Что взять: туманный горн, металл, дрон. Как применить: ночь/вода.

#### Ambience (5–10)

- чёрная вода: лапы, всплески, глубокий гул;
- ветер на высоте;
- камень статуи: скрип, осыпь;
- металл меча/доспеха: редкий звон;
- далёкий морской гул;
- неизвестное существо: низкий выдох/всплеск (редко);
- дождь/морось;
- эхо;
- тишина без птиц/насекомых;
- «звёздный» высокий тон (субъективный).

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| ENV_SEA_LAP | Вода | Медленные лапы, глубокий гул | Постоянно. |
| ENV_SEA_GUST | Ветер | Широкий, солёный | Порывы. |
| ENV_STATUE_GROAN | Статуя | Низкий скрип камня | Редко. |
| ENV_METAL_RING | Металл | Меч/доспех, далёкий | Редко. |
| ST_CHECKPOINT | Чекпоинт | Колокол/тон | Переход. |
| PL_WALK_STONE | Шаги | Мокрый камень | Платформа. |

#### Голоса

- **Sunny:** внутренний голос; тихо, почти шёпот; благоговение/страх.
- **ПРЕДЛОЖЕНИЕ:** голос моря — не слова, а низкий выдох; не объяснять.

#### Общая концепция

Чёрное море — **отсутствие мира**, а не локация. Музыка должна быть минимальной; главное — вода и суб-бас. Статуя — не декорация, а звуковой резонатор: шаги и металл должны отражаться от камня. После шума Кошмара — простор и пустота.

---

### 4.21. Спуск по статуе (Tide Descent)

**Статус:** РЕАЛИЗОВАНО как greybox; звук — ПРЕДЛОЖЕНИЕ.  
**Что происходит:** спуск по рельефу статуи к коралловому лабиринту; мокрый камень, высота, море.  
**Эмоциональная цель:** головокружение, холод, предвкушение; «вниз, в неизвестность».

#### Музыка

- **Стиль:** traversal / dark ambient / low strings.
- **Настроение:** спуск, напряжение, любопытство.
- **BPM/тональность:** 55 BPM, A minor; 4/4.
- **Инструменты:** низкие струнные, водяная перкуссия, хор, суб-бас, металл.
- **Аранжировка:** остинато; вода как ритм; хор — только на горизонте; без мелодии.
- **Слои:** `descent` (струнные/вода), `sea` (суб/ветер), `coral` (намёк на лабиринт), `silence`.
- **Начало/конец:** начинается на платформе; заканчивается на входе в лабиринт.
- **Тишина:** на узких участках — только вода/шаги.

#### Референсы

1. **R03, «The Opened Way» (Kow Otani, Shadow of the Colossus).** Почему: спуск/подъём по колоссу. Что взять: струнные, рог, перкуссию. Как применить: движение по статуе.
2. **R05, «The Road of Trials» (Austin Wintory, Journey).** Почему: traversal, испытание. Что взять: виолончель, арфу. Как применить: спуск.
3. **R47, «The Timefall» (Ludvig Forssell, Death Stranding).** Почему: мокрый, bleak traversal. Что взять: синт, низкие струнные, дождь. Как применить: вода/камень.
4. **R38, «The Descent» (David Julyan, The Descent).** Почему: спуск в темноту. Что взять: дрон, капли, низкие струнные. Как применить: узкие проходы.

#### Ambience (5–10)

- вода: капли, потоки, лапы;
- ветер;
- мокрый камень: шаги, скрип;
- металл статуи: редкий звон;
- далёкое море;
- камнепад;
- дыхание;
- эхо;
- «зов» лабиринта: низкий гул/хор.

#### SFX

| ID | Событие | Концепция | Условие |
|---|---|---|---|
| PL_WALK_WET_STONE | Шаги | Мокрый камень, скольжение | Спуск. |
| ENV_WATER_FLOW | Вода | Поток/капель | Постоянно. |
| ENV_ROCKFALL_SMALL | Камнепад | Осыпь | 1–2 раза. |
| ENV_WIND_GUST | Ветер | Порыв | По погоде. |
| ST_CHECKPOINT | Чекпоинт | Колокол/тон | Переход. |

#### Голоса

- **Sunny:** внутренний голос; короткие фразы, дыхание.
- **ПРЕДЛОЖЕНИЕ:** голос Касси/Нефис — только после реализации сцен; не озвучивать маркеры.

#### Общая концепция

Спуск — это **физическое усилие** и **высота**. Музыка должна поддерживать движение, но не заглушать воду и шаги. К концу — намёк на лабиринт: низкий гул, который станет основой следующей сцены.

---

### 4.22. Старый коралловый лабиринт (sandbox)

**Статус:** РЕАЛИЗОВАНО как sandbox; **не** канонический финальный арт (актуальная сцена — `labyrinth_first_fragment`).  
**Что происходит:** старый лабиринт с shrine/altar/star, не соответствующий текущему канону.  
**Эмоциональная цель:** не тратить ресурсы; использовать как тестовую площадку.

#### Музыка

- **ПРЕДЛОЖЕНИЕ:** не писать отдельный саундтрек. Использовать `coral_labyrinth` cue из Labyrinth First Fragment (4.23) или временную тему.
- **Приоритет:** Low.

#### Ambience

- вода, капли, камень, кости, ветер, шаги;
- shrine/altar: не канон, не добавлять священный хор.

#### SFX

- переиспользовать боевые/шаговые/интерактивные SFX из Labyrinth First Fragment.
- Не добавлять уникальные звуки для shrine/altar/star.

#### Голоса

- Нет; sandbox.

#### Общая концепция

Это **не** локация для финального звука. Все силы — в `labyrinth_first_fragment` и канонические сцены. Если старый лабиринт останется, он должен звучать как ранний прототип, а не как «ещё один храм».

---

### 4.23. Labyrinth First Fragment: 18 зон

**Статус:** РЕАЛИЗОВАНО как standalone greybox-сцена; бой, спутники, Эхо, гроза, HUD прилива — **ЗАПЛАНИРОВАНО/не реализовано**.  
**Сцена:** `scenes/locations/forgotten_shore_labyrinth/labyrinth_first_fragment.tscn`.  
**Масштаб:** ~1,5 км; 18 зон; 3 акта; прилив-прототип 120 с (цель — 16 минут); вход из `tide_descent`; западный выход выключен.

#### 4.23.0. Общая музыкальная архитектура

| Cue | Зоны | Функция | BPM/Key | Слои |
|---|---|---|---|---|
| `LAB_THRESHOLD` | Z01–Z03 | вход, статуя, первый выбор | 48–64, Dm/Gm | statue, wind, first_fight |
| `LAB_EAST` | Z04–Z09 | низина, кости, гряда, прогалина, туннель | 50–70, Cm/Am | mud, bone, ridge, meeting, tunnel |
| `LAB_CAMP` | Z10 | лагерь, хаб | 60, Am | fire, camp, night, danger |
| `LAB_TIDE` | Z11–Z12 | канал, перешеек | 62–66, Dm/Gm | tide_low, tide_high, west |
| `LAB_HUNT` | Z13–Z15 | охота, мост, убежище | 54–78, Em/Dm | hunt, bridge, refuge, echo |
| `LAB_PACK` | Z16 | территория стаи | 84, Em | pack_low, pack_high, dread |
| `LAB_STORM` | Z17–Z18 | гроза, утёсы, финал | 72–100, Dm→C | storm, run, climb, silence |

**Лейтмотивы:**
- **Статуя** — 3 ноты у низкого рога; звучит в Z01, Z07, Z10, Z18.
- **Огонь** — тёплая фраза у виолончели; Z10, Z15, Z18.
- **Охота** — 5-нотный ритм у рамочных барабанов; Z13, Z14, Z16.
- **Гроза** — низкий хор + металл; Z17, Z18.
- **Тень** — не в этой сцене; не добавлять.

**Правило зон:** каждая зона имеет свой **акустический профиль** (открыто/тесно/мокро/сухо/высоко/низко), но музыкальные темы переходят между зонами, чтобы игрок чувствовал единство места.

#### 4.23.1. Матрица зон

| Зона | Роль | Музыка | Ambience (5–9) | Ключевые SFX | Голос | Переход |
|---|---|---|---|---|---|---|
| **Z01 Threshold** | вход, статуя, обучение | `LAB_THRESHOLD`: 48 BPM, Dm; рог + низкие струнные + далёкий хор; только `statue` | ветер у каменной стопы; далёкий прибой; скрип коралла; капли; грязь под ногами; каменный гул; снежная пыль; эхо портала | `PL_WALK_STONE`, `PL_WALK_MUD`, `ENV_WIND_GUST`, `ST_CHECKPOINT`, `ST_AZURE_BLADE` (позже) | Санни: барк при входе | В Z03 — музыка остаётся, добавляется `wind` |
| **Z02 Carcass** | туша, карапаксы, риск | `LAB_EAST`: 58 BPM, Em; низкие струнные + диссонанс; слой `carcass` только рядом с туши | мясо/влажный треск; щелчки карапаксов; панцирь по камню; капли в лужу; ветер; далёкий прибой; кости; жужжание? (осторожно) | `CB_CRAB_CLICK`, `CB_CRAB_SCUTTLE`, `PL_WALK_MUD`, `PL_WALK_WATER`, `ENV_BONE_SETTLE` | Нет людей; карапаксы — щелчки/шипение | В Z01 — музыка уходит, остаётся ветер |
| **Z03 First Fork** | первый бой, развилка | `LAB_THRESHOLD`: 64 BPM, Gm; `first_fight` слой; после боя — `choice` | ветер в лезвиях; кости; грязь; далёкий прибой; капли; карапакс; каменный скрип; эхо | `CB_CRAB_ATTACK`, `CB_CRAB_HIT`, `CB_CRAB_DEATH`, `ST_AZURE_BLADE`, `ST_CHECKPOINT` | Санни: боевые выкрики/барки | В Z04/Z05/Z07 — crossfade 2 с |
| **Z04 Mud Hollow** | быстрый риск, грязь | `LAB_EAST`: 70 BPM, Cm; `mud` слой: низкий пульс + чавканье | чавканье грязи; пузыри; вода; ветер; кости; далёкий карапакс; каменный скрип; капли | `PL_WALK_MUD`, `PL_WALK_WATER`, `ENV_MUD_BUBBLE`, `CB_CRAB_SCUTTLE` | Нет | В Z08 — музыка светлеет, `meeting` |
| **Z05 Bone Passage** | узкий безопасный путь | `LAB_EAST`: 50 BPM, Am; `bone` слой: виолончель/арфа, паузы | капли/эхо; скрип костей; ветер в щели; мокрый камень; шаги; далёкий прибой; дыхание; карапакс в грязи | `PL_WALK_BONE`, `PL_WALK_STONE`, `ENV_BONE_CREAK`, `ENV_BONE_SNAP`, `CB_CRAB_ATTACK` | Санни: шёпот/дыхание | В Z08 — выход света, музыка уходит |
| **Z06 Dry Pocket** | тупик-награда, покой | `LAB_EAST`: 56 BPM, C Lydian; `relief` слой: тёплый пэд + виолончель | ветер; сухие кости; далёкий прибой; камень; кристалл (тон); тишина; шаги | `ST_SOUL_SHARD`, `PL_WALK_BONE`, `ENV_BONE_SETTLE` | Санни: барк | В Z05 — музыка уходит |
| **Z07 Scout Ridge** | панорама, верхний путь | `LAB_THRESHOLD`: 60 BPM, Dm; `ridge` слой: рог + струнные + широкий хор | сильный ветер; свист в лезвиях; далёкий прибой; камнепад; кости; шаги; гроза вдали; дыхание | `ENV_WIND_GUST`, `PL_WALK_STONE`, `PL_JUMP`, `PL_LAND_STONE` | Санни: барк | В Z08 — спуск, музыка стихает |
| **Z08 Clearing** | первая встреча | `LAB_EAST`: 58 BPM, Em→G; `meeting` слой: соло-голос + струнные | ветер; грязь; далёкий костёр; карапаксы; кости; вода; шаги; дыхание | `ST_MEETING`, `PL_WALK_MUD`, `CB_CRAB_CLICK` | **Нефис/Кассия — ЗАПЛАНИРОВАНО**, сейчас маркеры; Санни — барк | В Z10 — `LAB_CAMP` crossfade 3 с |
| **Z09 Blind Tunnel** | тёмный срез | `LAB_EAST`: 40 BPM, D; `tunnel` дрон, почти без музыки | капли/эхо; низкий гул; мокрый камень; дыхание; шаги; далёкий прибой; кристалл; тишина | `PL_WALK_STONE`, `PL_WALK_WATER`, `ENV_WATER_DRIP`, `ST_SOUL_SHARD` | Санни: шёпот | В Z10 — выход к свету/огню |
| **Z10 Coral Hill / Camp** | лагерь, хаб | `LAB_CAMP`: 60 BPM, Am; `fire` + `camp` + `night` + `danger` | костёр; ветер; верёвка; сушащееся мясо; дыхание; далёкий прибой; камень; шаги; ночные звуки | `ENV_FIRE_LOOP`, `ENV_FIRE_POP`, `ST_CHECKPOINT`, `ST_CAMP_INTERACT` | **Нефис/Кассия — ЗАПЛАНИРОВАНО**; Санни — барки | В Z11 — `LAB_TIDE` crossfade 2 с |
| **Z11 Tide Channel** | прилив, шлюз | `LAB_TIDE`: 66 BPM, Dm; `tide_low`/`tide_high`; вода как перкуссия | вода: лапы/поток/брызги; камень; ветер; шлюз; камнепад; коралловые обломки; дыхание | `ENV_WATER_FLOW`, `ENV_WATER_LAP`, `ENV_TIDE_WARNING`, `ENV_TIDE_GATE`, `PL_WALK_WATER` | Нет | В Z12 — вода стихает, `west` |
| **Z12 West Isthmus** | перешеек, выбор низ/верх | `LAB_TIDE`: 62 BPM, Gm; `west` слой: рог + струнные | ветер; далёкая гроза; вода; кости; карапаксы; камень; шаги; дыхание | `PL_WALK_STONE`, `PL_WALK_MUD`, `ENV_WIND_GUST`, `ENV_TIDE_WARNING` | Санни: барк | В Z13 — `LAB_HUNT` crossfade 2 с |
| **Z13 Hunting Grounds** | охота, 3 петли | `LAB_HUNT`: 78 BPM, Em; `hunt` + `stealth` + `combat` | ветер; грязь; кости; карапаксы; далёкий рёв; вода; гнёзда; шаги; дыхание | `CB_CRAB_*`, `PL_WALK_MUD`, `PL_WALK_BONE`, `ENV_BONE_SNAP`, `ST_STEALTH_RUSTLE` | Нет людей; карапаксы | В Z14 — `bridge` слой |
| **Z14 Bone Bridge** | мост, два карапакса, Эхо | `LAB_HUNT`: 70 BPM, Dm; `bridge` + `two_carapace` + `echo` | ветер в рёбрах; скрип костей; вода внизу; шаги по костям; далёкий прибой; карапаксы; эхо | `PL_WALK_BONE`, `ENV_BONE_CREAK`, `ENV_BONE_SNAP`, `CB_CRAB_ATTACK`, `CB_ECHO_CALL` | **Эхо — ЗАПЛАНИРОВАНО** (карапакс, не человеческий голос) | В Z15 — `refuge` crossfade 3 с |
| **Z15 High Refuge** | чекпоинт, обзор | `LAB_HUNT`: 54 BPM, C Lydian; `refuge` слой: соло-скрипка + арфа | ветер; далёкая гроза; кости; сухой коралл; дыхание; камень; шаги; тишина | `ST_CHECKPOINT`, `PL_WALK_STONE`, `ENV_WIND_GUST` | **Кассия — ЗАПЛАНИРОВАНО** (видение); Санни — барк | В Z16 — `LAB_PACK` crossfade 2 с |
| **Z16 Pack Territory** | стая, низкий лабиринт | `LAB_PACK`: 84 BPM, Em; `pack_low`/`pack_high`/`dread` | щелчки; шорох; низкое рычание; кости; грязь; ветер; вода; шаги; дыхание | `CB_CRAB_CLICK`, `CB_CRAB_SCUTTLE`, `CB_CRAB_SCREECH`, `CB_CRAB_ATTACK`, `ST_STEALTH_RUSTLE` | Нет людей; стая | В Z17 — `LAB_STORM` crossfade 1 с, резко |
| **Z17 Storm Run** | гроза, бег | `LAB_STORM`: 100 BPM, Dm; `storm` + `run` + `lightning` | дождь; гром; ветер; вода; камнепад; коралловые обломки; шаги по воде; дыхание | `ENV_RAIN_LOOP`, `ENV_THUNDER`, `ENV_WIND_GUST`, `PL_WALK_WATER`, `PL_BREATH_EXERT`, `ENV_STORM_SURGE` | Санни: усилия/барки | В Z18 — `climb` слой, музыка светлеет |
| **Z18 Cliffs** | финальный подъём | `LAB_STORM`: 72 BPM, Dm→C; `climb` + `silence` | ветер; дождь; гром; море; камнепад; вода; шаги; дыхание; тишина на вершине | `PL_WALK_WET_STONE`, `PL_JUMP`, `PL_LAND_STONE`, `PL_BREATH_EXERT`, `ST_FINAL_LOOK` | Санни; **Нефис/Кассия — ЗАПЛАНИРОВАНО** | Конец фрагмента; тишина/ветер |

#### 4.23.2. Акт I: восточный (Z01–Z11)

**Эмоциональная дуга:** любопытство → первый бой → выбор → встреча → лагерь → первый прилив.

- Музыка начинается с одного рога у статуи; в Z02–Z03 добавляются низкие струнные и ритм; в Z05–Z06 уходит почти полностью; в Z08 возвращается соло-голосом; в Z10 — тёплый лагерь; в Z11 — вода и тревога.
- Ambience восточной части: ветер, прибой, грязь, кости, карапаксы. Чем ближе к лагерю, тем больше огня и человеческих звуков.
- Первый бой в Z03 — **первое настоящее боевое крещендо**; после него — тишина и выбор.
- Встреча в Z08 — **не музыкальный climax**, а тихий человеческий момент; музыка должна уступить голосам.
- Лагерь Z10 — единственная тёплая зона; костёр громче музыки.
- Прилив Z11 — первый «таймер»: звук воды и шлюза должен быть понятен без HUD.

#### 4.23.3. Акт II: центральный (Z12–Z15)

**Эмоциональная дуга:** одиночество → охота → мост → убежище.

- Z12 — переход; музыка разреженная, западный шпиль/гроза вдали.
- Z13 — самая большая зона; музыка должна работать **вертикально**: stealth (низкий пульс), hunt (барабаны), combat (струнные/хор). Не включать всё сразу.
- Z14 — узкое место; музыка сжимается, кости/вода становятся ритмом; появление Эхо — низкий зов, не «босс-тема».
- Z15 — облегчение; соло-скрипка/арфа; тишина после боя; видение Касси (запланировано) — без пафоса.

#### 4.23.4. Акт III: западный (Z16–Z18)

**Эмоциональная дуга:** давление → гроза → подъём → тишина.

- Z16 — самый опасный низкий лабиринт; музыка почти не мелодическая, больше ритм/шёпот; стая звучит как **много маленьких звуков**, а не один рёв.
- Z17 — гроза; музыка и погода работают вместе; гром не должен полностью заглушать шаги/дыхание; темп 100 BPM поддерживает бег.
- Z18 — финал; музыка поднимается с подъёмом, но на вершине **обрывается**; остаётся ветер/море. Не добавлять победный хор.

#### 4.23.5. Голоса лабиринта

| Персонаж | Статус | Голос | Реплики |
|---|---|---|---|
| **Санни** | Реализован (базки/барки) | Тихий, ироничный, усталый; внутренний голос ближе и медленнее | Барки по контексту; сюжетные реплики — после реализации диалогов. |
| **Нефис** | ЗАПЛАНИРОВАНО (маркер) | Спокойный, regal, дистанция; средний-низкий женский; не «ледяная стерва», а человек, который держит себя в руках | Пока нет `.tres`; не озвучивать маркер. |
| **Кассия** | ЗАПЛАНИРОВАНО (маркер) | Мягкий, слегка надломленный; моложе; говорит с паузами, часто улыбается голосом | Пока нет `.tres`; не озвучивать маркер. |
| **Эхо** | ЗАПЛАНИРОВАНО (маркер) | Не человеческий голос: низкие щелчки, вибрация панциря, свист; иногда похоже на «мурлыканье» | Нет слов. |
| **Карапаксы/стая** | Реализованы только placeholder-меши | Щелчки, скрежет, шипение, низкое рычание; без слов | — |

**Важно:** не добавлять реплики Нефис/Кассии/Эхо до появления их сцен и диалогов. AUDIO может быть готов, но контент — нет.

#### 4.23.6. Общая концепция лабиринта

Лабиринт — это **живой риф**, а не «подземелье». Он должен звучать как место, где вода, камень и кости продолжают жить без людей. Музыка — редкий гость; её главная задача — отмечать **масштаб** (статуя, море, гроза) и **присутствие** (люди, стая, Эхо). Тишина и ветер — основа. Прилив и гроза — два главных «дирижёра»: они меняют не только громкость, но и тембр (фильтрация, reverb, плотность).

---

### 4.24. Море Души, меню, карта, RPG-интерфейс

**Статус:** РЕАЛИЗОВАНО (сцены/UI), звук — ПРЕДЛОЖЕНИЕ.

#### Море Души

- **Музыка:** без BPM; дрон D, обратное пианино, стеклянные капли, сердцебиение; 2 слоя (`soul_sea`, `memory`). Без хора/эпика.
- **Ambience:** вода, эхо, шёпот без слов, звёздный звон, дыхание, тишина.
- **SFX:** вход/выход, выбор воспоминания (стеклянный тон), подтверждение, ошибка.
- **Голос:** Санни — внутренний, тихо; возможно, эхо чужих голосов без слов.
- **Референсы:** R12 «Requiem» (Ligeti), R05 «Nascence» (Journey), R42 «Together We Will Live Forever» (The Fountain), R46 «Timber Hearth» (Outer Wilds).

#### Главное меню

- См. 4.1. Музыка продолжается; UI-звуки — см. 4.1.
- **Правило:** меню не должно быть громче игры; при возврате из игры — fade 1,5 с.

#### Карта

- **Ambience:** шорох бумаги/ткани, тихий ветер, далёкий гул; без музыки или с низким пэдом.
- **SFX:** открытие/закрытие (бумага/дерево), перемещение по карте (тихий шаг/скрип), выбор маркера (стеклянный тик), приближение/отдаление (мягкий whoosh), ошибка (сухой тон).
- **Голос:** нет.

#### RPG-меню (инвентарь, персонаж, аспекты, навыки, квесты, торговля)

- **Музыка:** низкий пэд/пианино, очень тихо; не отвлекать.
- **SFX:** hover/click/back/tab/slider/toggle/equip/unequip/pickup/drop/quest_update/skill_unlock/error.
- **Голос:** нет; текст.
- **Правило:** UI-звуки короткие (<150 мс), тихие, без «писка»; не повторять при каждом кадре слайдера.

#### Диалоги/субтитры

- **Голос:** 2D, сухой, без реверба; громкость Voice.
- **Музыка:** ducking −6…−9 dB; ambience −3 dB.
- **SFX:** тик появления строки (очень тихо), подтверждение «далее» (мягкий), закрытие (выдох).
- **Субтитры:** синхронизированы с voice; важные неречевые звуки — sound captions (см. 7.6).

---

### 4.25. Sandbox/dev-арены

**Статус:** РЕАЛИЗОВАНО, вне канона.  
**Сцены:** `main.tscn`, `combat_arena.tscn`, `larva_arena.tscn`, `test_level.tscn`, `caravan_ambush.tscn`, `ambush_site_demo.tscn`.

- **Музыка:** не писать отдельную; использовать боевые/караванные cue как temp.
- **Ambience:** переиспользовать ближайшую каноническую зону; не тратить время на уникальный soundscape.
- **SFX:** те же боевые/шаговые/UI; sandbox — удобная площадка для проверки приоритетов и полифонии.
- **Голоса:** только существующие; не озвучивать sandbox-манекены.
- **Приоритет:** Low. Не позволять sandbox-контенту диктовать архитектуру.

---

## 5. Сводная таблица музыкальных референсов по локациям

> Это быстрый производственный индекс. Подробные объяснения — в §4. Ссылки — в §3.7. Для каждой локации указаны конкретные треки, а не только произведения.

| Локация | Референсы (конкретные треки) | Что берём | Как применяем |
|---|---|---|---|
| **Главное меню** | R01 «Instrument of Surrender»; R02 «The Last of Us»; R03 «Prologue ~To the Ancient Land~»; R04 «The Night Unfurls»; R46 «Timber Hearth» | Усталая виолончель, интимное пианино, древний низ, готическое предчувствие, тёплая камерность | Основа темы Санни; слои `base`/`press`/`glitch`; без барабанов. |
| **Парк/улица** | R01 «Whirling-In-Rags, 8 AM»; R17 «Icarus»; R10 «2049»; R11 «Nightstalker»; R16 «Main Titles» | Ленивый городской грув, холодный synth, суб-бас мегаполиса, ритуальная перкуссия, корпоративная стерильность | Пианино/бас/щётки; synth-пэд при взгляде на город; без эпика. |
| **Лобби участка** | R16 «Main Titles»/«The Macrodata Refinement Team»; R07 «The Beast»; R08 «Pump Room»; R01 «Precinct 41 Major Crime Unit»; R18 «Main Title» | Стерильный пульс, процедурный гул, бетон, полицейская усталость, холодная тревога | Маримба/пианино + HVAC; Code Black — слой сирены/струнных. |
| **Изолятор** | R08 «Pump Room»; R09 «The Alien»; R18 «Main Title»; R16 «The Break Room»; R43 «Lux Aeterna» | Промышленный гул, органическое дыхание, клинический ужас, институциональное принуждение, нарастающий звон | Дрон A + сердцебиение + tinnitus; без мелодии; обрыв в тишину. |
| **Пустота Заклятия** | R12 «Requiem»/«Lux Aeterna»; R13 «Mountains»; R14 «Paul's Dream»; R05 «Nascence» | Хор как материя, орган/тиканье, ритуал/пророчество, духовная интимность | Один аккорд D; хор слоями; стеклянный тон; без ритма. |
| **Горное видение** | R03 «Prologue»; R13 «Mountains»; R14 «Paul's Dream»; R21 «The Ring Goes South»; R15 «On the Nature of Daylight» | Древний масштаб, время, пророчество, поход через горы, струнная печаль | Рог/струнные/хор; барабан только на кульминации; обрыв. |
| **Марш каравана** | R06 «The Revenant Main Theme»; R22 «The Riders of Doom»; R21 «The Ring Goes South»; R30 «The City Must Survive»; R29 «The Grey» | Холод/выживание, древний караван, поход, grim march, безнадёжность | Цепь 3+3+2 как ритм; виолончель/бас-флейта; Ауро — светлый мотив. |
| **Лагерь** | R02 «The Choice»; R31 «That's the Way It Is»; R32 «The Camp»; R33 «Sleeping»; R34 «The Green Mile» | Хрупкое тепло, лагерная элегия, убежище, средневековая тишина, милосердие | Гитара/виолончель/флейта; костёр громче музыки; ночь — дрон/голос. |
| **Нападение/личинка** | R25 «The Stranger»; R04 «Cleric Beast»; R03 «A Violent Encounter»; R27 «Kaiju»; R26 «BFG Division» | Brutal percussion, монстр/хор, гигант/трагедия, kaiju-суб, industrial chaos | Ударные слои; хор только на Тиране; личинка — высокие струнные/щелчки. |
| **Повозка** | R06 «Killing Hawk»; R23 «The Chase»; R21 «The Uruk-hai»; R24 «Brothers in Arms»; R22 «Battle of the Mounds» | Физическое напряжение, tribal chase, siege/choir, mechanical chaos, ancient battle | Анвил/струнные/хор; кульминация — падение; после — тишина. |
| **Последствия/ночь/рассвет** | R02 «All Gone (No Escape)»; R31 «That's the Way It Is»; R36 «Song for Jesse»; R37 «The Road»; R45 «The Departure» | Горе/пустота, лагерная элегия, траурный пейзаж, опустошение, утрата/трансценденция | Виолончель/пианино; после смерти ветерана — тишина; рассвет без фанфар. |
| **Дорога/подъём** | R21 «The Ring Goes South»; R40 «Gabriel's Oboe»; R05 «The Road of Trials»; R30 «We Are All Guests Upon the Land»; R06 «The Revenant Main Theme» | Поход/холод, духовное восхождение, паломничество, северная меланхолия, выживание | Бас-флейта/виолончель/барабан; храм — далёкий хор. |
| **Альков/рассвет** | R02 «Vanishing Grace»; R37 «The Boy»; R05 «Pi's Lullaby»; R06 «Goodbye to Hawk»; R55 «Sweden» | Тихое горе, хрупкость, рассвет/колыбельная, смерть/отпускание, горько-сладкая простота | Шкатулка/виолончель; после смерти Шифти — почти тишина. |
| **Учёный/пещера** | R38 «The Descent»; R39 «Sub-Level»; R19 «Humanity Part II»; R20 «Love»; R08 «Pump Room» | Клаустрофобия, industrial tension, паранойя, alien/телесность, бетон | Prepared piano/бас-кларнет/капли; без гармонической опоры. |
| **Смерть Героя/храм** | R21 «The Bridge of Khazad-dûm»; R04 «Father Gascoigne»; R03 «The End of the Battle»; R41 «Guts»; R40 «Long, Long Time Ago» | Жертва/хор, трагическая охота, трагическая победа, человеческая боль, тёмная сказка | Хор/брас/колокол; после смерти — ветер/колокол; порог — тишина. |
| **Святилище** | R04 «Ebrietas»; R70 «Soul of Cinder»; R69 «Godskin Apostles»; R12 «Requiem»; R43 «Lux Aeterna»; R42 «Death Is the Road to Awe» | Священный ужас, элегия, ритуал, космическая пустота, нарастающий ужас, трансценденция | Низкий хор/орган/стекло; Тиран — пульс; тени — обратный хор; после — тишина. |
| **Оценка** | R13 «Detach»; R12 «Also Sprach Zarathustra»; R42 «Death Is the Road to Awe»; R44 «An End, Once and for All»; R05 «Apotheosis» | Космический масштаб, трансценденция, духовный climax, финальная меланхолия, вознесение | Хор/орган/арфа; True Name — соло-виолончель; First Seal — удар/тишина. |
| **Финал** | R45 «The Departure»; R15 «On the Nature of Daylight»; R42 «Together We Will Live Forever»; R46 «Final Voyage»; R44 «An End, Once and for All» | Утрата/трансценденция, разрешение, элегия/принятие, космический финал, прощание | Пианино/виолончель/струнные; без фанфар; после карточки — тишина. |
| **Пост-Кошмар: город/академия** | R17 «Icarus»; R52 «Introduction»; R11 «Nightstalker»; R53 «Beneath the Mask»; R16 «Main Titles» | Корпоративная антиутопия, холодный город, футуристический ритуал, городская ночь, стерильность | Synth-пэд/пианино/струнные; Sleeper Center — marimba/часы. |
| **Чёрное море** | R03 «The Farthest Land»; R41 «Behelit»; R69 «Elden Ring»; R10 «Sea Wall»; R66 «The Lighthouse» | Одиночество/древность, dark fantasy, эпическое одиночество, монолит/вода, изоляция/безумие | Суб-бас/виолончель/далёкий хор; вода — главный инструмент. |
| **Спуск по статуе** | R03 «The Opened Way»; R05 «The Road of Trials»; R47 «The Timefall»; R38 «The Descent» | Спуск/колосс, traversal, мокрый bleak, спуск в темноту | Низкие струнные/водяная перкуссия; без мелодии. |
| **Старый коралловый лабиринт** | R48 «Abandon Ship»; R49 «The Abyss»; R09 «The Alien»; R04 «The Hunter»; R50 «Aquis» | Alien ocean, underwater awe, alien ecology, hunt, ancient/tribal | Не писать отдельно; использовать cue лабиринта; Low priority. |
| **Labyrinth First Fragment** | R48 «Abandon Ship»; R03 «The Farthest Land»; R04 «The Hunter»; R49 «The Abyss»; R09 «The Alien» | Alien reef, monumental solitude, hunt, underwater awe, alien ecology | 5 core cues + 18 zone layers; см. §4.23. |
| **Море Души/UI** | R12 «Requiem»; R05 «Nascence»; R42 «Together We Will Live Forever»; R46 «Timber Hearth» | Космическая пустота, духовная интимность, элегия, тёплая камерность | Дрон/обратное пианино/стекло; UI — короткие тихие звуки. |

---

## 6. Сводная таблица звуков окружения по локациям

> 5–10 конкретных примеров на локацию. Для каждой строки указан характер звучания и назначение. Это не готовые ассеты, а ТЗ на запись/генерацию.

| Локация | Звуки окружения |
|---|---|
| **Главное меню** | комнатный гул; далёкий ветер; суб-бас; редкий стеклянный звон; металлический скрип цепи; шорох бумаги; гул экрана; хор на «м»; далёкий колокол при бездействии. |
| **Парк/улица** | городской гул; ветер в кронах; шаги прохожих; walla без слов; велосипедный звонок; гул вывески; скрип скамейки; шелест стаканчика; далёкая сирена; приглушённая музыка станции. |
| **Лобби участка** | флуоресцентный гул; вентиляция; вентиляторы терминалов; принтер; шаги по плитке; далёкие двери/лифт; радио без слов; тест сирены; сервопривод турели; стекло/пластик. |
| **Изолятор** | HVAC 55/120 Гц; поток воздуха; реле терминала; фиксатор кресла; натяжение ремня; сервопривод; замок двери; шаги за дверью; далёкое радио; звон в ушах; дыхание. |
| **Пустота Заклятия** | низкий дрон; высокий синус; хоровые кластеры; обратное дыхание; стеклянный звон; далёкий горный ветер; медленное сердцебиение; треск реальности; тишина. |
| **Горное видение** | высокий ветер; далёкий камнепад; снежная пыль; горный гул; далёкая цепь/бубенцы; храмовый гул; редкий крик птицы; треск льда; обрыв. |
| **Марш каравана** | ветер в скалах; снег; цепь 3+3+2; дыхание; копыта; кожа седла; камнепад; треск льда; снежная пыль у обрыва; далёкий бубен. |
| **Лагерь** | костёр; ветер в ткани; лошади; цепь; далёкий камнепад; котелок; кожа/ремни; дыхание спящих; ночной камень; шаги по снегу. |
| **Нападение/личинка** | камни/лёд; рёв/шаги Тирана; земля/снег; треск повозки; цепь; крики; снежная пыль; щелчки личинки; сердцебиение; тишина после. |
| **Повозка** | дерево; металл клиньев; колесо; камни/снег; дыхание; команды; Тиран; ветер/пыль; удар/эхо; тишина. |
| **Последствия/ночь/рассвет** | угли; ветер; дыхание/храп; цепь; камнепад; ночной камень; фляги; яд; капель; шаги по замёрзшей земле. |
| **Дорога/подъём** | ветер; снег/лёд; треск; камнепад; далёкий Тиран; птица; вода; камень; дыхание; колокол; храм. |
| **Альков/рассвет** | ветер; капель; тающий снег; дыхание Шифти; ткань; камнепад; утренняя птица; храм; тишина. |
| **Учёный/пещера** | капли/эхо; низкий гул; влажный камень; дыхание; металл; вода; камнепад; ткань; сердцебиение; тишина. |
| **Смерть Героя/храм** | ветер; снег; колокол; Тиран; храм; страж; шаги; дыхание; камнепад; тишина. |
| **Святилище** | ветер в проломах; снег/лёд; камень; эхо; ткань; алтарь; тени; Тиран; капли; тишина. |
| **Оценка** | звёздный звон; хоровой дрон; орган; стекло; суб-бас; колокол; тишина; обратный вдох. |
| **Финал** | вдох; сердцебиение; ветер/пыль; стекло; дрон; тишина; перезапуск. |
| **Пост-Кошмар: город/академия** | флуоресцентный гул; шаги; радио; двери; бумаги; принтер; лифт; голоса; наручники; серверы; зимний ветер; снег; флаги; турели; капсулы; мониторы; душ; часы. |
| **Чёрное море** | вода; ветер; камень статуи; металл; далёкий морской гул; неизвестное существо; дождь; эхо; тишина; звёздный тон. |
| **Спуск по статуе** | вода; ветер; мокрый камень; металл; море; камнепад; дыхание; эхо; зов лабиринта. |
| **Старый коралловый лабиринт** | вода; капли; камень; кости; ветер; шаги; (не добавлять shrine/altar). |
| **Labyrinth First Fragment** | см. §4.23.1: ветер, прибой, грязь, кости, карапаксы, огонь, вода, гроза, дождь, гром. |
| **Море Души/UI** | вода; эхо; шёпот; звёздный звон; дыхание; бумага; тихие UI-тики. |
| **Sandbox** | переиспользовать ближайшую каноническую зону; не делать уникальный soundscape. |

---

## 7. Каталог SFX

> **Важно:** каталог покрывает только существующие или явно запланированные механики. В игре **нет** лазания, плавания, управляемой тени, активных заклинаний, стрельбы, транспорта, верховой езды игрока, стелс-убийств и компаньонского AI. Для них звуки не проектируются.
>
> Боевые SFX нужны для существующего боевого прототипа и будущего Лабиринта; в канонических сценах Первого Кошмара бой может быть постановочным.

### 7.1. Передвижение и поверхности

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие/референс |
|---|---|---|---|---|---|---|
| `PL_WALK_SNOW_PACKED` | Шаг по утоптанному снегу | Скрип, мягкий удар, лёгкий хруст | 6–8 | 2D (игрок) | Medium | Скорость < sprint; R06/R29. |
| `PL_WALK_SNOW_SOFT` | Шаг по рыхлому снегу | Глубокий, глухой, с провалом | 6–8 | 2D | Medium | Сугробы; R06. |
| `PL_WALK_ICE` | Шаг по льду | Осторожный, с проскальзыванием | 5–6 | 2D | Medium | Ледяные пятна; R06/R29. |
| `PL_WALK_STONE` | Шаг по камню | Сухой, короткий, с эхом | 6–8 | 2D | Medium | Мостовая/скала; R03. |
| `PL_WALK_WET_STONE` | Шаг по мокрому камню | Влажный, с лёгким чавканьем | 5–6 | 2D | Medium | Дождь/прилив; R47. |
| `PL_WALK_MUD` | Шаг по грязи | Чавканье, вязкость, пузыри | 6–8 | 2D | Medium | Z04/Z08/Z13; R48. |
| `PL_WALK_WATER` | Шаг по мелководью | Всплеск, вода, камень | 5–6 | 2D | Medium | Прилив/лужи; R48. |
| `PL_WALK_BONE` | Шаг по костям | Сухой треск, хрупкость | 6–8 | 2D | Medium | Z05/Z14; R03/R04. |
| `PL_WALK_WOOD` | Шаг по дереву | Скрип, полый стук | 4–6 | 2D | Medium | Повозка/помост; R31. |
| `PL_WALK_METAL` | Шаг по металлу | Гулкий, с лязгом | 4–6 | 2D | Medium | Станция/клетка; R18. |
| `PL_WALK_MARBLE` | Шаг по мрамору | Чистый, звонкий, с большим ревербом | 4–6 | 2D | Medium | Святилище; R04/R70. |
| `PL_WALK_CONCRETE` | Шаг по бетону | Плотный, с коротким эхом | 6–8 | 2D | Medium | Бункер/академия; R08. |
| `PL_WALK_TILE` | Шаг по плитке | Чистый, звонкий | 4–6 | 2D | Medium | Лобби/станция; R01. |
| `PL_WALK_ASPHALT` | Шаг по асфальту | Сухой, с песком | 6–8 | 2D | Medium | Улица; R01. |
| `PL_WALK_GRAVEL` | Шаг по гравию | Мелкий хруст, осыпь | 4–6 | 2D | Low | Двор/осыпь. |
| `PL_WALK_CORAL` | Шаг по кораллу | Хрупкий, пористый, с треском | 5–6 | 2D | Medium | Лабиринт; R48. |
| `PL_RUN_<surface>` | Бег | Те же поверхности, громче, чаще, с дыханием | 4–6 на поверхность | 2D | High | Sprint; отдельный набор, не pitch-шифт шага. |
| `PL_JUMP` | Прыжок | Вдох, ткань, отрыв | 3–4 | 2D | High | Jump; не «мультяшный». |
| `PL_LAND_<surface>` | Приземление | Удар, ткань, камень/снег | 4–6 на поверхность | 2D | High | Land; громкость от высоты. |
| `PL_LAND_STONE` | Приземление на камень | Плотный удар + осыпь | 4 | 2D | High | Z07/Z18. |
| `PL_FALL` | Падение | Ветер, ткань, дыхание | 2–3 | 2D | High | FallRecovery. |
| `PL_DODGE` | Уклонение | Ткань, шаг, короткий whoosh | 3–4 | 2D | High | CombatController; R04. |
| `PL_BLOCK` | Блок | Кожа/металл, короткий | 3–4 | 2D | High | Block; отдельно armed/unarmed. |
| `PL_HIT` | Получение урона | Удар, вдох, ткань | 4–6 | 2D | High | Hurtbox; R25. |
| `PL_DEATH` | Смерть | Выдох, падение, тишина | 2–3 | 2D | Critical | Health.died; без «киношного» стона. |
| `PL_CHAIN_STEP` | Цепь в шаге | Металл 3+3+2, трение | 4–6 | 2D | High | Caravan; R06/R22. |
| `PL_CHAIN_TENSION` | Натяжение цепи | Металл/кожа, короткий | 3 | 2D | High | Остановка колонны. |
| `PL_RESTRAINED_IDLE` | Ремни кресла | Кожа/металл, тихо | 2–3 | 2D | Medium | Containment. |
| `PL_SIT` | Сесть | Скрип, ткань, выдох | 3 | 2D | Medium | Bench/bedroll. |
| `PL_STAND` | Встать | Скрип, шаг, вдох | 3 | 2D | Medium | Bench. |
| `PL_DRINK` | Питьё | Керамика/металл, глоток, выдох | 3 | 2D | Medium | Coffee/flask. |
| `PL_THROW_CUP` | Бросок стаканчика | Бумага/пластик, свист, удар | 2–3 | 3D | Medium | B05. |
| `PL_LIE_DOWN` | Лечь на алтарь | Ткань, камень, выдох | 2 | 3D | Critical | S13. |
| `PL_COUGH_BLOOD` | Кровавая пена | Сдавленный кашель, влага, выдох | 2–3 | 2D | Critical | S13; не «смаковать». |

### 7.2. Бой

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие/референс |
|---|---|---|---|---|---|---|
| `CB_SWING_ARMED` | Замах оружием | Свист металла/кожи, короткий | 4–6 | 3D | High | MeleeAttack; R04. |
| `CB_SWING_UNARMED` | Замах кулаком | Свист ткани/воздуха | 4–6 | 3D | High | Unarmed; R25. |
| `CB_HIT_FLESH` | Попадание по плоти | Глухой удар, влага | 6–8 | 3D | High | Hurtbox; R25. |
| `CB_HIT_BONE` | Попадание по кости | Сухой треск, твёрдый | 4–6 | 3D | High | Skeleton/carapace; R03. |
| `CB_HIT_CARAPACE` | Попадание по панцирю | Твёрдый щелчок, скребок | 4–6 | 3D | High | Crabs; R48. |
| `CB_HIT_ARMOR` | Попадание по броне | Металл, звон, короткий | 4–6 | 3D | High | Soldiers; R22. |
| `CB_BLOCK_METAL` | Блок металлом | Лязг, трение, отдача | 4 | 3D | High | Armed block; R04. |
| `CB_BLOCK_LEATHER` | Блок кожей | Глухой удар, скрип | 4 | 3D | High | Unarmed block; R25. |
| `CB_GUARD_BREAK` | Пробитие блока | Треск, вдох, металл | 2–3 | 3D | High | Guard broken. |
| `CB_DODGE_WHOOSH` | Уклонение | Ткань/воздух, короткий | 3 | 3D | High | Dodge. |
| `CB_CRITICAL` | Критический удар | Акцент: низкий удар + высокий звон | 2 | 3D | Critical | Если механика crit есть; иначе не добавлять. |

### 7.3. Враги и существа

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие/референс |
|---|---|---|---|---|---|---|
| `CB_LARVA_WRITHE` | Личинка шевелится | Влажные щелчки, трение, дрожь | 4 | 3D | High | Larva; R09/R18. |
| `CB_LARVA_SCREECH` | Визг личинки | Высокий, короткий, «мокрый» | 3 | 3D | High | Attack; не «птица». |
| `CB_LARVA_BITE` | Укус | Щелчок, влага, рывок | 3 | 3D | High | Attack. |
| `CB_LARVA_DEATH` | Смерть личинки | Сжатие, влага, обрыв | 2 | 3D | High | Death. |
| `CB_TYRANT_BREATH` | Дыхание Тирана | Низкое, с суб-гармониками, медленное | 3 | 3D | High | Dormant/approach; R25/R27. |
| `CB_TYRANT_ROAR` | Рёв | Низкий, долгий, с металлом | 2–3 | 3D | Critical | Появление/атака; R04/R27. |
| `CB_TYRANT_STEP` | Шаг | Глухой удар, дрожь земли | 4 | 3D | High | Movement; R27. |
| `CB_TYRANT_SWIPE` | Удар лапой | Свист, удар, треск | 3 | 3D | Critical | Attack; R25. |
| `CB_TYRANT_LAND` | Приземление | Огромный удар, осыпь, суб | 2 | 3D | Critical | S03; R27. |
| `CB_TYRANT_DEATH` | Смерть | Долгий выдох, обвал, тишина | 1 | 3D | Critical | S13; R03/R42. |
| `CB_CRAB_CLICK` | Карапакс: щелчки | Хитиновые щелчки, сухие | 6–8 | 3D | Medium | Z02/Z13; R48. |
| `CB_CRAB_SCUTTLE` | Карапакс: бег | Быстрые щелчки/скребок | 5–6 | 3D | Medium | Z13/Z16; R48. |
| `CB_CRAB_SCREECH` | Карапакс: крик | Высокий, скрежещущий | 3–4 | 3D | High | Pack; R48. |
| `CB_CRAB_ATTACK` | Карапакс: атака | Рывок, щелчок, удар | 4 | 3D | High | Combat. |
| `CB_CRAB_HIT` | Карапакс: попадание | Панцирь, треск | 4 | 3D | High | Combat. |
| `CB_CRAB_DEATH` | Карапакс: смерть | Треск, лазурная кровь, обрыв | 3 | 3D | High | Combat. |
| `CB_ECHO_CALL` | Эхо: зов | Низкий вибрирующий зов, не человеческий | 2 | 3D | Critical | Z14; **ЗАПЛАНИРОВАНО**. |
| `CB_ECHO_MOVE` | Эхо: движение | Тяжёлые шаги, вибрация панциря | 3 | 3D | High | **ЗАПЛАНИРОВАНО**. |

### 7.4. Интерактивные объекты и предметы

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие/референс |
|---|---|---|---|---|---|---|
| `ST_INTERACT` | Взаимодействие | Мягкий тик/подтверждение | 2 | 2D | High | Interactable. |
| `ST_PICKUP` | Подбор | Ткань/металл/бумага | 3–4 | 3D | High | Item. |
| `ST_INSPECT` | Осмотр | Шорох, тихий тон | 2 | 2D | Medium | Inspectable. |
| `ST_KEY` | Ключ | Металл, зубцы, короткий | 2 | 3D | High | S02. |
| `ST_UNLOCK` | Замок | Металл, щелчок, цепь | 2 | 3D | High | S02. |
| `ST_DOOR_STONE` | Каменная дверь | Тяжёлый скрип/трение | 2 | 3D | High | S12; существующий CC BY файл. |
| `ST_DOOR_METAL` | Металлическая дверь | Лязг, шипение, замок | 3 | 3D | High | Station/academy. |
| `ST_TERMINAL` | Терминал | Реле, писк, экран | 3 | 2D/3D | Medium | Lobby/containment. |
| `ST_LEVER` | Рычаг | Металл, пружина, щелчок | 2 | 3D | Medium | Если есть; иначе не добавлять. |
| `ST_FLASK` | Фляга | Металл/пробка/вода | 3 | 3D | Medium | S02/S06. |
| `ST_RATIONS` | Еда | Ткань/дерево/металл | 2 | 3D | Medium | S02. |
| `ST_CAMPFIRE` | Костёр | Потрескивание/поп | 3 | 3D | High | S02/S06/Z10. |
| `ST_CAMP_INTERACT` | Лагерь: взаимодействие | Огонь/ткань/металл | 3 | 3D | Medium | Z10. |
| `ST_BELL_OBTAIN` | Silver Bell | Чистый маленький колокол | 1 | 2D | Critical | S06. |
| `ST_BELL_RING` | Звон | Чистый, долгий, один | 1 | 2D | Critical | S11. |
| `ST_ALTAR` | Алтарь | Камень, впитывание, тишина | 2 | 3D | Critical | S13. |
| `ST_SOUL_SHARD` | Кристалл души | Стеклянный тон, короткий | 2 | 3D | Medium | Z06/Z09. |
| `ST_AZURE_BLADE` | Azure Blade | Металл + низкий гул/стекло | 1 | 3D | Critical | Z03; **ЗАПЛАНИРОВАНО**. |
| `ST_MEETING` | Первая встреча | Тихий колокол/струнный harmonic | 1 | 2D | Critical | Z08; **ЗАПЛАНИРОВАНО**. |
| `ST_CHECKPOINT` | Чекпоинт | Мягкий колокол/тон | 1 | 2D | High | Z01/Z10/Z15/Z18. |
| `ST_FINAL_LOOK` | Финальный вид | Ветер + один низкий удар | 1 | 2D | High | Z18. |
| `ST_SILENCE` | Принудительная тишина | 2–8 с без музыки, только ambience | 1 | 2D | Critical | После крупных событий. |
| `ST_STEALTH_RUSTLE` | Скрытность | Шорох ткани/шагов, тихо | 3 | 2D | Medium | Если стелс появится; иначе не добавлять. |

### 7.5. UI

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие |
|---|---|---|---|---|---|---|
| `UI_HOVER` | Наведение | Мягкий тик, −24 dB | 2 | 2D | Medium | Не повторять при движении внутри. |
| `UI_CLICK` | Клик | Дерево/камень + тон | 2 | 2D | High | Все кнопки. |
| `UI_BACK` | Назад | Обратный тик | 1 | 2D | Medium | Escape/назад. |
| `UI_TAB` | Вкладка | Бумага + тон | 2 | 2D | Medium | Настройки. |
| `UI_SLIDER` | Ползунок | Тихий шаг, без писка | 1 | 2D | Low | Не на каждый пиксель. |
| `UI_TOGGLE` | Переключатель | Дерево/металл, короткий | 2 | 2D | Medium | Checkbox. |
| `UI_ERROR` | Ошибка | Сухой низкий тон | 1 | 2D | High | Недоступно. |
| `UI_CONFIRM` | Подтверждение | Мягкий колокол/тон | 1 | 2D | High | ОК/применить. |
| `UI_OPEN_MAP` | Карта | Бумага/ткань | 1 | 2D | Medium | M. |
| `UI_CLOSE_MAP` | Закрыть карту | Бумага/выдох | 1 | 2D | Medium | Escape/M. |
| `UI_QUEST_UPDATE` | Обновление цели | Тихий колокол/тон | 1 | 2D | High | Objective. |
| `UI_ITEM_PICKUP` | Предмет | Ткань/металл/стекло | 3 | 2D | High | Inventory. |
| `UI_ITEM_EQUIP` | Экипировка | Металл/кожа | 3 | 2D | Medium | RPG menu. |
| `UI_SKILL_UNLOCK` | Навык | Стеклянный тон/хор | 1 | 2D | Medium | Если есть. |

### 7.6. Заклятие, сюжет и кат-сцены

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие/референс |
|---|---|---|---|---|---|---|
| `SP_GREETING` | Приветствие Заклятия | Хоровой аккорд + стекло | 1 | 2D | Critical | B13/B15; R12. |
| `SP_MESSAGE` | Строка Заклятия | Тик/шёпот | 2 | 2D | High | Spell UI. |
| `SP_RUNE` | Руны | Низкий хор + стекло | 2 | 2D | High | B16. |
| `SP_MARK` | Mark of Divinity | Один чистый тон | 1 | 2D | High | B16. |
| `SP_APPRAISAL` | Оценка | Хор + звон | 1 | 2D | Critical | S14. |
| `SP_TRUE_NAME` | True Name | Соло-виолончель + удар | 1 | 2D | Critical | S14. |
| `SP_ASPECT` | Aspect | Низкий хор + стекло | 1 | 2D | Critical | S14. |
| `SP_BOND` | Shadow Bond | Суб-бас + цепь | 1 | 2D | Critical | S14. |
| `SP_SEAL` | First Seal | Удар + тишина | 1 | 2D | Critical | S14. |
| `SP_AWAKENING` | Пробуждение | Вдох + сердце + стекло | 1 | 2D | Critical | S15. |
| `SP_FLAW` | Flaw | Дрон + трещина | 1 | 2D | Critical | S15. |
| `ST_CODE_BLACK` | Code Black | Сирена + гул + ставни | 1 | 2D | Critical | B09. |
| `ST_TURRET` | Турель | Сервопривод + лязг + заряд | 2 | 3D | High | B09. |
| `ST_RESTRAIN` | Фиксация | Металл + ткань + замок | 2 | 3D | Critical | B10. |
| `ST_DROWSINESS` | Сонливость | Высокий звон + приглушение | 1 | 2D | Critical | B12. |
| `ST_VOID_IMPACT` | Вход в пустоту | Обратный вдох + суб | 1 | 2D | Critical | B13. |
| `ST_VISION_ORBIT` | Видение | Хор + ветер | 1 | 2D | High | B14. |
| `ST_CARAVAN_START` | Начало марша | Цепь + шаг + ветер | 1 | 2D | High | B15/S01. |
| `ST_WHIP` | Кнут | Резкий, но не громче ветра | 2 | 3D | High | March beat. |
| `ST_ROCKS_FALL` | Камнепад | Удар + осколки + свист | 3 | 3D | Critical | S03. |
| `ST_TYRANT_LAND` | Приземление Тирана | Суб-удар + осыпь | 1 | 3D | Critical | S03. |
| `ST_METAMORPHOSIS` | Превращение | Влажные щелчки + треск | 1 | 3D | Critical | S03. |
| `ST_KEY_THROW` | Ключ | Металл по камню/снегу | 1 | 3D | High | S03. |
| `ST_UNLOCK_CHAINS` | Освобождение | Замок + цепь + выдох | 1 | 3D | Critical | S03. |
| `ST_WEDGE_REMOVE` | Клинья | Дерево + металл | 1 | 3D | High | S05. |
| `ST_WAGON_PUSH` | Толчок | Дерево + усилие | 1 | 3D | High | S05. |
| `ST_WAGON_FALL` | Падение повозки | Треск + удар + обломки | 1 | 3D | Critical | S05. |
| `ST_TYRANT_FALL` | Падение Тирана | Низкий удар + дрожь | 1 | 3D | Critical | S05. |
| `ST_VETERAN_KILL` | Милосердие | Короткий, тяжёлый, без смакования | 1 | 3D | Critical | S06. |
| `ST_NIGHT_FALL` | Ночь | Ветер + приглушение | 1 | 2D | High | S06. |
| `ST_POISON_POUR` | Яд | Жидкость + металл | 1 | 3D | High | S06. |
| `ST_DAWN` | Рассвет | Ветер + капель + колокол | 1 | 2D | High | S06. |
| `ST_ROAD_GAP` | Разрушенная дорога | Камень + ветер | 1 | 3D | High | S07. |
| `ST_SWORD_DISCARD` | Брошенный меч | Металл по камню | 1 | 3D | Medium | S07. |
| `ST_SHIFTY_DEATH` | Смерть Шифти | Слабый выдох + тишина | 1 | 3D | Critical | S08. |
| `ST_SCHOLAR_CONFRONT` | Разоблачение | Тихий металл/ткань | 1 | 3D | Critical | S09. |
| `ST_CAVE_ENTER` | Вход в пещеру | Гул + капли | 1 | 3D | High | S10. |
| `ST_CONFESSION` | Признание | Дыхание + пауза | 1 | 2D | Critical | S10. |
| `ST_WOUND` | Ранение | Резкий вдох + ткань + капли | 1 | 3D | Critical | S10. |
| `ST_CAVE_ESCAPE` | Побег | Шаги + дыхание + камни | 1 | 3D | High | S10. |
| `ST_HERO_CONFRONT` | Герой | Металл + ткань + дыхание | 1 | 3D | Critical | S11. |
| `ST_HERO_TAKEN` | Захват | Удар + хор-стоп | 1 | 3D | Critical | S11. |
| `ST_HERO_DEATH` | Смерть Героя | Тишина + ветер + колокол | 1 | 3D | Critical | S11. |
| `ST_GUARD_PRESENCE` | Страж | Низкий гул + искажение | 1 | 3D | Critical | S12; существующий CC0 файл. |
| `ST_THRESHOLD_CREAK` | Порог | Каменный скрип | 1 | 3D | High | S12; существующий CC BY файл. |
| `ST_ALTAR_LIE` | Алтарь | Ткань + камень + выдох | 1 | 3D | Critical | S13. |
| `ST_BLOOD_ABSORB` | Кровь впитывается | Тихий впитывающий звук | 1 | 3D | Critical | S13. |
| `ST_TYRANT_ENTER` | Вход Тирана | Шаги + рёв + эхо | 1 | 3D | Critical | S13. |
| `ST_SHADOW_TENDRILS` | Тени | Обратный хор + шёпот + суб | 1 | 3D | Critical | S13. |
| `ST_TYRANT_TORN` | Разрыв | Треск + хор-стоп + тишина | 1 | 3D | Critical | S13. |
| `ST_FINAL_CARD` | Карточка | Тихий удар/хор | 1 | 2D | High | S15. |
| `ST_RESTART` | `R` | Вдох/ветер | 1 | 2D | Medium | S15. |

### 7.7. Состояния и редкие события

| ID | Событие | Концепция | Вариации | Пространство | Приоритет | Условие |
|---|---|---|---|---|---|---|
| `PL_BREATH_COLD` | Холод | Дрожащий вдох/выдох, 2 с loop | 3 | 2D | High | `ConditionFeedback.cold`; сейчас не управляется. |
| `PL_NOISE_RUSTLE` | Шум | Шорох ткани/снега, 1 с loop | 3 | 2D | Medium | `ConditionFeedback.noise`; сейчас не управляется. |
| `PL_HEARTBEAT` | Сердцебиение | Низкий, медленный/быстрый | 3 | 2D | High | Страх/ранение/сон. |
| `PL_TINNITUS` | Звон | Высокий синус, мягкий вход | 2 | 2D | High | Сон/ранение/шок. |
| `ENV_WIND_GUST` | Порыв ветра | Широкий, с свистом | 6–8 | 3D/2D | Medium | Погода. |
| `ENV_RAIN_LOOP` | Дождь | Плотный, без «белого шума» | 3 | 2D | High | Z17. |
| `ENV_THUNDER` | Гром | Далёкий/близкий, с хвостом | 5–6 | 3D | High | Z17. |
| `ENV_WATER_LAP` | Вода | Лапы, пузыри, глубина | 5–6 | 3D | Medium | Z11/Black Sea. |
| `ENV_WATER_FLOW` | Поток | Ручей/канал, непрерывный | 3 | 3D | Medium | Z11. |
| `ENV_WATER_DRIP` | Капли | Одиночные, с эхом | 8–10 | 3D | Medium | Cave/tunnel. |
| `ENV_FIRE_LOOP` | Костёр | Потрескивание/шипение | 3 | 3D | High | Camp. |
| `ENV_FIRE_POP` | Хлопок | Короткий, случайный | 6–8 | 3D | Medium | Camp. |
| `ENV_BONE_CREAK` | Кость | Скрип/треск | 5–6 | 3D | Medium | Bone areas. |
| `ENV_BONE_SETTLE` | Кости оседают | Тихий стук/треск | 4 | 3D | Low | Z02/Z05. |
| `ENV_HORSE` | Конь | Копыта, храп, седло | 4 | 3D | Medium | Ауро/караван. |
| `ENV_BONE_SNAP` | Кость ломается | Резкий треск | 4–5 | 3D | High | Combat/ambience. |
| `ENV_ROCKFALL_SMALL` | Камнепад | Осыпь, далёкий | 6–8 | 3D | Medium | Mountains. |
| `ENV_ROCKFALL_LARGE` | Обвал | Удар + осколки | 3–4 | 3D | High | S03/Z17. |
| `ENV_ICE_CRACK` | Лёд | Сухой треск | 5–6 | 3D | Medium | Mountains. |
| `ENV_STONE_GROAN` | Камень | Низкий скрип | 4–5 | 3D | Medium | Temple/labyrinth. |
| `ENV_MUD_BUBBLE` | Грязь | Пузыри/чавканье | 5–6 | 3D | Low | Z04. |
| `ENV_TIDE_WARNING` | Прилив | Низкий гул + вода + шлюз | 2 | 2D | Critical | Z11; HUD. |
| `ENV_TIDE_GATE` | Шлюз | Камень/металл, тяжёлый | 2 | 3D | High | Z11. |
| `ENV_STORM_SURGE` | Штормовой прилив | Вода + гром + ветер | 1 | 2D | Critical | Z17. |
| `ENV_CAMP_INTERACT` | Лагерь | Огонь/ткань/металл | 3 | 3D | Medium | Z10. |
| `ENV_SEA_LAP` | Море | Глубокие лапы | 4 | 3D | Medium | Black Sea. |
| `ENV_SEA_GUST` | Морской ветер | Широкий, солёный | 3 | 3D | Medium | Black Sea. |
| `ENV_STATUE_GROAN` | Статуя | Низкий скрип камня | 2 | 3D | Medium | Black Sea. |

### 7.8. Чего в каталоге сознательно нет

- **Нет** звуков лазания, плавания, подводного дыхания, управляемой тени, активных заклинаний, стрельбы, транспорта, верховой езды игрока, стелс-убийств, компаньонского AI — этих механик нет в текущем проекте.
- **Нет** звуков «прокачки уровня», «лута редкости», «открытия сундуков» — если этих систем нет, не добавлять.
- **Нет** звуков для Нефис/Кассии/Эхо как реплик — только будущие голосовые концепции; маркеры не озвучиваются.
- **Нет** уникального саундтрека для sandbox-арен.

---

## 8. AI Voice Acting: концепция и pipeline

### 8.1. Что реально нужно озвучить

По текущим `.tres` и `sunny_barks.json`:

| Голос | Реплик | Знаков | Приоритет | Комментарий |
|---|---:|---:|---|---|
| **Наррация Санни** | 78 | 3 784 | **Critical** | Внутренний голос; тот же тембр, что Санни, но ближе/тише/медленнее. |
| **Санни (прямая речь)** | 49 | 1 588 | **Critical** | Диалоги и барки; ирония, усталость. |
| **Герой** | 37 | 1 034 | **High** | Благородство без пафоса; трагическая арка. |
| **Шифти** | 18 | 551 | **High** | Молодой, нервный; смерть в алькове. |
| **Учёный** | 16 | 759 | **High** | Умный, манипулятивный; не «злодей». |
| **Полицейский** | 11 | 785 | **High** | Процедурный, тяжёлый; брифинг. |
| **Desk officer** | 6 | 149 | **Medium** | Усталая бюрократия. |
| **Широкоплечий раб** | 5 | 125 | **Medium** | Грубый, агрессивный; короткая роль. |
| **Ветеран** | 4 | 112 | **High** | Сломленный, тихий; милосердие. |
| **Командир** | 2 | 43 | **Medium** | Командный, сухой; PA/радио. |
| **Барки Санни** | 30 | 2 976 | **High** | Короткие реплики в марше/опасности; не все обязательны. |
| **Заклятие** | — | — | **Critical** | Не в `.tres`; greeting и spell messages; отдельный синтетический голос. |
| **Итого** | **226 + 30** | **11 906** | — | ≈13–16 минут чистой речи. |

**Вывод:** объём озвучки небольшой. Полное озвучивание реально; нет причин оставлять «только главное». Но начинать нужно с 60–80 «якорных» реплик, чтобы зафиксировать тембр и манеру.

### 8.2. Что озвучивать полностью, а что оставить текстом

| Тип | Решение | Почему |
|---|---|---|
| Сюжетные диалоги (226 реплик) | **Полное VO** | Это основа эмоционального восприятия; текст без голоса сильно проигрывает. |
| Наррация Санни (78) | **Полное VO** | Внутренний голос — главный инструмент близости; без него история холоднее. |
| Барки (30) | **VO, но не все** | 15–20 ключевых; остальные можно оставить текстом/без звука, чтобы не перегружать. |
| Заклятие | **Синтетический VO** | Его голос — часть мира; текст без звука теряет угрозу. |
| UI/системные сообщения | **Без VO** | Короткие тексты; звук UI достаточен. |
| Враги/монстры | **Не речь** | Рычание, щелчки, дыхание; без слов. |
| Толпа | **Walla без слов** | Не озвучивать отдельные реплики, если их нет в сценарии. |
| Нефис/Кассия/Эхо | **Не озвучивать сейчас** | Маркеры без сцен/диалогов; VO появится вместе с контентом. |

### 8.3. Voice bible: характер и манера

| Персонаж | Возраст/тип | Тембр | Темп | Манера | Что избегать |
|---|---|---|---|---|---|
| **Санни** | 16–18, худой, уставший | Средний, слегка хриплый, «не поставленный» | Средний, с паузами | Ирония, самоирония, внутренняя речь тише и медленнее; никогда не «героический» | Пафос, «аниме-герой», слащавость, постоянная злость. |
| **Наррация Санни** | То же | Ближе к микрофону, интимнее | Медленнее на 10–15% | Наблюдательная, усталая, иногда горькая; дыхание слышно | Театральность, «сказочный рассказчик». |
| **Герой** | 25–35, воин | Низкий-средний, тёплый, с хрипотцой | Медленный | Благородство без декламации; говорит как человек, который устал держаться | «Паладин», командный крик, пафос. |
| **Шифти** | 15–20, трус | Средний-высокий, ломкий | Быстрый, сбивчивый | Нервный смех, частые вдохи, перебивает | Визгливость, комическая трусость. |
| **Учёный** | 30–45, образованный | Средний, ровный, чёткий | Ровный, контролируемый | Уверенность, лёгкое снисхождение, паузы перед ложью | «Злодейский шёпот», злорадство. |
| **Полицейский** | 35–50, тяжёлый | Низкий, грудной | Медленный, процедурный | Спокойствие, без тепла; читает инструкцию | Угрозы, крик, «плохой коп» из кино. |
| **Desk officer** | 25–40 | Средний, немного гнусавый | Быстрый, автоматический | Скука, вежливость по протоколу | Энтузиазм, «добрый клерк». |
| **Широкоплечий раб** | 30–40, сильный | Низкий, грубый | Быстрый, громкий | Агрессия/страх, короткие фразы | «Качок-злодей», рычание. |
| **Ветеран** | 45–60, сломленный | Низкий, хриплый, тихий | Очень медленный, с паузами | Усталость, достоинство, боль; говорит тише, чем ожидает игрок | Слёзы в голосе, мелодрама. |
| **Командир** | 40–55 | Низкий, сухой | Ровный, командный | Короткие приказы, без эмоций; PA/радио-фильтр | «Голливудский генерал». |
| **Заклятие** | — | Бесполый, многослойный, чистый | Очень медленный | Спокойствие, древность, лёгкое безразличие; слова — как факт | Робот, «бог», злодейский хор, шёпот-скример. |

**Референсы манеры (не клонировать):**
- Санни — молодой британский/европейский актёр с усталой иронией; не «аниме».
- Герой — сдержанный баритон, похожий на уставшего рыцаря, а не на генерала.
- Учёный — интеллектуал с мягким, но неприятным контролем.
- Заклятие — не человеческий голос; ближе к хору/стеклу, чем к актёру.

**Важно:** не клонировать голоса живых актёров. Референсы — только описание манеры. Для AI-клонирования использовать собственный голос или голос с письменным согласием.

### 8.4. Единообразие голоса

| Проблема | Решение |
|---|---|
| Разный тембр между сессиями | Один voice ID/модель на персонажа; не менять модель внутри роли. |
| «Плавание» интонации | Низкая температура (0.6–0.8), фиксированный seed, если поддерживается; 2–3 дубля, выбор лучшего. |
| Разная громкость | Единая цепочка обработки и LUFS-нормализация. |
| Неправильные ударения | Pronunciation lexicon + ручная проверка носителем; разбивать сложные слова. |
| Разная скорость | Единый `speed`/пауза; не растягивать в редакторе без необходимости. |
| Потеря эмоции | Генерировать по сценам, а не по алфавиту; сохранять контекст; использовать acting instructions/tags. |
| «AI-акцент» | Тестировать на русском; при акценте сменить модель/голос, а не «лечить» питчем. |

**Правило:** лучше 2–3 хороших дубля на реплику, чем 10 средних. Хранить все дубли, но в игру ставить только выбранный.

### 8.5. Массовая генерация

1. **Экспорт.** Собрать все `DialogueLine` и `BarkLine` в CSV/JSON с полями: `line_id`, `speaker`, `scene`, `text`, `context`, `duration`, `notes`. `line_id` — `<sequence>_<index>`; позже можно добавить поле в `DialogueLine`.
2. **Разметка.** Для каждой реплики добавить `direction` (эмоция, темп, пауза, шёпот/крик) и `take` (A/B/C). Не менять текст без согласования.
3. **Батчи.** Группировать по персонажу и сцене; генерировать 2–3 дубля; сохранять seed/settings.
4. **QC.** Прослушать все дубли; выбрать; отметить проблемы (ударение, артефакт, лишнее слово, обрезанный хвост).
5. **Обработка.** De-noise (осторожно), high-pass 80–100 Гц, EQ, compression 2:1–3:1, de-ess, normalize −18 LUFS, true peak −1 dBTP.
6. **Экспорт.** Ogg Vorbis mono 48 кГц, 96–128 kbps; имя `<speaker>_<scene>_<line_id>_v01.ogg`; WAV-мастер хранить отдельно.
7. **Интеграция.** `VoiceDirector` + `DialogueRunner`; субтитры остаются текстом; voice не автопродвигает реплику, если `duration=0`.
8. **Регрессия.** При изменении текста — перегенерировать только затронутые `line_id`; хранить хеш текста.

**Инструменты батча:** API ElevenLabs/Fish/Cartesia; локальный скрипт Chatterbox/XTTS; очередь с retry, лимитами и логом. Не генерировать 226 реплик одним файлом — потеряется управление.

### 8.6. Хранение и интеграция в Godot

```
assets/audio/voice/
  sunny/
    prologue/
      sip_1_01_v01.ogg
    caravan/
      camp_rations_03_v01.ogg
  hero/
    caravan/
      camp_aftermath_02_v01.ogg
  ...
resources/audio/voice/
  voice_manifest.tres        # типизированный ресурс: line_id -> stream, speaker, duration, loudness
  pronunciation_lexicon.tres # опционально
scripts/audio/
  voice_director.gd
```

**Минимальная интеграция без переписывания диалогов:**
- Добавить в `DialogueLine` опциональное поле `voice_id: StringName = &""` (или `voice_stream: AudioStream`).
- `DialogueRunner` при показе строки вызывает `AudioDirector.play_voice(line.voice_id)`.
- Если `voice_id` пуст — работает как сейчас (текст).
- `BarkLine` — аналогично.
- `VoiceDirector` — один `AudioStreamPlayer` на шине `Voice`, `max_polyphony=1`, ducking музыки/ambience, сигнал `voice_finished`.
- Субтитры не менять; voice и текст синхронизируются по `line_id`.

**Почему не хранить voice в `.tres` напрямую:** 226 `AudioStream` ссылок раздуют ресурсы и усложнят перегенерацию. Лучше manifest + `line_id`.

### 8.7. Сравнение AI Voice Tools (актуальность: 2026-11-01)

> Цены/лимиты меняются; проверять официальные страницы. «Русский» — заявленная поддержка, **не** гарантия качества; все модели требуют прослушивания на русском тексте проекта.

| Инструмент | Тип | Русский | Клонирование | Эмоции/управление | Консистентность | Выход | Цена (ориентир) | Лицензия/ограничения | Локально | Вердикт |
|---|---|---|---|---|---|---|---|---|---|---|
| **ElevenLabs v3/v4** | hosted TTS | Да (70+/90+ языков) | Instant (Starter), Professional (Creator) | Очень высокая; v3 — эмоциональная игра, теги/паузы; v4 — качество | Высокая при одном voice ID | MP3/WAV/PCM; 44,1 кГц на Pro | Starter $6/мес (30k credits), Creator $22/мес (121k), API $80/1M chars (v3/v4), $40/1M (Flash/Turbo) | Commercial on paid; free — нет; PVC только свой голос | Нет | **Primary** для русского VO, если качество на тесте хорошее. |
| **Fish Audio S2.1 Pro / Drama 3** | hosted + open weights | Да (80+/83 языка; русский tier 2) | Да, 10–30 с | Очень высокая; inline-теги, multi-speaker, director revision | Высокая | MP3/WAV | API платный; `s2.1-pro-free` бесплатен до 30.11.2026 (fair use); open weights — research license | Commercial API; open weights non-commercial | Да (S2 Pro ~4B; GPU) | **Strong second opinion**; Drama 3 — для сцен с несколькими персонажами. |
| **Cartesia Sonic 3.6** | hosted TTS | 44 языка (проверить русский) | Instant (Pro), Pro clone (Startup) | Высокая; скорость/эмоции/произношение | Высокая | WAV/MP3/PCM | Pro $5/мес (100k credits ≈133 мин), Startup $49/мес | Commercial from Pro | Нет | **Cheap/fast** для черновиков и UI-реплик; проверить русский. |
| **PlayHT 3.0** | hosted TTS | 140+ языков | Да, 30 с | Высокая; emotion preservation | Средняя-высокая | MP3/WAV | Creator $9.99/мес (1M credits); Studio $34.99 | Commercial on paid; free — нет | Нет | **Budget alternative**; качество зависит от голоса. |
| **Hume Octave** | hosted TTS | Ограниченно | Да | Очень высокая; acting instructions | Высокая | 48 кГц | — | **API sunset 13.11.2026** | Нет | **Не использовать** для нового проекта. |
| **OpenAI gpt-4o-mini-tts** | hosted TTS | Много языков (проверить) | Нет | Средняя; `instructions` | Высокая | MP3/OPUS/AAC | ~$0.015/мин; $0.60/1M text + $12/1M audio tokens | Commercial; модель deprecated (2027) | Нет | **Cheap fallback**; нет клонирования, меньше актёрской игры. |
| **Google Cloud TTS (Chirp 3 HD / Gemini TTS)** | hosted TTS | Да, много голосов | Instant custom voice (Chirp 3) | Средняя-высокая; Gemini TTS — prompt control | Очень высокая | MP3/Linear16/OGG | Chirp 3 HD $30/1M chars, 1M free; Gemini TTS token-based | Google Cloud terms; commercial | Нет | **Reliable Russian**; хорош для системных/второстепенных голосов. |
| **Azure AI Speech (Neural/HD)** | hosted TTS | Да, сильные русские голоса | Custom Neural Voice (платно) | Средняя; SSML, styles | Очень высокая | MP3/WAV/OGG | Neural $15/1M; HD $22/1M; 0.5M free | Commercial; custom voice training | Нет | **Enterprise-grade Russian**; меньше «актёрской» игры. |
| **MiniMax Speech-02/2.8 HD** | hosted TTS | Много языков (проверить) | Да, rapid clone | Высокая; эмоции | Высокая | MP3/WAV/PCM/FLAC | HD $100/1M; Turbo $60/1M | Commercial API | Нет | **Expressive alternative**; проверить русский. |
| **Resemble Chatterbox / Multilingual V3** | local open | Да (23 языка, включая русский) | Zero-shot, 5–10 с | Высокая; exaggeration control, paralinguistic tags | Средняя (зависит от reference) | WAV | Бесплатно | **MIT** (code/weights); watermark | Да; ~4–8 ГБ VRAM (Turbo меньше) | **Primary local** для русского; хорош для черновиков и полного VO при контроле. |
| **Coqui XTTS-v2** | local open | Да (17 языков, включая русский) | Zero-shot, 6 с | Средняя | Средняя | WAV | Бесплатно | **CPML, non-commercial** | Да; ~6 ГБ VRAM | **Local backup**; подходит для личного проекта, не для коммерции. |
| **Silero TTS v5** | local open | Да (русский — сильная сторона) | Нет (готовые голоса) | Низкая-средняя | Высокая | WAV | Бесплатно | **CC BY-NC 4.0** (кроме base CIS — MIT) | Да; CPU | **Placeholder** для временных дорожек; не финальный арт. |
| **GPT-SoVITS** | local open | Да (через обучение) | Few-shot, 1 мин | Средняя-высокая | Высокая после fine-tune | WAV | Бесплатно | **MIT** | Да; GPU 6–8 ГБ | **Custom voice** для уникального тембра; требует обучения. |
| **Kokoro-82M** | local open | Нет русского | Нет | Низкая | Высокая | WAV | Бесплатно | Apache 2.0 | Да; CPU | **Не подходит** для русского. |
| **Higgs Audio v2** | local open | English/Chinese focus | Да | Высокая | Средняя | WAV | Бесплатно | Apache/other (проверить) | Да; 24 ГБ VRAM рекомендовано | **Не для русского**; интересен для экспериментов. |
| **VibeVoice** | local open | English/Chinese | Да | Средняя | Высокая | WAV | Бесплатно | MIT, research-only note | Да | **Не для русского**; research. |

**8.7.1. Качество для русского: ориентировочный рейтинг**

| Уровень | Кандидаты | Комментарий |
|---|---|---|
| **S — тестировать первыми** | ElevenLabs v3/v4; Fish Audio S2.1 Pro/Drama 3 | Лучшая актёрская игра/эмоции; требуют слепого теста на русском. |
| **A — сильные альтернативы** | Cartesia Sonic 3.6; Chatterbox Multilingual V3; Azure Neural HD; Google Chirp 3 HD; MiniMax Speech-2.8 HD | Хорошая разборчивость/консистентность; меньше «актёрской» свободы или хуже русский акцент. |
| **B — черновики/бюджет** | PlayHT 3.0; OpenAI gpt-4o-mini-tts; XTTS-v2 | Быстро/дёшево; качество/эмоции ниже; XTTS — non-commercial. |
| **C — плейсхолдер** | Silero TTS v5 | Очень быстро, но роботизированно; только для тайминга. |
| **N/A** | Hume Octave (sunset); Kokoro/Higgs/VibeVoice (нет русского/фокус на других языках) | Не использовать для русского VO. |

**Выразительность (субъективно):** ElevenLabs v3/v4 и Fish Drama 3 — лучшие для «актёрской игры»; Chatterbox/Cartesia/PlayHT/MiniMax — высокие; Azure/Google — ровные, но менее свободные; OpenAI — средние; Silero — низкие.  
**Управляемость:** ElevenLabs (acting/теги), Fish (inline-теги, multi-speaker), Hume (acting instructions, но sunset), Cartesia (speed/emotion/pronunciation), PlayHT (emotion preservation), Chatterbox (exaggeration/cfg), XTTS (reference-only, слабее), Silero (SSML/ударения, но мало эмоций).  
**Ограничения:** клонирование требует согласия; free-тарифы часто без коммерческих прав; некоторые модели не поддерживают русский; watermark у Chatterbox; API-модели могут меняться/уходить (Hume — пример).

**Рекомендуемый стек:**
1. **ElevenLabs v3/v4** — основной кандидат для финального русского VO; проверить на 20–30 репликах.
2. **Fish Audio S2.1 Pro/Drama 3** — второй кандидат; особенно для сцен с несколькими персонажами.
3. **Chatterbox Multilingual V3 (local)** — бесплатный локальный вариант; хорош для черновиков и, возможно, финала при тщательном QC.
4. **XTTS-v2 / Silero** — только черновики/плейсхолдеры; лицензии non-commercial.
5. **Cartesia/PlayHT/Azure/Google** — альтернативы для второстепенных голосов и системных сообщений.

### 8.8. Локальная генерация и бесплатные решения

| Решение | Плюсы | Минусы | Когда использовать |
|---|---|---|---|
| **Chatterbox Multilingual V3** | MIT, русский, клонирование, эмоции, 4–8 ГБ VRAM, watermark | Средняя стабильность длинных реплик; нужен reference; watermark | Основной локальный вариант; черновики и финал при QC. |
| **XTTS-v2** | 17 языков, русский, 6 с reference, 6 ГБ VRAM | CPML non-commercial; качество ниже топовых; не развивается | Личный проект; быстрый черновик. |
| **Silero TTS v5** | Очень быстрый CPU, русские голоса, автоударения | Роботизированность, мало эмоций | Временные дорожки, тесты тайминга. |
| **GPT-SoVITS** | MIT, few-shot, хорошая похожесть | Нужно обучение/данные; сложнее | Уникальный тембр, если есть 1–2 минуты чистого голоса. |
| **Piper** | MIT, CPU, офлайн | Русские голоса ограничены; качество ниже | Embedded/прототип. |
| **Kokoro** | Apache 2.0, быстрый | Нет русского | Не использовать. |

**Аппаратные требования (ориентир, не замер на целевом ноутбуке):**
- Chatterbox: 4–8 ГБ VRAM; Turbo — меньше.
- XTTS-v2: ~6 ГБ VRAM.
- GPT-SoVITS: 6–8 ГБ VRAM.
- Silero: CPU, 1–2 ГБ RAM.
- Stable Audio 3 / ACE-Step: см. §9; для локальной музыки может потребоваться 8–16 ГБ VRAM; на RTX 3060 Laptop возможны компромиссы (Small/offload). **НЕ ПРОВЕРЕНО.**

### 8.9. Оценка стоимости VO

- 11 906 знаков ≈ 13–16 минут речи.
- ElevenLabs v3/v4: $80/1M chars → **≈$0.95** за один проход; 3 дубля ≈ **$2.85**; месячный Creator $22 покрывает 121k chars с запасом.
- Fish Audio: ориентир $15/1M → **≈$0.18** за проход; 3 дубля ≈ **$0.54** (проверять актуальный тариф).
- Cartesia: $50/1M → **≈$0.60** за проход.
- Azure Neural: $15/1M → **≈$0.18**; Google Chirp 3 HD: $30/1M → **≈$0.36**; OpenAI: ≈ **$0.23** за 15 минут.
- Локально: **$0** за генерацию, но время GPU/QC и электричество.

**Вывод:** стоимость генерации ничтожна по сравнению с временем на QC и монтаж. Не экономить на дублях; экономить на количестве моделей.

### 8.10. QC-чеклист

- [ ] Все 226 реплик + выбранные барки имеют файл.
- [ ] Нет галлюцинированных/пропущенных слов.
- [ ] Ударения и имена проверены носителем.
- [ ] Нет обрезанных хвостов/начала.
- [ ] Нет клиппинга, щелчков, дыхания в микрофон, эха комнаты.
- [ ] Громкость −18 LUFS ±1; true peak ≤ −1 dBTP.
- [ ] Длительность соответствует субтитрам (±15%).
- [ ] Один тембр на персонажа; нет «дрейфа» между сценами.
- [ ] Эмоция соответствует сцене; нет «одинакового» прочтения.
- [ ] Голос не клонирует живого актёра без согласия.
- [ ] Метаданные (model, voice ID, seed, take, date) сохранены.
- [ ] Файлы зарегистрированы в `docs/ASSET_LICENSES.md` (если внешние).
- [ ] В титрах указано использование AI-голоса.

### 8.11. Этика и лицензии

- Клонировать только свой голос или голос с документированным согласием.
- Не выдавать AI-голос за реального актёра; в титрах — «AI voice generation».
- Проверить условия инструмента: free-тарифы часто **не** дают коммерческих прав; для личного проекта это менее критично, но фиксировать.
- Не использовать голоса умерших/живых актёров без прав.
- Хранить consent-записи и метаданные; не коммитить чужие сэмплы.

---

## 9. AI-генерация музыки и звуков

### 9.1. Сравнение инструментов для музыки

> Актуальность: 2026-11-01. Цены/функции меняются; проверять официальные страницы. «Stems» — возможность получить отдельные дорожки; «Loop» — заявленная/практическая возможность бесшовного цикла.

| Инструмент | Тип | Качество/стиль | Управление | Stems | Seamless loop | Форматы | Цена (ориентир) | Коммерция | Локально | Вердикт |
|---|---|---|---|---|---|---|---|---|---|---|
| **Suno v6** | hosted, full songs | Очень высокое; вокал/инструментал, многие жанры | Промпт, структура, lyrics, style, personas | Да, до 12 дорожек (paid) | Нет нативной гарантии; DAW | MP3/WAV; stems WAV | ≈$10/мес Pro, ≈$30/мес Premier (проверять валюту/лимиты) | Paid plans; free — нет | Нет | **Быстрые эскизы и thematic mockups**; финал — после DAW/стемов. |
| **Eleven Music v2.5** | hosted | Высокое; инструментал/вокал; 5 мин | Промпт, composition plan, audio reference, inpainting | Да, 2/4/6 stems | Да, через inpainting | MP3 44,1 кГц; stems | API $0.15/мин; подписка | Paid; крупные game rights — Enterprise | Нет | **Лучший контроль структуры/лупов**; проверить цену/права. |
| **Stable Audio 3.0** | open weights + API | Высокое; инструментал, SFX; до 6 мин | Prompt tags, duration, audio-to-audio, inpainting/continuation | Да, instrument/stem generation | Да, через inpainting/continuation (ручная проверка) | WAV/FLAC (API) | Small/Medium бесплатно (Community License); Large API | Community License; регистрация; <$1M revenue | Да; Small/Medium на consumer GPU | **Лучший локальный/лицензионно чистый вариант**; без вокала. |
| **Google Lyria 3 / 3 Pro** | hosted (Vertex AI/Gemini) | Высокое; оркестр/вокал; 30 с / 184 с | Промпт, image input, lyrics, negative prompt, seed | Нет | Нет нативной; edit | MP3 (Lyria 3), WAV (Lyria 2) | Pay-per-use; проверить Vertex AI | Google Cloud terms; commercial | Нет | **Оркестровые эскизы**; нет стемов, меньше контроля для игры. |
| **ACE-Step v1.5** | open, local | Среднее-высокое; full songs, 4 мин | Промпт, duration, audio-to-audio, extend/repaint | Нет нативных stems | Нет нативной; DAW | WAV | Бесплатно | MIT/Apache (проверить веса) | Да; GPU 8–12 ГБ (ориентир) | **Бесплатный локальный черновик**; качество ниже топов. |
| **Udio** | hosted | Высокое | Промпт | Нет (downloads disabled) | — | — | — | — | Нет | **Исключён**: экспорт отключён после UMG settlement. |
| **Meta MusicGen / AudioCraft** | open, local | Среднее; instrumental | Промпт, melody conditioning | Нет | Нет | WAV | Бесплатно | Веса CC-BY-NC (non-commercial) | Да; GPU | **Fallback/исследование**; устарел. |
| **Riffusion / AIVA / Soundraw / Beatoven** | hosted | Среднее; library music | Промпт/редактор | Ограниченно | Зависит | MP3/WAV | Подписки | Зависит | Нет | **Temp/библиотека**; меньше контроля, чем Suno/Stable Audio. |

**Качество/управляемость (кратко):** Suno v6 и Eleven Music — лучший «музыкальный» результат; Stable Audio 3 — лучший контроль/лицензии для инструментала; Lyria 3 — красивый оркестр, но мало контроля для игры; ACE-Step — средний локальный; MusicGen — ниже. Udio исключён из-за отсутствия экспорта.

**Бесплатные лимиты (ориентир):**
- **Suno Free:** 50 кредитов/день (~10 треков), без коммерческих прав; скачивание ограничено/может меняться.
- **ElevenLabs Free:** 10k кредитов/мес; без коммерческой лицензии; музыка/озвучка — только тест.
- **Stable Audio 3:** Small/Medium — бесплатные веса (Community License); API/Large — платно.
- **Lyria 3:** ограниченные генерации в Gemini/AI Studio; Vertex AI — pay-per-use.
- **ACE-Step:** бесплатно локально; качество ниже, но лимитов нет.

**Вариации одного cue:**
- **Suno** — 2–4 варианта за генерацию; хорошо для поиска мелодии/аранжировки, но loop/stems нужно чистить.
- **Eleven Music** — inpainting/секции; можно менять фрагмент, сохраняя остальное; хорош для вариаций без потери структуры.
- **Stable Audio 3** — audio-to-audio + inpainting; можно делать слои/варианты из одного «родителя», сохраняя гармонию.
- **ACE-Step** — audio-to-audio/repaint; бесплатно, но качество ниже; хорош для быстрых итераций.
- **Lyria 3** — seed/negative prompt; ограниченные вариации, нет stems.

**Вывод по музыке:**
- **Suno v6** — для быстрых идей и melodical mockups; не гарантирует loop/stems чистоту.
- **Stable Audio 3.0** — основной локальный/лицензионно чистый инструмент для инструментальных cue, атмосфер и стемов; идеален для layered music, но без вокала.
- **Eleven Music** — если нужен вокал/структура и inpainting-лупы; дороже, но управляемее.
- **Lyria 3** — для оркестровых эскизов; не для интерактивной музыки.
- **ACE-Step** — бесплатный локальный резерв.

### 9.2. Рабочий процесс музыки для игры

1. **Brief.** Для каждой локации — mood, BPM, key, instrumentation, 3–5 refs, layers, loop length, transitions.
2. **Sketch.** Suno/Eleven Music/Lyria — 3–5 вариантов по 60–120 с; не 3-минутные песни.
3. **Selection.** Слепое прослушивание; выбрать 1–2; отметить, что нравится (тембр, ритм, плотность).
4. **Stems.** Stable Audio 3 / Eleven Music / Suno stems; если stems грязные — DAW/ Demucs.
5. **Loop.** Выбрать 30–60 с стабильной текстуры; crossfade 2–4 с; проверить zero-crossing; для слоёв — одинаковый BPM/длина.
6. **Layers.** Сгенерировать/вырезать `base`, `mid`, `high`, `stinger`; не делать «один трек, который всё делает».
7. **Mix.** LUFS −20…−18; true peak −1 dBTP; убрать низкий гул, который конфликтует с SFX; проверить моно.
8. **Integration.** `MusicDirector` + отдельные плееры на слой (или `AudioStreamSynchronized`, если слои статичны); crossfade между cue; `AudioStreamInteractive` для авторских переходов.
9. **QA.** 10–15 минут непрерывного прохождения; проверить, не надоедает ли loop; нет ли щелчков; не маскирует ли диалог.

**Prompt-формула:**
```
[genre/mood], [instruments], [tempo/BPM], [key/mode], [structure],
[production: dry/intimate/wide/cavernous], [dynamics], [no vocals/no drums],
[loop-friendly: steady texture, no big fills, no fade-out]
```
**Пример (меню):**
```
slow chamber lament, solo cello and detuned upright piano, sparse low choir,
52 BPM, D minor, intimate close-mic, long decay, no drums, no vocals,
steady texture, loop-friendly, no fade-out, no trailer braam
```
**Пример (караван):**
```
grim dark folk march, low strings, bass flute, distant horn, frame drum,
72 BPM, G minor, cold mountain wind, chain-like 3+3+2 rhythm, male choir on "mm",
restrained, no heroic melody, loop-friendly, no big fills
```
**Пример (святилище):**
```
sacred dark ambient, low male choir, cello, glass harmonica, pipe organ,
40 BPM, D minor, vast stone hall, long reverb, no percussion,
slow cluster, no melody, loop-friendly, no horror stingers
```

**Seamless loop — практическое правило:**
- Генерировать 60–120 с; брать 30–60 с, где нет вокальных фраз/больших fill.
- Crossfade 2–4 с; проверять на слух и в Spectrogram.
- Для слоёв — один и тот же таймлайн/ BPM; иначе `AudioStreamSynchronized` не спасёт.
- Не использовать MP3 для лупов; Ogg/WAV.

### 9.3. Сравнение инструментов для SFX

| Инструмент | Тип | Сильные стороны | Loop | Форматы | Цена | Коммерция | Локально | Вердикт |
|---|---|---|---|---|---|---|---|---|
| **ElevenLabs Sound Effects v2** | hosted | Короткие one-shot (~0,5–22 с; проверять лимит 30 с на странице тарифа); loop flag; WAV 48 кГц; быстрый | Да | MP3/WAV | $0.12/мин API; 200 credits/generation | Paid plans | Нет | **Primary** для one-shot и loop ambience. |
| **Mirelo SFX 2.0** | hosted | Video-to-SFX, Foley, 1–30 с, WAV, dialogue preservation | Нет поля loop | WAV | Free 5k credits; Creator €20/мес | Проверить terms | Нет | **Foley/видео-синхронизация**; не для лупов. |
| **Stable Audio 3 Small SFX** | open weights | Локально, SFX-специализация, Community License | Через inpainting | WAV | Бесплатно | Community License | Да; ~4–8 ГБ VRAM (ориентир) | **Primary local** для SFX. |
| **Krotos Studio** | recorded library + performance | 60k+ реальных записей, Foley/creatures, Video-to-Sound | Зависит | WAV | Pro $23.33/мес; Max $83.33/мес | Pro/Max commercial/broadcast | Нет | **Foley/оружие/существа**; не генеративный. |
| **Woosh** | open weights | SFX-specific, text/video-to-audio, 48 кГц | Нет | WAV | Бесплатно | **CC-BY-NC** weights | Да; 4–12 ГБ VRAM | **R&D only**; non-commercial. |
| **AudioX** | open weights | Unified SFX/music/foley, video-to-audio | Нет | WAV | Бесплатно | **CC-BY-NC** | Да; GPU | **R&D only**; non-commercial. |
| **HunyuanVideo-Foley** | open weights | 48 кГц, video-to-Foley | Нет | WAV | Бесплатно | Tencent Community License; territory restrictions | Да; GPU | **Осторожно**; не EU/UK/KR; проверить. |
| **AudioGen / MMAudio** | open | Text/video-to-audio | Нет | WAV | Бесплатно | Проверить лицензию | Да | **Fallback/исследование**. |

**Вариации SFX:**
- **ElevenLabs SFX v2** — один клип за запрос; вариации через повторные генерации + pitch/volume jitter в Godot.
- **Stable Audio 3** — seed/audio-to-audio/inpainting; можно делать семейства похожих звуков.
- **Krotos** — реальные записи + performance; лучшие вариации для Foley/оружия.
- **Mirelo** — несколько вариантов на видео; хорошо для синхронизации, не для лупов.
- **Woosh/AudioX** — seed/вариации, но non-commercial.

**Вывод по SFX:**
- **ElevenLabs SFX v2** — самый практичный hosted-вариант для игры: loop flag, WAV 48 кГц, короткие клипы.
- **Stable Audio 3 Small SFX** — локальный бесплатный вариант; проверять качество на целевом GPU.
- **Krotos Studio** — если нужен «настоящий» Foley/оружие/существа, а не синтез; дороже, но предсказуемее.
- **Mirelo** — для видео-синхронизированного Foley; не для интерактивных лупов.
- **Woosh/AudioX** — только исследование, если non-commercial устраивает; не строить на них pipeline.

### 9.4. Рабочий процесс SFX

1. **Каталог.** Взять ID из §7; для каждого — 2–3 референса (фильм/игра) и описание слоёв.
2. **Генерация.** 6–10 вариантов на событие; разные акценты (мягче/жёстче, ближе/дальше).
3. **Отбор.** Слепое прослушивание; выбрать 3–5; проверить на моно/наушниках/динамиках.
4. **Обработка.** High-pass, de-noise, transient shaping, EQ; для лупов — crossfade/zero-crossing.
5. **Вариации.** `AudioStreamRandomizer`: pitch ±1–2 semitones, volume ±1–2 dB; не для голоса/музыки.
6. **Интеграция.** `SfxPool` + priority/cooldown; 3D для мира, 2D для UI/игрока.
7. **QA.** 100+ повторных шагов/ударов; нет усталости, щелчков, клиппинга; не маскирует диалог.

**SFX prompt-формула:**
```
[source], [material], [action], [distance/perspective], [space/environment],
[attack/transient], [tail/decay], [no music/no voice], [loop if needed]
```
**Примеры:**
- `heavy boot step on packed snow, close perspective, cold mountain air, crisp crunch, short tail, no music, no voice`
- `old iron chain links shifting under tension, close, dry metal, slight grit, short ring, no music`
- `massive stone door grinding open, deep low-frequency rumble, dust, long dark reverb, no music`
- `giant ape-like creature roar, low subharmonic, wet breath, distant mountain echo, no music`
- `small wet larva screech, close, high and short, body horror, no music`
- `soft UI click on dark glass, short, muted, no reverb, no music`

### 9.5. Локальные требования (ориентир)

| Инструмент | VRAM | RAM | Скорость | Статус |
|---|---:|---:|---|---|
| Stable Audio 3 Small / Medium | 6–12 ГБ (Medium с offload) | 16–32 ГБ | секунды–минуты на клип | **НЕ ПРОВЕРЕНО** на RTX 3060 Laptop. |
| Stable Audio 3 Small SFX | 4–8 ГБ | 16 ГБ | быстро | **НЕ ПРОВЕРЕНО**. |
| ACE-Step v1.5 | 8–12 ГБ | 16–32 ГБ | 4 мин на A100 ≈20 с; на consumer GPU дольше | **НЕ ПРОВЕРЕНО**. |
| MusicGen | 8–16 ГБ | 16–32 ГБ | средне | **НЕ ПРОВЕРЕНО**. |
| Woosh | 4–12 ГБ | 16 ГБ | средне | **НЕ ПРОВЕРЕНО**. |
| AudioX | 8–12 ГБ | 16–32 ГБ | средне | **НЕ ПРОВЕРЕНО**. |
| Chatterbox | 4–8 ГБ | 8–16 ГБ | быстро | **НЕ ПРОВЕРЕНО**. |
| XTTS-v2 | ~6 ГБ | 8–16 ГБ | быстро | **НЕ ПРОВЕРЕНО**. |

**Практика:** на ноутбуке с RTX 3060 Laptop (6–8 ГБ VRAM) начинать с **Small**-моделей и offload; не запускать Stable Audio Medium и ACE-Step одновременно; для тяжёлых моделей использовать облако/API. Это ориентир, а не замер.

### 9.6. Лицензии и коммерция (кратко)

| Инструмент | Лицензия output | Коммерческое использование | Что проверить |
|---|---|---|---|
| Suno | Paid plan rights | Да, на paid; free — нет | Права на трек, stems, game use; текущие terms. |
| Eleven Music | Paid plan rights | Да, на paid; крупные game rights — Enterprise | Music terms; game-specific tier. |
| Stable Audio 3 | Community License | Да, <$1M revenue; регистрация | Community License; attribution; self-host terms. |
| Lyria 3 | Google Cloud terms | Да, по условиям | Vertex AI terms; SynthID; game use. |
| ACE-Step | MIT/Apache (код/веса) | Проверить веса/данные | Model card; output rights. |
| Udio | — | Нет экспорта | Не использовать. |
| MusicGen | CC-BY-NC weights | Нет (non-commercial) | Model card. |
| ElevenLabs SFX | Paid plan rights | Да, на paid | Sound Effects terms. |
| Mirelo | Terms | Проверить | Output/game use. |
| Krotos | Pro/Max commercial | Да | Broadcast/game rights. |
| Stable Audio 3 SFX | Community License | Да, <$1M | Registration/attribution. |
| Woosh | CC-BY-NC | Нет | Non-commercial. |
| AudioX | CC-BY-NC | Нет | Non-commercial. |
| Hume Octave | — | — | API sunset 13.11.2026. |

**Для личного некоммерческого проекта** ограничения мягче, но:
- не коммитить чужие temp-треки;
- не распространять сборку с чужими записями;
- фиксировать лицензии AI-ассетов в `docs/ASSET_LICENSES.md`;
- если проект когда-нибудь станет публичным — пересмотреть non-commercial модели (XTTS, Silero, Woosh, AudioX, MusicGen).

### 9.7. Рекомендуемый стек по задачам

| Задача | Primary | Backup | Local/free |
|---|---|---|---|
| Тематические эскизы музыки | Suno v6 | Eleven Music | ACE-Step |
| Финальные инструментальные cue | Stable Audio 3 Medium | Eleven Music | Stable Audio 3 Medium local |
| Вокал/песня (если нужна) | Eleven Music / Suno | Lyria 3 | — |
| Лупы и стемы | Eleven Music inpainting / Stable Audio 3 | Suno stems + DAW | Stable Audio 3 local |
| One-shot SFX | ElevenLabs SFX v2 | Mirelo SFX 2.0 | Stable Audio 3 Small SFX |
| Foley/оружие/существа | Krotos Studio | Mirelo | Запись/библиотека |
| Loop ambience | ElevenLabs SFX v2 | Stable Audio 3 | Stable Audio 3 local |
| Русский VO | ElevenLabs v3/v4 | Fish Audio S2.1 Pro | Chatterbox Multilingual |
| Черновик VO | Cartesia / Silero | XTTS-v2 | Chatterbox / Silero |
| QC/монтаж | Reaper | Audacity | Python (только анализ) |
| Интеграция | Godot AudioStream* | — | — |

---

## 10. Архитектура аудиосистемы в Godot

### 10.1. Оценка текущей архитектуры

| Компонент | Сейчас | Оценка | Минимальное вмешательство |
|---|---|---|---|
| `GameSettings` | RefCounted; Master/Music/SFX; создаёт шины в рантайме | Рабочий шаблон, но не глобальный | Расширить поля; применять через `AudioDirector`; не дублировать создание шин. |
| `ConditionFeedback` | Два `AudioStreamPlayer` в `sunny.tscn` | Полезный компонент, но не управляется | Оставить; route в `SFX`/`Voice`; позже подключить cold/noise. |
| `PilgrimPath` | Три прямых плеера | Работает, но не микшируется | Оставить поведение; назначить bus; позже перевести на `AudioDirector`. |
| `SliceDirector` | Биты B01–B16 | Готовая событийная шина | Подписаться на `beat_changed`, не переписывать. |
| `CaravanSite` | Фазы CAMP/ATTACK/… | Готовая state machine | Подписаться на `phase_changed`. |
| `PilgrimPath` | Фазы ROAD/ASCENT/… | Готовая state machine | Подписаться на `phase`/сигналы. |
| `LabyrinthFirstFragment` | Зоны/триггеры/прилив | Готовые маркеры | Добавить `AudioZone`/`AudioDirector` вызовы. |
| UI | Меню/карта/RPG | Готовые сигналы | Подключить UI SFX. |

**Принцип:** не переписывать режиссёров и state machines. Аудио — **наблюдатель** существующих сигналов и фаз.

### 10.2. Предлагаемая шина

```
Master
├── Music        → send Reverb (−12 dB)
├── Ambience     → send Reverb (−6 dB)
├── SFX          → send Reverb (−6 dB)
├── Voice        → send Reverb (−18 dB)
├── UI           → без send
└── Reverb       → return в Master
```

| Шина | Эффекты | Назначение |
|---|---|---|
| **Master** | EQ (high-pass 30 Hz), Compressor (2:1), Limiter (−1 dBTP) | Защита от клиппинга, общий баланс. |
| **Music** | Compressor (2:1), EQ (лёгкий cut 250–400 Hz) | Музыка не маскирует речь. |
| **Ambience** | EQ, Compressor | Фон не маскирует шаги/опасность. |
| **SFX** | Compressor, EQ | Удары/шаги/мир. |
| **Voice** | EQ (high-pass 80 Hz), Compressor (3:1), de-esser (EQ) | Разборчивость речи. |
| **UI** | EQ, Limiter | Короткие, тихие, без писка. |
| **Reverb** | `AudioEffectReverb` | Общий reverb-return; зоны меняют wet/room size. |

**Почему не per-source reverb:** в Godot нет дешёвого per-source send; общий return + зоны — практичный компромисс. Для пещеры/храма можно добавить отдельный `ReverbCave` bus, если качество потребует.

**Файл:** `default_bus_layout.tres` в корне проекта (не создавать в рантайме). `GameSettings._ensure_audio_buses()` заменить на проверку/применение, а не создание.

### 10.3. Структура файлов (предложение)

```
assets/audio/
  music/
    menu/main_theme.ogg
    prologue/park_base.ogg
    caravan/road_chain.ogg
    ...
  ambience/
    prologue/city_bed.ogg
    caravan/camp_fire.ogg
    labyrinth/z01_wind.ogg
    ...
  sfx/
    player/footsteps/snow_01.wav
    combat/hit_flesh_01.wav
    world/chain_loop.ogg
    ...
  voice/
    sunny/prologue/sip_1_01_v01.ogg
    ...
  ui/click_01.wav
resources/audio/
  music_cues/*.tres
  ambience_zones/*.tres
  sfx_cues/*.tres
  surfaces/*.tres
  voice/voice_manifest.tres
scripts/audio/
  audio_director.gd
  music_director.gd
  ambience_director.gd
  sfx_pool.gd
  voice_director.gd
  surface_detector.gd
  reverb_zone.gd
  audio_debug_overlay.gd
scenes/audio/
  audio_director.tscn
  sfx_pool_3d.tscn
```

**Именование:**
- `music/<location>/<cue>_<layer>.ogg`
- `ambience/<location>/<bed>_<variant>.ogg`
- `sfx/<category>/<event>_<nn>.wav`
- `voice/<speaker>/<scene>/<line_id>_v<nn>.ogg`
- `ui/<event>_<nn>.wav`

### 10.4. Core: AudioDirector

**Autoload** `AudioDirector`:
```gdscript
# scripts/audio/audio_director.gd
extends Node

signal music_changed(cue_id: StringName)
signal ambience_changed(zone_id: StringName)

@onready var music: MusicDirector = $MusicDirector
@onready var ambience: AmbienceDirector = $AmbienceDirector
@onready var sfx: SfxPool = $SfxPool
@onready var voice: VoiceDirector = $VoiceDirector

func play_music(cue_id: StringName, fade := 2.0) -> void:
    music.play_cue(cue_id, fade)

func set_music_intensity(value: float) -> void:
    music.set_intensity(value)

func play_ambience(zone_id: StringName, fade := 2.0) -> void:
    ambience.play_zone(zone_id, fade)

func play_sfx(cue_id: StringName, at: Vector3 = Vector3.INF, params := {}) -> void:
    sfx.play(cue_id, at, params)

func play_voice(line_id: StringName) -> void:
    voice.play_line(line_id)

func duck_music(amount_db: float, duration: float) -> void:
    music.duck(amount_db, duration)
```

**Правила:**
- `AudioDirector` не знает о сценах; сцены вызывают его.
- Все id — `StringName`; неизвестный id → warning, не crash.
- `AudioDirector` работает в `PROCESS_MODE_ALWAYS`, чтобы музыка/UI не останавливались при паузе; SFX/ambience можно ставить на паузу.
- `AudioDirector` загружает `GameSettings` и применяет шины при `_ready()`.

### 10.5. MusicDirector

**Два уровня:**
1. **Внутри cue:** один `AudioStreamPlayer` на слой (3–5 слоёв), все стартуют в одном кадре; `volume_db` каждого слоя тянется Tween’ом. Это проще и надёжнее, чем менять громкость внутри `AudioStreamSynchronized` на лету.
2. **Между cue:** две группы слоёв (A/B) + Tween crossfade; либо `AudioStreamInteractive` для авторских переходов.

> `AudioStreamSynchronized` полезен, когда слои должны быть сэмпл-в-сэмпл и их громкость не меняется часто. Для динамической игры с вертикальными слоями практичнее отдельные `AudioStreamPlayer` на слой.

```gdscript
# scripts/audio/music_director.gd (упрощённый набросок)
extends Node

@export var cue_library: Dictionary[StringName, MusicCue] = {}
var _layers: Array[AudioStreamPlayer] = []
var _current: StringName = &""

func _ready() -> void:
    for i in 6:
        var p := AudioStreamPlayer.new()
        p.bus = &"Music"
        p.max_polyphony = 1
        add_child(p)
        _layers.append(p)

func play_cue(cue_id: StringName, fade := 2.0) -> void:
    if cue_id == _current:
        return
    var cue := cue_library.get(cue_id)
    if cue == null:
        push_warning("Unknown music cue: %s" % cue_id)
        return
    # 1) fade out current layers
    var out := create_tween().set_parallel()
    for p in _layers:
        out.tween_property(p, "volume_db", -80.0, fade)
    await out.finished
    # 2) assign new streams and start together
    for i in _layers.size():
        var p := _layers[i]
        p.stop()
        if i < cue.layers.size():
            p.stream = cue.layers[i].stream
            p.volume_db = -80.0
            p.play()
    # 3) fade in selected layers
    var in_t := create_tween().set_parallel()
    for i in mini(_layers.size(), cue.layers.size()):
        in_t.tween_property(_layers[i], "volume_db", cue.layers[i].default_db, fade)
    _current = cue_id
    music_changed.emit(cue_id)

func set_intensity(value: float) -> void:
    var cue := cue_library.get(_current)
    if cue == null:
        return
    var t := create_tween().set_parallel()
    for i in mini(_layers.size(), cue.layers.size()):
        var layer := cue.layers[i]
        var db := lerpf(layer.min_db, layer.max_db, clampf(value, 0.0, 1.0))
        t.tween_property(_layers[i], "volume_db", db, 0.25)
```

**MusicCue resource (предложение):**
```gdscript
class_name MusicCue
extends Resource
@export var id: StringName
@export var bpm: float = 0.0
@export var key: String = ""
@export var loop_length: float = 0.0
@export var layers: Array[MusicLayer] = []
@export var stingers: Dictionary[StringName, AudioStream] = {}
```

```gdscript
class_name MusicLayer
extends Resource
@export var name: StringName
@export var stream: AudioStream
@export var default_db: float = -12.0
@export var min_db: float = -80.0
@export var max_db: float = -6.0
```

**Переходы:**
- Обычный crossfade 2–4 с.
- Сюжетный срез 0,3–0,8 с.
- `AudioStreamInteractive` — если нужен переход «на следующий такт»:
```gdscript
var playback := player.get_stream_playback()
if playback is AudioStreamPlaybackInteractive:
    playback.switch_to_clip_by_name(&"combat")
```
- После крупного события — `stop()` + 2–8 с тишины, затем новый cue.

### 10.6. AmbienceDirector

- 3–4 `AudioStreamPlayer` (2D) для глобальных слоёв: `bed`, `mid`, `detail`, `weather`.
- `AudioStreamRandomizer` для редких one-shot (капли, камни, треск).
- `Area3D`/`AudioZone` для локальных зон; при входе — crossfade.
- `AudioStreamPlaylist` — для последовательных/случайных ambience-фрагментов.
- Параметры: `time_of_day`, `weather`, `tide_level`, `indoor`, `danger`. Они меняют громкость/фильтр/выбор слоя, а не запускают новый трек каждый раз.

```gdscript
func play_zone(zone_id: StringName, fade := 2.0) -> void:
    var zone := zone_library.get(zone_id)
    if zone == null:
        push_warning("Unknown ambience zone: %s" % zone_id)
        return
    # crossfade bed/mid/detail; weather/tide — отдельные слои
```

**Правило:** ambience не должен быть «одним файлом на локацию». Минимум 3 слоя + random one-shots.

### 10.7. SfxPool и приоритеты

**Два пула:**
- **3D:** 16–24 `AudioStreamPlayer3D` в пуле; для мира.
- **2D:** 1 `AudioStreamPlayer` с `AudioStreamPolyphonic` (polyphony 32) для UI/игрока/близких one-shot; или 8 `AudioStreamPlayer` с `max_polyphony`.

**Приоритеты:**

| Приоритет | Примеры | Макс. одновременно | Политика вытеснения | Cooldown |
|---|---|---:|---|---|
| **Critical** | VO, смерть, рёв Тирана, сюжетный stinger | 2 | Не вытеснять; остановить Low/Medium | 0 |
| **High** | удар, блок, уклонение, враг, подбор | 8 | Вытеснить Low, затем самый старый Medium | 0,03–0,08 с |
| **Medium** | шаги, двери, костёр, ambience one-shot | 16 | Вытеснить Low/старый Medium | 0,05–0,15 с |
| **Low** | дальняя осыпь, UI hover, толпа | 12 | Отбрасывать при перегрузке | 0,2–0,5 с |

**SfxCue resource:**
```gdscript
class_name SfxCue
extends Resource
@export var id: StringName
@export var streams: Array[AudioStream] = []
@export var bus: StringName = &"SFX"
@export var priority: int = 1          # 0 Low .. 3 Critical
@export var volume_db: float = 0.0
@export var pitch_range: Vector2 = Vector2(0.97, 1.03)
@export var cooldown: float = 0.0
@export var max_instances: int = 4
@export var spatial: bool = true
@export var max_distance: float = 60.0
@export var unit_size: float = 6.0
@export var loop: bool = false
```

**Поведение:**
- При `play()` проверить cooldown, max_instances, приоритет.
- Если пул полон — вытеснить Lowest/oldest; если новый Low — drop.
- Для вариаций — `AudioStreamRandomizer` + pitch/volume jitter.
- Для шагов — отдельный пул/лимит 2 (левая/правая), чтобы не плодить 30 одинаковых звуков.

### 10.8. VoiceDirector

- Один `AudioStreamPlayer` на `Voice`, `max_polyphony=1`.
- `play_line(line_id)`:
  - lookup manifest;
  - stop previous (fade 0,05 с);
  - duck Music −8 dB и Ambience −3 dB на время реплики;
  - play; emit `voice_started/finished`.
- Не автопродвигать диалог, если `DialogueLine.duration == 0`.
- Субтитры — как сейчас; voice не заменяет текст.
- Для барков — 2D, тише, без ducking (или −3 dB).

### 10.9. 3D, окклюзия, reverb

**Базовые настройки `AudioStreamPlayer3D`:**
- `attenuation_model = ATTENUATION_LOGARITHMIC` или `INVERSE_DISTANCE`;
- `unit_size = 4–8`;
- `max_distance = 40–120` (в зависимости от зоны);
- `attenuation_filter_cutoff_hz = 5000`;
- `panning_strength = 1.0`;
- `doppler_tracking = DOPPLER_TRACKING_PHYSICS_STEP` только для падающих камней/повозки/Тирана;
- `max_polyphony = 2–4`;
- `bus = &"SFX"`.

**Окклюзия (минимальная):**
- Raycast из listener в источник каждые 0,15–0,25 с (не каждый кадр).
- Если стена: `volume_db -= 3…6`, `attenuation_filter_cutoff_hz = 1200…2500`.
- Альтернатива: переключать `bus` на `SFX_Occluded` с `AudioEffectFilter` (low-pass) — дороже по bus-ам, но чище.
- Не делать окклюзию для музыки/ambience/voice.

**Reverb-зоны:**
- `Area3D` + `ReverbZone` script:
  - outdoor: wet 0,15–0,25, room 0,2;
  - tunnel/cave: wet 0,45–0,65, room 0,5;
  - temple: wet 0,6–0,8, room 0,8;
  - cell: wet 0,2–0,3, room 0,3.
- Tween 0,5–1,5 с; не переключать мгновенно.
- `AudioEffectReverb` на `Reverb` bus; `Reverb` возвращается в Master.

**Listener:**
- По умолчанию камера — listener; если камера уходит в кинематографический режим, можно добавить `AudioListener3D` и `make_current()`, но не обязательно.

### 10.10. Настройки и сохранение

**Расширить `GameSettings`:**
```gdscript
var master_volume := 0.8
var music_volume := 0.7
var ambience_volume := 0.8
var sfx_volume := 0.8
var voice_volume := 1.0
var ui_volume := 0.8
```
`CONFIG_VERSION = 2`; миграция:
- если `voice`/`ambience`/`ui` отсутствуют — взять defaults;
- сохранять в `user://settings.cfg` секция `[audio]`;
- `apply_audio()` → `AudioDirector.apply_bus_levels()` (если autoload есть) или локально;
- не создавать шины в рантайме, если есть `default_bus_layout.tres`.

**Экран настроек:** добавить слайдеры Voice/Ambience/UI; подписи; «Сброс»; сохранять при изменении (как сейчас).

**Пауза/фокус:**
- При паузе: Music/Ambience volume −6 dB (не стоп), SFX/voice пауза.
- При потере фокуса: Master mute (опция, Low priority).
- При возврате: восстановить.

### 10.11. Точки интеграции в существующие сцены

| Сцена/система | Сигнал/фаза | Аудио-действие |
|---|---|---|
| `SliceDirector` | `beat_changed` B01–B16 | `play_music`/`play_ambience` по биту; `ui.drowsiness` → low-pass/tinnitus. |
| `ParkStreet` | `play_cutscene("doze")` | `drowse` слой; фильтр; звон. |
| `StationLobby` | `code_black` | `ST_CODE_BLACK`, `music.alarm`. |
| `ContainmentRoom` | `restrain`, `policeman_enters` | `ST_RESTRAIN`, `ST_POLICEMAN_STEPS`, `ST_DROWSINESS`. |
| `SliceDirector` | `_spell()` | `SP_GREETING`. |
| `MountainVision` | `vision`, `orbit` | `ST_VISION_ORBIT`, `music.mountain`. |
| `FirstNightmarePass` | `start`, march beats | `ST_CARAVAN_START`, chain/ambience; whip. |
| `CaravanSite` | `phase_changed` CAMP/ATTACK/LARVA/WAGON/AFTERMATH/NIGHT/DAWN | music/ambience states; stingers. |
| `CaravanSiteArrival` | `attack_requested`, `larva_grabbed`, `key_collected`, `wagon_push_requested`, `night_requested`, `dawn_requested` | `ST_ROCKS_FALL`, `ST_METAMORPHOSIS`, `ST_KEY_THROW`, `ST_WAGON_FALL`, `ST_NIGHT_FALL`, `ST_DAWN`. |
| `PilgrimPath` | `phase` ROAD/ASCENT/ALCOVE/DAWN/SCHOLAR/CAVE/HERO/TEMPLE | music/ambience states; existing wind/guard/creak route to SFX. |
| `PilgrimPathArrival` | `road_gap_seen`, `sword_discarded`, `rest_requested`, `scholar_requested`, `cave_requested`, `cave_escape_requested`, `hero_requested`, `bell_rung`, `temple_reached` | stingers/voice. |
| `ShadowSanctuary`/`AltarRitual` | ALTAR/TYRANT/DEATH | `SP_*`, `ST_ALTAR_LIE`, `ST_SHADOW_TENDRILS`, `ST_TYRANT_TORN`, `ST_SILENCE`. |
| `Appraisal` | messages | `SP_APPRAISAL`, `SP_TRUE_NAME`, `SP_ASPECT`, `SP_BOND`, `SP_SEAL`. |
| `Finale` | messages | `SP_AWAKENING`, `SP_FLAW`, `ST_FINAL_CARD`. |
| `LabyrinthFirstFragment` | zone triggers / `TideController` | `LAB_*` cues; `ENV_TIDE_*`; `ENV_STORM_*`. |
| `MainMenu` | buttons/sliders | `UI_*`; `play_music("menu")`. |
| `MapScreen`/RPG | open/close/select | `UI_*`. |
| `DialogueRunner` | line started/finished | `VoiceDirector.play_line`; ducking. |

### 10.12. Производительность

| Параметр | Цель | Как достичь |
|---|---|---|
| Одновременные голоса | ≤24 (пик 32) | Приоритеты, cooldowns, max_instances, пулы. |
| 3D-источники | ≤16 активных | `max_distance`, зоны, `VisibilityEnabler3D`, stop за 60 м. |
| Музыка | 1 cue + 4–6 стемов | 4–6 `AudioStreamPlayer` на слой; `AudioStreamSynchronized` только если слои статичны. |
| Ambience | 4 слоя + 8 one-shot | `AudioStreamPlaylist`/Randomizer. |
| Память аудио | <150 МБ | Ogg для длинных, WAV для коротких; не держать неиспользуемые. |
| CPU audio | <5% | Ограничить голоса, окклюзию 0,2 с, не делать per-frame raycast. |
| Загрузка | без фризов | Preload коротких SFX; stream music/ambience. |

### 10.13. Тестирование

**GUT/headless:**
- `default_bus_layout.tres` существует; шины Master/Music/Ambience/SFX/Voice/UI/Reverb.
- `GameSettings` сохраняет/загружает 6 громкостей; миграция v1→v2.
- `SfxPool` соблюдает priority/cooldown/max_instances.
- `SurfaceDetector` возвращает правильный `SurfaceType` на тестовой геометрии.
- `VoiceDirector` находит все `line_id` из manifest; нет missing.

**Runtime (вручную):**
- Прямой запуск сцены F6: шины есть; звук не падает в Master.
- Меню → игра → меню: музыка crossfade; UI звуки.
- 5 поверхностей: шаги различаются.
- Бой: удар/попадание/блок/уклонение/смерть.
- Караван: фазы CAMP→ATTACK→LARVA→WAGON→AFTERMATH→NIGHT→DAWN.
- Pilgrim: ветер/страж/скрип; голос.
- Sanctuary: алтарь/Тиран/тени/тишина.
- Appraisal/Finale: spell sounds.
- Настройки: Voice=0 → голос молчит, музыка играет; Music=0 → музыка молчит; сохраняется после перезапуска.
- Пауза/фокус: музыка приглушается, SFX стоп.
- 10 минут loop: нет щелчков/усталости.
- Максимум голосов: нет обрывов/клиппинга.

**NOT TESTED:** всё выше — план; фактический запуск не выполнялся.

### 10.14. Минимальная миграция (без переписывания)

1. **Bus layout.** Добавить `default_bus_layout.tres`; назначить bus существующим плеерам (`WindSource`, `GuardPresence`, `ThresholdCreak`, `ColdBreath`, `NoiseRustle`). Проверить F6.
2. **AudioDirector.** Добавить autoload/сцену; `GameSettings.apply_audio()` делегирует; ничего не ломать.
3. **Settings.** Добавить Voice/Ambience/UI; миграция; меню.
4. **UI SFX.** Подключить к существующим кнопкам/слайдерам.
5. **SurfaceDetector + footsteps.** Добавить в `sunny_waking_poc.tscn`; 6–8 поверхностей.
6. **Combat/interaction SFX.** Подключить к `MeleeAttack`, `Hurtbox`, `HealthComponent`, `Interactable`.
7. **Music/ambience.** Начать с меню, пролога, каравана; затем pilgrim/sanctuary.
8. **Voice.** Manifest + `DialogueLine.voice_id`; 60 якорных реплик; затем все.
9. **Polish.** Reverb zones, occlusion, randomizer, captions, credits.

---

## 11. Приоритетный план внедрения

> Оценки — для одного разработчика с AI-инструментами; это ориентир, не обещание сроков. Каждый этап заканчивается проверкой и записью результата (включая **NOT TESTED**, если проверка не выполнялась).

### 11.1. Stage 0 — Foundation (Critical)

| # | Задача | Приоритет | Оценка | Зависимости | Приёмка |
|---:|---|---|---|---|---|
| 0.1 | `default_bus_layout.tres`: Master/Music/Ambience/SFX/Voice/UI/Reverb | **Critical** | 0,5–1 день | — | Шины видны в редакторе; прямой F6 не падает в Master. |
| 0.2 | `AudioDirector` autoload + пустые `MusicDirector`/`AmbienceDirector`/`SfxPool`/`VoiceDirector` | **Critical** | 2–3 дня | 0.1 | Сцена запускается; нет missing nodes; warning на неизвестный id. |
| 0.3 | Расширить `GameSettings` до 6 громкостей + миграция v1→v2 | **Critical** | 1–2 дня | 0.1 | Сохранение/загрузка; Voice=0 не глушит музыку. |
| 0.4 | `SurfaceDetector` + 6–8 `SurfaceType` + шаги | **Critical** | 2–3 дня | 0.2 | Шаги различаются на снегу/льду/камне/грязи/костях/дереве. |
| 0.5 | UI SFX (hover/click/back/tab/slider/error/confirm) | **Critical** | 1–2 дня | 0.2 | Меню/карта/RPG звучат; нет писка. |
| 0.6 | Существующие 3 плеера PilgrimPath → bus `SFX`/`Voice`; loop import | **Critical** | 0,5 дня | 0.1 | Ветер/страж/скрип не в Master; loop без щелчка. |
| 0.7 | Audio debug overlay (bus meters, voice count) | **Medium** | 1 день | 0.2 | Видно, сколько голосов играет; можно отключить. |

**Выход Stage 0:** игра всё ещё почти без контента, но аудиосистема существует, микшируется и не ломается при F6.

### 11.2. Stage 1 — Первый час: меню, пролог, караван (High)

| # | Задача | Приоритет | Оценка | Зависимости | Приёмка |
|---:|---|---|---|---|---|
| 1.1 | Музыка меню + UI SFX | **High** | 2–3 дня | Stage 0 | Меню звучит; crossfade в игру. |
| 1.2 | Ambience парка/улицы/станции | **High** | 2–3 дня | 0.2 | Городской слой; шаги; walla. |
| 1.3 | Музыка/ambience лобби и изолятора | **High** | 3–4 дня | 1.2 | Code Black; дремота; обрыв в тишину. |
| 1.4 | Пустота/видение: spell + mountain cue | **High** | 2–3 дня | 1.3 | Приветствие Заклятия; переход к видению. |
| 1.5 | Марш каравана: цепь, ветер, музыка | **High** | 3–5 дней | 1.4 | Цепь 3+3+2; Ауро; прибытие. |
| 1.6 | Лагерь: костёр, музыка, голоса | **High** | 3–4 дня | 1.5 | Тёплый лагерь; ночь; тревога. |
| 1.7 | Нападение/личинка/повозка | **High** | 4–5 дней | 1.6 | Камни/Тиран/личинка/падение; тишина. |
| 1.8 | Последствия/ночь/рассвет | **High** | 3–4 дня | 1.7 | Ветеран; колокол; яд; рассвет. |

**Выход Stage 1:** первый час игры звучит как законченный вертикальный срез.

### 11.3. Stage 2 — Паломничество и финал (High)

| # | Задача | Приоритет | Оценка | Зависимости | Приёмка |
|---:|---|---|---|---|---|
| 2.1 | Дорога/подъём | **High** | 3–4 дня | Stage 0 | Ветер/шаги/храм вдали. |
| 2.2 | Альков/Шифти | **High** | 2–3 дня | 2.1 | Шкатулка; смерть; тишина. |
| 2.3 | Учёный/пещера | **High** | 3–4 дня | 2.2 | Капли/эхо; ранение; побег. |
| 2.4 | Герой/храм | **High** | 3–5 дней | 2.3 | Колокол; захват; порог. |
| 2.5 | Святилище | **High** | 4–6 дней | 2.4 | Алтарь; Тиран; тени; тишина. |
| 2.6 | Оценка/финал | **High** | 3–4 дня | 2.5 | Spell; True Name; Flaw; карточка. |

**Выход Stage 2:** канонический маршрут Первого Кошмара полностью звучит.

### 11.4. Stage 3 — Пост-Кошмар и Лабиринт (Medium)

| # | Задача | Приоритет | Оценка | Зависимости | Приёмка |
|---:|---|---|---|---|---|
| 3.1 | Город/академия/общежитие | **Medium** | 4–6 дней | Stage 0 | 5 сцен; бюрократия/зима/сон. |
| 3.2 | Чёрное море/спуск | **Medium** | 3–4 дня | 3.1 | Вода/статуя/масштаб. |
| 3.3 | Labyrinth First Fragment: 18 зон, ambience | **Medium** | 6–8 дней | 3.2 | Каждая зона имеет профиль; прилив слышен. |
| 3.4 | Labyrinth: музыка 5 cue + слои | **Medium** | 5–7 дней | 3.3 | 3 акта; переходы; тишина. |
| 3.5 | Labyrinth: бой/карапаксы/Эхо | **Medium** | 4–6 дней | 3.4 | Бой читается; Эхо — не человек. |
| 3.6 | Гроза/штормовой прилив | **Medium** | 3–4 дня | 3.5 | Дождь/гром/вода; не глушит шаги. |
| 3.7 | Прилив HUD/предупреждения | **Medium** | 2–3 дня | 3.6 | Звук + визуал; 30 с warning. |

**Выход Stage 3:** Лабиринт звучит как отдельный мир, но контент (враги/спутники) может быть ещё не готов.

### 11.5. Stage 4 — AI Voice (High)

| # | Задача | Приоритет | Оценка | Зависимости | Приёмка |
|---:|---|---|---|---|---|
| 4.1 | Voice manifest + `DialogueLine.voice_id` + `VoiceDirector` | **High** | 2–3 дня | Stage 0 | 1 тестовая реплика играет; субтитр синхронен. |
| 4.2 | Voice bible + 60 якорных реплик | **High** | 3–5 дней | 4.1 | Тембр зафиксирован; 3 персонажа. |
| 4.3 | Полная генерация 226 реплик + 20 барков | **High** | 5–8 дней | 4.2 | Все файлы; QC; LUFS. |
| 4.4 | Spell voice + appraisal/finale | **High** | 2–3 дня | 4.3 | Заклятие звучит; True Name. |
| 4.5 | Интеграция в диалоги/барки | **High** | 3–4 дня | 4.4 | Нет рассинхрона; ducking. |
| 4.6 | QC носителем русского | **High** | 2–4 дня | 4.5 | Ударения/имена; нет галлюцинаций. |

**Выход Stage 4:** персонажи звучат; текст остаётся субтитрами.

### 11.6. Stage 5 — Полировка и доступность (Medium/Low)

| # | Задача | Приоритет | Оценка | Приёмка |
|---:|---|---|---|---|
| 5.1 | Reverb-зоны (улица/пещера/храм/клетка) | **Medium** | 2–3 дня | Пространство слышно. |
| 5.2 | Окклюзия 3D | **Medium** | 2–3 дня | Стены глушат звук; без per-frame. |
| 5.3 | Randomizer/вариации шагов/ударов | **Medium** | 1–2 дня | Нет повторов. |
| 5.4 | Sound captions для важных сигналов | **Medium** | 1–2 дня | Доступность. |
| 5.5 | Титры/атрибуция CC BY | **High** | 0,5 дня | Долг закрыт. |
| 5.6 | Финальный микс/LUFS/true peak | **High** | 2–3 дня | Нет клиппинга; баланс. |
| 5.7 | 10-минутные loop-тесты | **Medium** | 1–2 дня | Нет усталости/щелчков. |
| 5.8 | Оптимизация/профилирование | **Medium** | 2–3 дня | ≤24 голоса; CPU <5%. |

### 11.7. Что делать в первую неделю (практично)

1. Создать `default_bus_layout.tres`; назначить bus трём существующим плеерам и `ConditionFeedback`.
2. Добавить `AudioDirector` + `GameSettings` Voice/Ambience/UI.
3. Подключить UI SFX к меню.
4. Сделать `SurfaceDetector` и 6 поверхностей; проверить на улице/снегу/камне/грязи/костях/дереве.
5. Записать/сгенерировать 20 базовых SFX (шаги, удар, попадание, дверь, подбор, костёр).
6. Сделать 1 музыкальный cue меню и 1 ambience парка; проверить crossfade.
7. Записать результат проверки (что работает, что **NOT TESTED**).

---

## 12. Риски, допущения и критерии приёмки

### 12.1. Риски

| Риск | Вероятность | Влияние | Смягчение |
|---|---|---|---|
| AI-русский звучит неестественно/с акцентом | Высокая | Высокое | Слепой тест 20–30 реплик; 2–3 модели; носитель; при провале — Chatterbox/другой голос. |
| Голос «плывёт» между сценами | Высокая | Высокое | Один voice ID; seed; batch по персонажу; QC; не менять модель. |
| Музыка перегружает игру | Средняя | Высокое | Политика тишины; тесты 10–15 мин; 60–70% без музыки. |
| Лупы щёлкают/устают | Высокая | Среднее | Crossfade; zero-crossing; 10-мин тест; не MP3. |
| Клиппинг/скачки громкости | Средняя | Высокое | LUFS/true peak; лимитер; проверка на динамиках/наушниках. |
| Шины/маршрутизация ломаются при F6 | Средняя | Критическое | `default_bus_layout.tres`; тест F6; запрет fallback в Master. |
| Temp-треки попадут в Git/сборку | Средняя | Высокое | `.gitignore`; ссылки вместо файлов; `docs/audio/reference_playlist.md`; проверка перед коммитом. |
| CC BY файл без атрибуции | Высокая | Среднее | Титры/credits; или заменить на CC0. |
| Слишком много одновременных звуков | Средняя | Среднее | Приоритеты; max_instances; пулы; профилирование. |
| Scope creep (18 зон, все враги) | Высокая | Высокое | Stage gates; не озвучивать маркеры; сначала первый час. |
| Потеря аудиоассетов | Низкая | Высокое | Git LFS; бэкап; manifest; не хранить только в `%TEMP%`. |
| Лицензии AI-моделей | Средняя | Среднее | Реестр; non-commercial флаги; пересмотр при публикации. |

### 12.2. Допущения

- Игра остаётся личным некоммерческим проектом; это влияет на выбор non-commercial моделей и temp-треков.
- Целевая платформа — Windows, Godot 4.7.2, Forward+; аудио — стерео, без surround.
- Основной язык озвучки — русский; английская локализация не входит в первый этап.
- Игрок использует наушники или стереоколонки; моно-совместимость проверяется.
- 18 зон Лабиринта остаются в одной сцене; аудио-зоны — через `Area3D`/триггеры, не через отдельные сцены.
- Спутники/Эхо/враги Лабиринта появятся позже; их VO не блокирует Stage 1–2.

### 12.3. Критерии приёмки (Definition of Done)

- [ ] `default_bus_layout.tres` существует; Master/Music/Ambience/SFX/Voice/UI/Reverb; ни один плеер не остаётся на Master по ошибке.
- [ ] Прямой запуск каждой канонической сцены (F6) не ломает звук.
- [ ] 6 громкостей сохраняются/загружаются; Voice=0 не глушит музыку.
- [ ] Шаги различаются минимум на 6 поверхностях.
- [ ] Боевой минимум: удар/попадание/блок/уклонение/смерть.
- [ ] UI: hover/click/back/confirm/error.
- [ ] Музыка есть в меню, прологе, караване, pilgrim, sanctuary, appraisal, finale.
- [ ] Ambience есть в каждой канонической локации.
- [ ] 226 реплик + выбранные барки озвучены; нет missing.
- [ ] −18 LUFS voice, −20…−18 music, true peak ≤ −1 dBTP.
- [ ] Нет клиппинга/щелчков на 10-минутных лупах.
- [ ] ≤24 одновременных голосов; CPU audio <5%; нет dropouts.
- [ ] CC BY атрибуция закрыта; AI-ассеты в `docs/ASSET_LICENSES.md`.
- [ ] Sound captions/субтитры для важных сигналов.
- [ ] Все проверки записаны; непроверенное — **NOT TESTED**.

---

## 13. Приложения

### 13.1. Именование

| Тип | Шаблон | Пример |
|---|---|---|
| Музыка | `music/<location>/<cue>_<layer>.ogg` | `music/caravan/road_chain.ogg` |
| Ambience | `ambience/<location>/<bed>_<variant>.ogg` | `ambience/labyrinth/z01_wind.ogg` |
| SFX | `sfx/<category>/<event>_<nn>.wav` | `sfx/player/footsteps/snow_01.wav` |
| Голос | `voice/<speaker>/<scene>/<line_id>_v<nn>.ogg` | `voice/sunny/prologue/sip_1_01_v01.ogg` |
| UI | `ui/<event>_<nn>.wav` | `ui/click_01.wav` |
| Cue resource | `resources/audio/music_cues/<id>.tres` | `resources/audio/music_cues/caravan_road.tres` |

### 13.2. Import settings

| Тип | Формат | Настройки |
|---|---|---|
| Музыка | Ogg Vorbis, stereo, 44,1/48 кГц | `loop=true`; quality 0.7–0.9; stream. |
| Ambience | Ogg Vorbis, stereo, 44,1/48 кГц | `loop=true`; quality 0.6–0.8. |
| SFX one-shot | WAV, mono, 48 кГц, 16/24 бит | `loop=false`; `compress/mode=0` (PCM) или QOA; не normalize. |
| SFX loop | Ogg Vorbis, mono/stereo, 48 кГц | `loop=true`; exact loop points. |
| Voice | Ogg Vorbis, mono, 48 кГц, 96–128 kbps | `loop=false`; normalize off; stream. |
| UI | WAV, mono, 48 кГц | `loop=false`; короткий; не normalize. |

### 13.3. Чеклист сцены

- [ ] У сцены есть music cue или осознанная тишина.
- [ ] Есть ambience bed + 1–2 детали.
- [ ] Шаги работают на всех поверхностях сцены.
- [ ] Все интерактивные объекты звучат.
- [ ] Все сюжетные события имеют stinger/тишину.
- [ ] Голосовые реплики синхронизированы с субтитрами.
- [ ] Нет клиппинга/щелчков.
- [ ] При выходе из сцены музыка/ambience корректно затухают.
- [ ] При повторном входе звук не дублируется.
- [ ] F6 не ломает шины.

### 13.4. Политика референсов и temp-треков

- Референсы хранятся **ссылками** в этом документе, не аудиофайлами в Git.
- Temp-треки для личной сборки — в `%TEMP%/opencode/audio_temp` или локальной папке вне репозитория; не коммитить.
- Перед коммитом проверить `git status` на аудиофайлы; в `assets/audio` — только лицензированные/собственные.
- Для каждого ассета — запись в `docs/ASSET_LICENSES.md` (источник, автор, лицензия, URL, дата, ограничения).
- CC BY 4.0 `stone_door_large_001.ogg`: либо добавить титры, либо заменить на CC0/собственный звук. **Открытый долг.**

### 13.5. Глоссарий

| Термин | Значение |
|---|---|
| **Cue** | Музыкальная тема/фрагмент, который запускается как единое целое. |
| **Stem** | Отдельная дорожка внутри cue (бас, струнные, хор). |
| **Layer** | Слой, который включается/выключается по интенсивности. |
| **Stinger** | Короткий акцент на событие. |
| **Bed** | Непрерывный фоновый слой ambience. |
| **One-shot** | Единичный звук, не loop. |
| **Ducking** | Автоматическое приглушение музыки под речь. |
| **Occlusion** | Приглушение звука за препятствием. |
| **Reverb zone** | Зона с собственным reverb-профилем. |
| **LUFS** | Единица громкости; цель для микса. |
| **True peak** | Пиковый уровень после реконструкции; цель ≤ −1 dBTP. |

### 13.6. Открытые решения

| # | Вопрос | Рекомендация по умолчанию |
|---:|---|---|
| 1 | Язык VO | Русский; английский — позже, если понадобится. |
| 2 | Полное VO или частичное | Полное для 226 реплик; 20 барков; остальные — текст. |
| 3 | Кто озвучивает Санни | Один AI-голос + один reference; не менять между сценами. |
| 4 | CC BY каменная дверь | Добавить титры или заменить на CC0/собственный. |
| 5 | Labyrinth First Fragment — канон? | Считать целевой сценой; старый `coral_labyrinth` — sandbox. |
| 6 | Бюджет AI | $30–60/мес на 2–3 месяца; локальные модели бесплатно. |
| 7 | DAW | Reaper (платно, ~$60 личная лицензия) или Audacity (бесплатно); **не установлены**. |
| 8 | Surround | Нет; стерео. |
| 9 | Sound captions | Да, для ключевых неречевых сигналов. |
| 10 | Публикация | Личная сборка; не распространять чужие temp-треки. |

### 13.7. Следующие шаги

1. Утвердить этот ADD как рабочую концепцию (или отметить правки).
2. Выполнить Stage 0 (bus layout + AudioDirector + settings + surface + UI SFX).
3. Сделать 1 музыкальный cue и 1 ambience как пилот; проверить на слух.
4. Записать результаты; обновить `docs/DECISIONS.md` только после фактических изменений.
5. Не коммитить аудио без лицензий; не добавлять чужие треки в репозиторий.

---

## 14. Источники и благодарности

- Внутренние документы проекта: `README.md`, `docs/DECISIONS.md`, `docs/design/first_nightmare_scene_matrix.md`, `docs/design/level_brief_*`, `docs/design/labyrinth_first_fragment_implementation.md`, `docs/art/graphics_audit_and_tooling.md`, `docs/ASSET_LICENSES.md`, `docs/research/post_first_nightmare_dream_realm/*`.
- Код и сцены: `scripts/world/condition_feedback.gd`, `scripts/slice/locations/pilgrim_path.gd`, `scripts/settings/game_settings.gd`, `scripts/slice/slice_director.gd`, `scripts/slice/locations/caravan_site.gd`, `scripts/slice/locations/caravan_site_arrival.gd`, `scripts/campaign/*`, `scripts/locations/forgotten_shore_labyrinth/*`, `scenes/**`.
- Godot 4.7 docs: AudioStreamPlayer, AudioStreamPlayer3D, AudioStreamSynchronized, AudioStreamInteractive, AudioStreamPlaylist, AudioStreamRandomizer, AudioStreamPolyphonic, AudioEffectReverb, AudioServer.
- AI tools: официальные страницы ElevenLabs, Fish Audio, Cartesia, PlayHT, Hume, OpenAI, Google Cloud, Azure, MiniMax, Resemble AI, Stability AI, Suno, Google DeepMind, ACE-Step, Mirelo, Krotos, Sony AI Woosh, HKUST AudioX, Tencent HunyuanVideo-Foley (ссылки в §8–9).
- Музыкальные референсы: ссылки R01–R70 в §3.7.

**Отказ от ответственности:** это не юридическая консультация. Лицензии и условия сервисов меняются; перед публикацией/распространением проверять актуальные terms.

---

*Конец документа.*


---

## 15. Статус реализации (2026-11-01)

Реализован базовый каркас из раздела 1.4:

- шины `Master/Music/Ambience/SFX/Voice/UI/Reverb`, `default_bus_layout.tres`;
- autoload `AudioDirector` с `MusicDirector`, `AmbienceDirector`, `SfxPool`, `VoiceDirector`;
- шесть аудио-настроек и три новых ползунка в меню;
- `SurfaceDetector` и шаги по 9 поверхностям (добавлен coral);
- боевой, интерактивный и UI SFX-минимум;
- музыка/ambience для меню, пролога, караванного марша, лагеря, святилища, appraisal, финала и паломнического пути;
- 18 зон Лабиринта: ambience, интенсивность музыки, tide/storm/one-shot;
- зоны Лабиринта вынесены в `audio_zones.tres`; 18 reverb-профилей;
- 8 музыкальных cue по 3 реальных слоя (`base/pulse/melody`, 24 OGG), включая `finale`;
- `AudioStreamRandomizer` + редкие one-shot в ambience;
- reverb-профили и per-source raycast-окклюзия 3D SFX (listener→source);
- мастер-компрессор, лимитер, `AudioEffectCapture` и LUFS-инструмент;
- pause-политика: музыка/ambience/UI продолжаются, 3D/2D SFX и voice — `stream_paused`;
- typed cue table `resources/audio/audio_cue_library.tres`, `AudioLibrary` только загружает её;
- hover/focus UI-звуки, отдельный ritual cue, финальная тема;
- accessibility: captions важных SFX, mono downmix, full/reduced dynamic range;
- голосовой pipeline (`DialogueLine.voice_id`, вызовы из `DialogueRunner`/`BarkUI`);
- временная озвучка 146 реплик пролога/каравана + 30 барков через Windows SAPI (Microsoft Irina, ru-RU); 83 реплики ещё без файлов.

**Не сделано:** 83 из 229 реплик не озвучены; SAPI-голоса — временные плейсхолдеры, не финальное VO. Окклюзия — одиночный raycast на момент запуска, без многолучевого/динамического уточнения. Все новые звуки — процедурные плейсхолдеры; их художественное качество и баланс **NOT TESTED** на слух. Слепой слуховой тест **NOT TESTED** (нужен человек); протокол — `docs/audio/BLIND_LISTENING_TEST.md`. Музыка/ambience сжаты в OGG, SFX в mono/22,05 кГц; общий объём 47,9 МБ. Проверки: `test_audio_system` 19/19, `test_audio_playback` 7/7, `test_labyrinth_audio` 6/6, `test_game_settings` 6/6, `test_main_menu` 6/6, `test_slice_director` 11/11, `test_caravan_march` 7/7, `test_shadow_sanctuary` 11/11, `test_campaign_flow` 10/10, `test_labyrinth_first_fragment` 13/13. Полный GUT ограничен внешними ошибками `park_street_art.tscn`/`sunny`; аудио-набор зелёный. Это не заменяет ручной аудиотест; в обычном headless воспроизведение отключено, но `test_audio_playback` принудительно проверяет `playing`/`volume_db`/pool/ducking.

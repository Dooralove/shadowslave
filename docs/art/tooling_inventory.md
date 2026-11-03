# Инвентарь графического софта (G1)

**Дата:** 2026-11-01  
**Статус:** установка и настройка выполнены. Графика проекта (сцены, материалы, коллизии, маршруты, настройки) **не изменялась**; Stage 0/1 не начаты.  
**Назначение:** единый источник правды по инструментам, версиям, путям, лицензиям и фактическому статусу.  
**Связанные документы:** `docs/art/graphics_audit_and_tooling.md`, `docs/ASSET_LICENSES.md`, `docs/art/asset_staging_manifest.md`.

Пути записаны через переменные окружения Windows (`%PROGRAMFILES%`, `%USERPROFILE%`, `%APPDATA%`, `%LOCALAPPDATA%`), чтобы не привязывать документ к имени пользователя. Точные пути на текущей машине можно получить командами из §7.

---

## 1. Установлено/настроено в этой сессии

| Инструмент | Версия | Путь | Лицензия | Назначение | Проверка |
|---|---|---|---|---|---|
| **Krita** | 5.3.4.1 (git bd6e8d0) | `%PROGRAMFILES%\Krita (x64)\bin\krita.exe` | GPL-3.0 | 2D-живопись, decals, правка текстур, маски | `krita --version` → `krita 5.3.4.1` |
| **Materialize** | 1.78 (архив `Materialize_1.78.zip`) | `%USERPROFILE%\Tools\Materialize\Materialize.exe` | GPL-3.0 | PBR-карты из изображений: height/normal/AO/roughness/metallic/edge | запуск проверен, процесс стартовал и был закрыт |
| **glTF-Transform CLI** | 4.5.1 | `%APPDATA%\npm\gltf-transform.ps1`; модули — `%APPDATA%\npm\node_modules\@gltf-transform\cli` | MIT | инспекция, optimize, simplify, dedup, prune, resize, KTX2 | `gltf-transform --version` → `4.5.1`; `gltf-transform inspect` на `altar_black_marble.glb` работает |
| **Blender OptiX** | Blender 5.1.1 | `%PROGRAMFILES%\Blender Foundation\Blender 5.1\blender.exe` | GPL-2.0-or-later | GPU-рендер Cycles, bake | `compute_device_type=OPTIX`; OPTIX device `use=True`; CUDA/CPU `use=False` |
| **Blender Node Wrangler** | встроенный аддон | `%APPDATA%\Blender Foundation\Blender\5.1\scripts\addons` (поставка Blender) | GPL-2.0-or-later | ускорение работы с шейдерными графами | `addon_utils.check('node_wrangler')` → `(True, True)` |

Настройки Blender сохранены в `userpref.blend`; при следующем запуске OptiX и Node Wrangler остаются включёнными. Скрипты `assets/environments/nightmare/source/nm_lib.py::setup_render()` дополнительно выставляют `OPTIX` и `scene.cycles.device = "GPU"` на каждый запуск сборщика.

---

## 2. Полный инвентарь (графика)

| Инструмент | Версия | Путь / источник | Лицензия | Роль | Статус |
|---|---|---|---|---|---|
| **Godot Engine** | 4.7.2 stable | `%USERPROFILE%\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe`; обёртка `godot.cmd` | MIT | редактор и runtime | установлен; MCP editor connected |
| **Blender** | 5.1.1 | `%PROGRAMFILES%\Blender Foundation\Blender 5.1\blender.exe` | GPL-2.0-or-later | DCC, Geometry Nodes, remesh, UV, Cycles | установлен; MCP addon 1.8/protocol 15 |
| **Krita** | 5.3.4.1 | `%PROGRAMFILES%\Krita (x64)\bin\krita.exe` | GPL-3.0 | 2D-текстуры и decals | установлен 2026-11-01 |
| **Materialize** | 1.78 | `%USERPROFILE%\Tools\Materialize\Materialize.exe` | GPL-3.0 | PBR-карты | установлен 2026-11-01 |
| **glTF-Transform** | 4.5.1 | `%APPDATA%\npm\gltf-transform.ps1` | MIT | оптимизация GLB | установлен 2026-11-01 |
| **Material Maker** | 1.7 | `%USERPROFILE%\Tools\MaterialMaker_1.7\material_maker_1_7_windows\material_maker.exe` | MIT | процедурные PBR-графы | установлен ранее; экспериментальный |
| **MaterialPilot** | 0.1.0 | `experiments/materialpilot/materialpilot` (gitignored) | Apache-2.0 | автоматизация Material Maker | экспериментальный; не используется |
| **Godot MCP** | 0.6.1 | `addons/godot_mcp`; сервер `npx godot-mcp-server@0.6.1` | MIT | управление редактором/сценами | editor connected; runtime helper не подключается из-за parse errors проекта |
| **GUT** | 9.7.1 | `addons/gut` | MIT | GUT-тесты | установлен; в этой задаче не запускался |
| **Blender MCP addon** | 1.8, protocol 15 | `%APPDATA%\Blender Foundation\Blender\5.1\scripts\addons\blender_mcp.py` | MIT | мост Blender ↔ MCP | проверен вживую; libraries/generators off, telemetry false |
| **mcp-for-blender server** | 2.2.6 | `uvx mcp-for-blender==2.2.6`; закреплён в `opencode.json` и `.mcp.json` | MIT | MCP-сервер Blender | работает при открытом Blender; addon 1.8/protocol 15 |
| **MPFB** | 2.0.18 | `%APPDATA%\Blender Foundation\Blender\5.1\extensions\blender_org\mpfb` | GPL-3.0 (код) | MakeHuman-персонажи | установлен ранее |
| **Node.js** | 24.19.0 | `%PROGRAMFILES%\nodejs\node.exe` | MIT | запуск CLI-инструментов | установлен |
| **npm** | 11.17.0 | `%PROGRAMFILES%\nodejs\npm.ps1` | Artistic-2.0 | менеджер пакетов | установлен |
| **Python** | 3.13.3 | `%SystemDrive%\Python313\python.exe` | PSF-2.0 | скрипты, текстуры, автоматизация | установлен |
| **pip** | 26.1.1 | `%APPDATA%\Python\Python313\site-packages\pip` | MIT | пакеты Python | установлен |
| **uv / uvx** | 0.13.6 | `%SystemDrive%\Python313\Scripts\uv.exe`, `uvx.exe` | MIT/Apache-2.0 | запуск MCP-серверов | установлен |
| **Git** | 2.45.1.windows.1 | `%PROGRAMFILES%\Git\cmd\git.exe` | GPL-2.0 | версии | установлен |
| **Git LFS** | 3.5.1 | `git lfs` | GPL-2.0 | бинарные ассеты | установлен |

---

## 3. Python-пакеты

| Пакет | Версия | Лицензия | Назначение |
|---|---|---|---|
| numpy | 2.3.5 | BSD-3-Clause | массивы, шум, карты высот |
| Pillow | 12.0.0 | HPND | изображения, PNG/JPEG, каналы |
| opencv-python | 5.0.0.93 | Apache-2.0 | обработка изображений, фильтры |
| scipy | 1.17.0 | BSD-3-Clause | научные расчёты, карты |
| scikit-learn | 1.8.0 | BSD-3-Clause | вспомогательная аналитика |
| matplotlib | 3.10.8 | PSF-based | графики/превью |
| imageio-ffmpeg | 0.6.0 | BSD-2-Clause | ffmpeg 7.1 для видео/кадров (CLI `ffmpeg` отдельно не установлен) |
| torch | 2.6.0+cpu | BSD-3-Clause | CPU-инференс; CUDA-сборка не установлена |

Пакеты — инструменты разработки, в поставку игры не входят. Полные тексты лицензий — в `site-packages/<пакет>/...` и на страницах пакетов.

---

## 4. Blender: фактическая конфигурация

Проверено фоновым запуском Blender 5.1.1:

```
COMPUTE OPTIX
DEVICES [('CUDA', False), ('CPU', False), ('OPTIX', True)]
NODE_WRANGLER (True, True)
```

- `Cycles Render Devices` → **OptiX**, устройство `NVIDIA GeForce RTX 3060 Laptop GPU` включено.
- CUDA и CPU выключены для GPU-рендера; CPU остаётся доступен как fallback.
- `Node Wrangler` включён.
- `nm_lib.setup_render()` также выставляет OptiX/GPU на каждый рендер сборщика, поэтому фоновые скрипты не зависят от ручной настройки.

## 4.1. Проектные skills

Лежат в `.opencode/skills/`; OpenCode подхватывает их автоматически (ID = имя папки):

| Skill | Когда использовать | Что внутри |
|---|---|---|
| `graphics-production` | любая графическая работа по Лабиринту | пайплайн Blender/PBR/свет/оптимизация, safety, команды |
| `mcp-operations` | работа через Godot/Blender MCP | статус, скриншоты, безопасные правки, troubleshooting, конфиги |
| `forgotten-shore-art` | канон и арт-дирекшн | 18 зон, прилив, гроза, палитра, запреты, приёмка |
| `texture-toolchain` | текстуры и PBR-карты | Krita/Materialize/glTF-Transform, tiling, packing, импорт |

Глобальные skills не дублировались. Загрузка — через `skill` tool по точному ID.

Krita, Materialize и glTF-Transform не имеют официальных MCP-серверов: они используются как GUI/CLI и описаны в skill `graphics-production`; отдельный MCP для них не добавлялся.

---

## 5. Не установлено / отложено

| Инструмент | Почему не установлен | Бесплатная альтернатива | Когда вернуться |
|---|---|---|---|
| **ComfyUI + SDXL / Flux** | 10–20 ГБ, отдельный CUDA-стек, не нужен для первого арт-прохода; финальный PBR всё равно авторится/запекается | Fooocus, InvokeAI, Automatic1111 | после Stage 2, если понадобятся концепты/черновые текстуры |
| **UVPackmaster 3 / RizomUV** | платные; Blender UV достаточно для трипланарных материалов | Blender `Smart UV Project` / `Pack Islands` | если появятся плотные лайтмапы |
| **GIMP** | Krita + Python/Pillow закрывают живопись и батчи | Krita, Photopea | по необходимости |
| **ImageMagick / отдельный ffmpeg CLI** | Python/Pillow/OpenCV + `imageio-ffmpeg` закрывают задачи | Python-стек | по необходимости |
| **Substance 3D / Quixel / Houdini / ZBrush** | платные/избыточные; Blender + Materialize + Krita достаточно | Blender, Material Maker | не планируется |
| **Modly CLI** | не проверен, неизвестное качество | Blender | не планируется |
| **AI 3D (Tripo/Hunyuan3D/Hyper3D/Meshy)** | платные/кредитные, топология не для финального окружения; в Blender MCP выключены | Blender bmesh/GN | только концепт, по отдельному решению |
| **pymeshlab / open3d / trimesh** | mesh-обработка уже есть в Blender; инспекция GLB — в glTF-Transform | Blender, glTF-Transform | если понадобится автоматический QA вне Blender |
| **KTX-Software (`toktx`)** | KTX2/Basis пока не обязателен; Godot импортирует PNG/JPEG | glTF-Transform `resize`; Godot VRAM compression | при оптимизации текстур |

**Платных программ не покупалось.** Для текущего этапа бесплатного набора достаточно.

---

## 6. Библиотеки ассетов и staging

### 6.1. Poly Haven (CC0 1.0)

Скачано в staging **вне проекта**: `%USERPROFILE%\Tools\asset_staging\polyhaven`.

| ID | Автор | Файлы | Назначение |
|---|---|---|---|
| `coral_ground_02` | Rob Tuytel | diff/nor_gl/arm 2K | коралловый грунт, обнажённое дно |
| `coral_gravel` | Rob Tuytel | diff/nor_gl/arm 2K | гравий, осыпи |
| `coral_mud_01` | Rob Tuytel | diff/nor_gl/arm 2K | ил/грязь |
| `coral_stone_wall` | Dimitrios Savva | diff/nor_gl/arm 2K | коралловый камень |
| `low_tide_rocks` | Dimitrios Savva | diff/nor_gl/arm 2K | мокрые камни отлива |
| `damp_beach_sand` | Dimitrios Savva | diff/nor_gl/arm 2K | влажный песок |
| `coral_fort_wall_01` | Dimitrios Savva, Rico Cilliers | diff/nor_gl/arm 2K | массивная коралловая кладка |
| `coral_fort_wall_02` | Dimitrios Savva | diff/nor_gl/arm 2K | то же, вариант |
| `coral_fort_wall_03` | Dimitrios Savva, Rico Cilliers | diff/nor_gl/arm 2K | то же, вариант |

Итого: **27 файлов, 99 029 607 байт (≈94,4 MiB)**. MD5 сверен с API Poly Haven: **27/27 совпадают**. Манифест с SHA256 и URL — `%USERPROFILE%\Tools\asset_staging\polyhaven\manifest.csv` и `docs/art/asset_staging_manifest.md`.

**В проект не импортировано.** В Godot ничего не добавлено; `.tres` и сцены не менялись. Перенос в `assets/environments/...` — только после Stage 2 и регистрации в `docs/ASSET_LICENSES.md`.

Модели (`coast_land_rocks_*`, `lambis_shell`) и HDRI не скачивались: для первого material-теста достаточно текстур; модели/HDRI — на Stage 2–3.

### 6.2. Другие библиотеки

| Библиотека | Статус | Лицензия | Комментарий |
|---|---|---|---|
| Poly Haven API | доступен (HTTP 200) | CC0 | текстуры/HDRI/модели; органических красных кораллов нет |
| ambientCG API | доступен (HTTP 200) | CC0 | кораллов нет; грязь/камень/металл |
| Sketchfab API | поиск доступен (HTTP 200) | CC0-фильтр | скачивание требует аккаунт/OAuth; только референс |
| Poly Pizza API | HTTP 401 | CC0/CC-BY | не настроен; low-poly, не подходит |

---

## 7. Проверки и команды

| Проверка | Команда | Результат |
|---|---|---|
| Krita | `& "%PROGRAMFILES%\Krita (x64)\bin\krita.exe" --version` | `krita 5.3.4.1 (git bd6e8d0)` |
| Materialize | `Start-Process "%USERPROFILE%\Tools\Materialize\Materialize.exe"` | процесс стартовал; закрыт вручную |
| glTF-Transform | `gltf-transform --version` | `4.5.1` |
| glTF-Transform inspect | `gltf-transform inspect assets\environments\nightmare\temple\altar_black_marble.glb` | работает, читает GLB 2.0 |
| Blender OptiX/Node Wrangler | `blender --background --python-expr ...` | `COMPUTE OPTIX`, OPTIX `use=True`, Node Wrangler `(True, True)` |
| Godot import | `godot --headless --path . --import` | exit 0 |
| Godot MCP | `godot.get_godot_status` | connected, Godot 4.7.2; runtime helper false |
| MCP config | `opencode-cli.exe mcp list` | `blender connected`, `godot connected` (серверы; для Blender tool calls Blender должен быть открыт) |
| Blender MCP | `blender.get_addon_status` | Blender 5.1.1, addon 1.8, protocol 15; libraries/generators off |
| Poly Haven | 27 файлов, MD5 | 0 расхождений |

Точные пути на текущей машине:

```powershell
(Get-Command python).Source
(Get-Command node).Source
(Get-Command git).Source
(Get-Command gltf-transform).Source
(Get-Command godot).Source
Get-ChildItem "$env:PROGRAMFILES" -Directory | Where-Object Name -like 'Krita*'
Get-Item "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe"
Get-Item "$env:USERPROFILE\Tools\Materialize\Materialize.exe"
& "$env:LOCALAPPDATA\Programs\@opencodedesktop\resources\opencode-cli.exe" mcp list
```

Ожидаемо: `✓ blender connected`, `✓ godot connected`.

---

## 8. Лицензионные заметки

- Все перечисленные программы — **инструменты разработки**, в поставку игры не входят.
- GPL-лицензии Blender, Krita и Materialize не означают, что созданные в них игровые ассеты автоматически становятся GPL. Лицензия на конкретный ассет определяется его источником и условиями; для собственных моделей/текстур проекта — решение проекта.
- glTF-Transform (MIT), Godot (MIT), GUT (MIT), Godot MCP (MIT), Blender MCP (MIT) не создают ограничений на игровые данные.
- CC0-текстуры Poly Haven можно использовать без атрибуции; авторы всё равно внесены в manifest и будут внесены в `docs/ASSET_LICENSES.md` при переносе в проект.
- Секреты, токены и `.env` в документ не записаны; абсолютные пользовательские пути заменены переменными окружения.

---

## 9. Итог

- Установлены и проверены: **Krita 5.3.4.1**, **Materialize 1.78**, **glTF-Transform 4.5.1**.
- Настроены: **Blender OptiX**, **Node Wrangler**.
- Скачаны в staging 9 CC0-наборов Poly Haven (27 файлов, ≈94,4 MiB), в проект не импортированы.
- **MCP:** серверы `godot` и `blender` подключены к OpenCode; версии закреплены в `opencode.json` и `.mcp.json` (`godot-mcp-server@0.6.1`, `mcp-for-blender==2.2.6`). Для Blender tool calls Blender должен быть открыт; Godot editor подключён.
- **Skills:** `.opencode/skills/graphics-production`, `mcp-operations`, `forgotten-shore-art`, `texture-toolchain`; подхватываются OpenCode.
- Графика, сцены, материалы, коллизии, маршруты и настройки проекта **не изменялись**. Stage 0/1 не начаты.
- Платные инструменты и ассеты не покупались; ComfyUI/UV-инструменты отложены.

---

## 6. Character Animation: Blender Retarget (2026-11-02)

| Инструмент | Версия | Путь | Лицензия | Назначение | Проверка |
|---|---|---|---|---|---|
| **Blender Retarget extension** | 5.2.0 | `%APPDATA%\Blender Foundation\Blender\5.1\extensions\user_default\retarget` | GPL-3.0-or-later | Ретаргет/бейк персонажных анимаций в Blender | Установлен 2026-11-02 в user extensions; `addon_utils.check("bl_ext.user_default.retarget")` → `(True, True)` |

Инструмент установлен как Blender extension, не входит в поставку игры и не является
рантайм-зависимостью. Источник: https://extensions.blender.org/add-ons/retarget/.

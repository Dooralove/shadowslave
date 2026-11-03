# HUD reference analysis — The Witcher 3 screenshot (2026-11-03)

**Reference:** 1920×1080 screenshot of The Witcher 3 HUD (Russian UI).
**Goal:** keep the project’s coral/bone/bronze language, but move the gameplay
HUD to the reference composition: vitals top-left, minimap top-right, quest
tracker right, quick items bottom-left, control hints bottom-right.

## 1. What the reference contains

| Reference element | Position | What it does |
|---|---|---|
| Wolf medallion + health bar | top-left | player identity, current/max vitality |
| Secondary bar / status icon | under health | stamina / toxicity / active state |
| Context action (“Идти”) | under vitals | current interaction or movement intent |
| Circular minimap + compass | top-right | local terrain, player arrow, nearby markers |
| Region caption (“ОКРУГА”) | under minimap | current area name |
| Quest tracker | right, under minimap | quest title + current objective |
| Quick items (“5 Хлеб”, “2 Бутылка воды”, “Факел”) | bottom-left | carried consumables/tools with counts |
| Control hints (“Ускориться”, “Ведьмачье чутьё”) | bottom-right | real key bindings |
| Performance overlay | top-centre | recording tool, not game HUD; ignored |
| Red line at bottom | bottom edge | video progress bar; ignored |

## 2. Current HUD before this pass

| Component | File | State |
|---|---|---|
| Player vitals | `scenes/ui/vitals_bar.tscn`, `scripts/ui/vitals_bar.gd` | working coral bar, was bottom-left |
| Combat/target bars | `scenes/ui/combat_hud.tscn` | player bottom-left, enemy top-right |
| Objective line | `scenes/ui/objective_line.tscn` | top-left, generic “ЦЕЛЬ” |
| Tide indicator | `scenes/ui/tide_indicator.tscn` | top-right, below enemy panel |
| World markers | `scenes/ui/hud_world_markers.tscn` | in-world diamonds/objective arrow |
| Subtitles | `scenes/quests/gameplay_hud.tscn` | bottom-centre |
| Quest toast | `scripts/ui/quest_toast.gd` | bottom-right |
| Hint | `scripts/ui/gameplay_hud.gd` | top-centre |
| Interaction prompt | scripts/ui/interaction_prompt_ui.gd | bottom-centre |

## 3. Gap matrix

| Reference | Before | Change |
|---|---|---|
| Vitals top-left | bottom-left | `CombatHud.PlayerPanel` moved top-left |
| Circular minimap | absent | new `HudMinimap` + `HudMinimapCanvas`, fed by `MapSystem.minimap_snapshot()` |
| Compass ring | absent | bronze N/E/S/W ring + ticks in `HUDMinimap._draw()` |
| Region caption | absent | `RegionLabel` under minimap |
| Quest tracker right | generic objective top-left | `ObjectiveLine` moved right, right-aligned, quest title used when available |
| Quick items bottom-left | absent | `HudQuickItems`, real `NightmareRunState` counts for bread/water/torch |
| Control hints bottom-right | absent | `HudControlHints`, key labels read from `InputMap` |
| Context action under vitals | bottom-centre prompt | `Prompt` moved under vitals |
| Tide | top-right | kept, moved under quest tracker |
| Time / weather | absent | not ported: the project has a tide cycle, not a time-of-day/weather system |
| Wolf medallion | — | replaced with the project’s coral reliquary medallion |
| Witcher sense | — | no direct equivalent; map/quest hint is the closest existing system |
| Performance overlay / video bar | — | external recording UI; intentionally ignored |

## 4. 1600×900 layout

| Element | Anchor | Rect |
|---|---|---|
| Player vitals | top-left | 20,20–380,150 |
| Context prompt | top-left | 24,158–380,186 |
| Enemy bar | top-centre | 650,20–950,80 |
| Minimap | top-right | 1386,24–1576,236 |
| Quest tracker | top-right | 1240,242–1576,342 |
| Tide indicator | top-right | 1240,352–1576,430 |
| Quick items | bottom-left | 24,746–274,876 |
| Subtitles | bottom-centre | 380,768–1220,872 |
| Quest toast | bottom-right | 1240,670–1576,730 |
| Control hints | bottom-right | 1240,746–1576,876 |

The layout is authored for the project’s 1600×900 `canvas_items` reference.
16:9 scales cleanly; 21:9 leaves extra side room; 4:3 is not validated.

## 5. Implementation

| File | Role |
|---|---|
| `scenes/ui/hud_minimap.tscn` | circular minimap, viewer, compass ring |
| `scripts/ui/hud_minimap.gd` | data refresh, SubViewport update, ring/caption |
| `scripts/ui/hud_minimap_canvas.gd` | local map features, markers, player arrow |
| `assets/ui/hud/minimap_mask.gdshader` | circular alpha mask |
| `scenes/ui/hud_quick_items.tscn` | bottom-left carried-items panel |
| `scripts/ui/hud_quick_items.gd` | real `NightmareRunState` counts |
| `scenes/ui/hud_control_hints.tscn` | bottom-right key hints |
| `scripts/ui/hud_control_hints.gd` | live `InputMap` labels |
| `scenes/quests/gameplay_hud.tscn` | composition of all HUD widgets |
| `scripts/ui/gameplay_hud.gd` | reference layout coordinates |
| `scripts/ui/objective_line.gd` | responsive width + right alignment + quest title |
| `scenes/ui/combat_hud.tscn` | vitals top-left, enemy top-centre |
| `assets/ui/rpg_menu/icons/torch.svg` | quick-item torch icon |

## 6. Data and behavior

- **Minimap** reads `MapSystem.minimap_snapshot()`: current `MapDefinition`,
  player XZ, forward. It draws world-space `MapFeature` polygons and visible
  `MapMarker`s, with quest markers in gold. No second map system is created.
- **Quick items** reads `NightmareRunState.get_item_count()` for
  `provisions`, `water_skin`, `torch`; updates on `item_changed`. It is a
  carried-items display, not a new inventory.
- **Control hints** reads `InputMap.action_get_events()` for `sprint`,
  `interact`, `open_map`; updates once a second if bindings change.
- **Quest tracker** uses the existing `ObjectiveLine` sources
  (`QuestSystem` → `CampaignGuide`), now right-aligned and compact.
- **Context prompt** is the existing `InteractionPromptUI`; only its position
  changed.

## 7. Verification

- `test_hud_reference`: 5/5 tests, 31 asserts.
- `test_ui_demo`, `test_p4_presentation`, `test_combat_hud`,
  `test_vitals_hud`, `test_combat_arena`, `test_larva_enemy`,
  `test_combat_course`: 48/48 tests, 237 asserts.
- Full GUT: 89 scripts, 717/717 tests, 7,849 asserts, exit 0.
- 1600×900 captures: `docs/art/previews/hud_reference/hud_reference_full.png`
  and `hud_reference_subtitles.png`.
- Manual gameplay, 1080p/60 FPS, gamepad and 4:3: **NOT TESTED**.

## 8. Deliberately not ported

- The recording performance overlay and video progress bar are not game UI.
- The exact wolf medallion is replaced by the project’s coral reliquary; no
  Witcher asset is copied.
- Time-of-day/weather icons are not invented: the game has a tide system, and
  the tide indicator remains the authoritative environmental readout.
- Toxicity/adrenaline are not added; the existing stamina bar and status
  systems cover the available data.

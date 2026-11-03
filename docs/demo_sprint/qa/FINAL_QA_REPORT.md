# FINAL QA REPORT — Stage 5 / Release Candidate Validation

Date: 2026-11-03  
Branch: `demo/integration`  
HEAD: `ab8fe304f5b4c9915d1d5579851f1402d2cf8b18`  
Snapshot: **working tree dirty** — 196 changed/untracked paths at validation start (other agents' equipment, loot, world-frame, art and audio work). Results are tied to this dirty tree, not to a clean commit.  
Old Stage 1 report preserved as `docs/demo_sprint/qa/FINAL_QA_REPORT_STAGE1.md`.

> **Post-Stage-5 integration note (2026-11-03):** after this report, Academy playable segment, CutsceneDirector + 5 M1 cutscenes, shared input rebinding/gamepad defaults and authored enemy hit/death clips were integrated at `9c908f5`. Full GUT is **749/749, 8 039 asserts, exit 0**; route 61/61; Academy walkthrough 24/24. A temp release export succeeded and boots headless exit 0 (exe 109,268,480 B, PCK 1,000,473,040 B), but still includes dev tools/MCPRuntime. The manual M1/tech/Academy pass, 1080p/60 and listening test remain **NOT TESTED**. See `BASELINE_RESULTS.md` §15.

## 0. Release verdict

| Gate | Result |
|---|---|
| Gameplay / scenario | **PASS WITH LIMITATIONS** |
| Side quests | **PASS** |
| Characters / animation | **PASS WITH LIMITATIONS** |
| UI | **PASS WITH LIMITATIONS** |
| Save / load | **PASS WITH LIMITATIONS** |
| Zone transitions | **PASS** |
| Performance | **PASS WITH LIMITATIONS** |
| Export build | **PASS WITH LIMITATIONS** |
| Overall release | **FAIL — NOT RELEASE-READY** |

**The build must not be declared fully ready.** The Windows release executable and PCK now exist and boot headlessly, but the validation is still tied to a dirty working tree and there is no continuous human 50–70-minute playthrough on a clean commit. The build also includes dev/QA tooling and `MCPRuntime`; see BUG-017. Release remains blocked by the human pass + clean commit gate, not by the export itself.

---

## 1. Requirement status

| # | Requirement | Status | Evidence |
|---:|---|---|---|
| 1 | Full GUT | **PASS** | 717 tests, 717 pass, 7,849 asserts, exit 0 |
| 2 | Godot runtime | **PASS WITH LIMITATIONS** | Actual menu, M1, tech demo, portals, UI, save/load; cleanup errors noted |
| 3 | Complete main scenario | **PASS WITH LIMITATIONS** | First Nightmare 9/9; finale→P05 5/5; P05→…→Labyrinth 23/23; M1 finale/tech 41/41 |
| 4 | Every side quest | **PASS** | SQ-01…05 161/161; rewards and choice panel verified |
| 5 | Characters and animations | **PASS WITH LIMITATIONS** | 74/74 animation/character tests; placeholder M1 mannequins |
| 6 | Main game interfaces | **PASS WITH LIMITATIONS** | UI tour 8/8; menu/settings/HUD/journal/inventory/map/pause/choice/finale |
| 7 | Save and load | **PASS WITH LIMITATIONS** | F5/F9 15/15; position/flags/currency/enemy respawn; one cleanup error on reload |
| 8 | All zone transitions | **PASS** | Portal chain 23/23; route reachability 18/18, 51/51; route walk 51/51 |
| 9 | Performance | **PASS WITH LIMITATIONS** | 108.8 FPS @1080p; 1,661 draw calls > 1,500 budget; 825 MB VRAM |
| 10 | Exportable build | **PASS WITH LIMITATIONS** | Windows exe + PCK produced; headless boot exit 0; local preset/templates, dirty tree, dev tooling included |

---

## 2. Build and static gates

| Check | Result |
|---|---|
| `godot --headless --path . --import` | exit 0 |
| Full GUT | **717/717, 7,849 asserts, exit 0** |
| `qa_script_audit` | **386 checked, 0 failures** |
| `qa_resource_audit` | **715 checked, 211 scenes, 504 resources, 0 failures** |
| `route_reachability` | **18/18 zones, 51/51 POI** |
| `labyrinth_route_walk` @15 m/s | **51/51 segments**, exit 0 |
| `export_presets.cfg` | local preset created; file is gitignored; `script_export_mode=0` |
| Windows export templates | installed locally under `export_templates/4.7.2.stable` |
| `build/ShadowSlave.exe` | **present** — 109,268,480 bytes |
| `build/ShadowSlave.pck` | **present** — 962,214,296 bytes |
| Exported build boot | **exit 0** (`--headless --quit-after 5`) |

> Note: the earlier full-GUT run failed 5 tests because the editor had stale imported scripts (`get_loot_bags` missing at runtime). After a clean `--import`, the same 717 tests passed. This is a reproducible **tooling/cache risk** for CI: always run `--import` before GUT on a fresh tree.

---

## 3. Actual Godot runtime and main scenario

### 3.1. Main path

| Step | Result |
|---|---|
| Main menu → “После Кошмара · ДЕМО” | **PASS** — actual mouse click; `post_nightmare_started`, beat P05 |
| P05 Jett + mirror | **PASS** — `p05_jett_talked`, `p05_mirror_seen`, `shadow_sight_unlocked` |
| P05→P06→P07→P08→P09→B01→B02→Labyrinth | **PASS** — actual `LevelPortal.activate()` chain, 23/23 checks |
| First Nightmare S00–S15 | **PASS** — campaign tour 9/9 phases, 18 screenshots |
| First Nightmare finale → P05 | **PASS** — ContinueButton 5/5 checks |
| M1 finale Z10 → `PostNightmareFinale` | **PASS** — M1 card and flags |
| M1 finale → tech demo (`ContinueButton`) | **PASS** — sets `demo_mode_full`, spawns at `CampReturn` |
| Tech demo menu entry | **PASS** — `TechDemoButton`, `demo_mode_full`, Z01 |
| Tech finale Z18 | **PASS** — `FinalZone` → finale card, `post_nightmare_completed` |

### 3.2. Scenario harness results

| Harness | Result |
|---|---|
| `qa_campaign_tour` | **9/9 phases**; captures `01_B01_park` … `18_S15_finale` |
| `qa_stage5_menu_m1` | **5/5**; actual M1 menu click |
| `qa_stage5_scenario_chain` | **5/5**; First Nightmare finale → P05 |
| `qa_stage5_portal_chain` | **23/23**; all seven scene transitions |
| `qa_stage4_post_nightmare` | **62/62** |
| `qa_stage4_labyrinth` | **161/161** |
| `qa_stage4_final_save` | **41/41** |
| `qa_stage4_input_combat` | **15/15** |
| `qa_stage4_menu_tech` | **7/7** |
| `qa_stage5_ui_tour` | **8/8** |
| `qa_stage5_cast_capture` | **8/8 captures** |

---

## 4. Side quests

| Quest | Status | Verified |
|---|---|---|
| SQ-01 «Девятый жетон» | **PASS** | token, 3 traces, Theo, `sq_fs_01_complete` |
| SQ-02 «Голос из слепого туннеля» | **PASS** | `echo_polyp` killed, `destroy_polyp=1`, cloak/core, `sq_fs_02_complete` |
| SQ-03 «Правда без лжи» | **PASS** | `QuestChoicePanel` active, truth choice, `sq_fs_03_resolved`, cord/cache |
| SQ-04 «Соляной ящик» | **PASS** | markers/runtime, low tide, levers `[LOW,HIGH,LOW]`, box, +2 shards, chart |
| SQ-05 «Хозяин костяного моста» | **PASS** | Old Shell killed, reward, shell cutter +2 shards |

Base quests also pass: `first_day`, `first_blood`, `azure_blade`, `crystal_cache`, `hunt_pack`, `camp_rest`, `bridge_stand`. Combat E01/E02/E03 pass, including player melee kill and kill credits.

---

## 5. Characters and animations

- Targeted suite: **74/74 tests, 550 asserts** (`test_sunny_animation`, `test_enemy_animation`, `test_animation_lab`, `test_sunny_waking`, `test_sunny_poc`, `test_carapace_enemy`, `test_larva_enemy`, `test_mountain_king`).
- Captures: 18 states for v3 and Nightmare Sunny (`idle/walk/run/attack/hit/guard/dodge/death`, armed idle/guard), plus 8 NPC close-ups.
- P05 Jett, P06 Jet, P07 Nephis silhouette, P09 Cassia/Kasper/Rock, Labyrinth Nephis/Cassia captured.
- **Limitation:** M1 NPCs are mannequin placeholders; some close-ups show simplified/placeholder faces and clipping. This is known A06 scope, not a new release blocker for the demo, but full character polish is **NOT VERIFIED**.
- Nightmare death/armed captures are static poses; the state machine tests cover transitions, not a full animation review.

---

## 6. Interfaces

Verified with actual opening/closing:

| Screen | Status | Notes |
|---|---|---|
| Main menu | **PASS** | M1 and tech-demo entries visible; demo hint fixed |
| Settings | **PASS** | Graphics tab, resolution/vsync/FPS/render scale, reset/back |
| Gameplay HUD | **PASS** | objective, HP, enemy bar, prompt, tide indicator |
| Quest journal | **PASS** | live quests, tracked objective, 2 entries at start |
| Inventory | **PASS WITH LIMITATIONS** | opens and renders; demo item set, not the live run inventory |
| Map | **PASS WITH LIMITATIONS** | 17 locations, route line, player marker; objective text slightly overlaps the “КАРТА РЕГИОНА” header |
| Pause | **PASS** | current objective, resume/settings/controls/credits/menu/quit |
| Choice panel | **PASS** | 3 SQ-03 choices; actual truth selection completed the quest |
| Finale cards | **PASS** | M1 card + Continue; tech finale card |

Known HUD issue: enemy health bar can appear before the enemy is visually revealed (BUG-014, design review). Inventory is explicitly a demo set and not a live inventory test.

---

## 7. Save / load

| Check | Result |
|---|---|
| F5 writes quick save | **PASS** |
| Save payload readable, labyrinth scene path | **PASS** |
| F9 reloads labyrinth | **PASS** |
| Position restored | **PASS** |
| Flags/currency restored | **PASS** |
| Enemy killed after save respawns after load | **PASS** |
| Re-entry runtime rebuild / no duplicate SQ-01 token | **PASS** |
| Checkpoint death / respawn | **PASS** — 1.0 m from checkpoint |
| Loot-bag persistence | **NOT VERIFIED** — no dedicated live pickup + reload test |

A non-fatal engine log error remains on F9 reload: `Can't use get_node() with absolute paths from outside the active scene tree.` The load still completes and state is correct. This should be cleaned up before release (Low/Medium).

---

## 8. Zone transitions and route

- Actual portal chain P05→P06→P07→P08→P09→B01→B02→Labyrinth: **23/23 PASS**.
- `route_reachability`: **18/18 zones, 51/51 POI PASS**.
- `labyrinth_route_walk`: **51/51 segments PASS** at 15 m/s after excluding runtime enemies from the static route audit.
- Fixed low-route false blocks: `SQ02_EchoPolyp` and `SQ05_OldShell` were standing on audit segments; the QA tool now removes `Gameplay/Runtime` and `Gameplay/RuntimeNarrative` collision actors before walking.
- Labyrinth internal transitions / final zone: **PASS**.
- **Limitation:** route walk is a scripted forced-velocity audit, not a human walk; but route reachability and portal chain are independent checks.

---

## 9. Performance

| Scene | Resolution | FPS | Draw calls | Primitives | VRAM |
|---|---|---:|---:|---:|---:|
| Labyrinth first fragment | 1920×1080 | **108.8** | **1,661** | 4,559,053 | 825.2 MB |
| Police precinct (P05) | 1920×1080 | **203.1** | 431 | 185,994 | 1,006.0 MB |
| Black Sea platform (B01) | 1920×1080 | **120.3** | 286 | 319,189 | 419.4 MB |

**Verdict: PASS WITH LIMITATIONS.** FPS and VRAM meet the 60 FPS / <4 GB target on this machine; labyrinth draw calls **1,661 > 1,500 budget** (BUG-011). The measurement is an uncapped focused-window probe, not a human 1080p soak. No optimization was applied in this stage.

---

## 10. Exportable build

- `export_presets.cfg`: local preset “Windows Desktop” created for validation; **gitignored**, not part of the repository. `script_export_mode=0` is required for this tree: binary-token export produced autoload/type-resolution parse errors and a bark-JSON parse error; text mode produced a clean boot.
- Windows `4.7.2.stable` templates installed locally under `%APPDATA%\Godot\export_templates\4.7.2.stable`.
- `build/ShadowSlave.exe` — **109,268,480 bytes**, produced 2026-11-03 15:12.
- `build/ShadowSlave.pck` — **962,214,296 bytes**, produced 2026-11-03 15:12.
- `build/ShadowSlave.exe --headless --quit-after 5` — **exit 0, no script/JSON errors** after switching to text script export.
- **Limitations:** preset is gitignored, templates are machine-local, PCK includes `tools/**`, `tests/**` and the `MCPRuntime` autoload; this is not a clean release package. The build was not exercised on a machine without the project/templates.

**Export gate: PASS WITH LIMITATIONS.** Build exists and boots, but must be regenerated from a clean commit with a release-only export filter.

---

## 11. Known issues / limitations

| ID | Severity | Issue | Status |
|---|---|---|---|
| BUG-001 | Critical | No exportable build/templates | **MITIGATED locally** — exe/PCK built and booted; clean-commit rebuild still required |
| BUG-002 | High | No continuous human 50–70 min playthrough | **OPEN / NOT VERIFIED** |
| BUG-011 | Medium | Labyrinth draw calls 1,661 > 1,500 | **OPEN** |
| BUG-012 / BUG-032 | Medium | Black Sea B01 readability still dark | **OPEN — art pass required** |
| BUG-014 | Low | Enemy HUD bar can appear before reveal | **OPEN — design review** |
| BUG-017 | High | `MCPRuntime` autoload present in project; must not ship | **OPEN** |
| — | Medium | Dirty working tree, 196 paths; no clean RC commit | **OPEN** |
| — | Low | `get_node()` absolute-path cleanup error on F9 reload | **OPEN — non-fatal** |
| — | Low | Engine reflection-probe error on scene transition; 7 texture RIDs leaked at exit | **OPEN — engine/cleanup** |
| — | Low | M1 NPC placeholders / simplified faces; inventory demo set | **PASS WITH LIMITATIONS** |

No new Critical gameplay failure was found in the validated path. The former build blocker is mitigated locally: the Windows build exists and boots. The remaining release blockers are the absent human pass, the dirty/unreproducible tree, and release-only packaging/tooling cleanup.

---

## 12. Escalation to Technical Director (immediate)

1. **A00 — stop the release gate.** Produce a clean commit/worktree for the RC, run `--import` and full GUT, and freeze the hash. The current 196-path dirty tree cannot be treated as a release candidate.
2. **A00 — regenerate the build from the clean commit.** A local build now exists and boots (`build/ShadowSlave.exe` + `.pck`), but the preset/templates are machine-local and gitignored. Rebuild from the clean hash with a release-only export filter; verify the exe on a second machine. BUG-001 is mitigated, not release-closed.
3. **A00 — remove `MCPRuntime` and dev/QA content from release.** BUG-017 is a High release risk; the current PCK includes `tools/**`, `tests/**` and the dev autoload. Exclude them in the export preset and re-test.
4. **A10/TD — run the human 50–70-minute pass.** BUG-002 remains High; scripted harnesses cannot substitute for a human playthrough. Re-run on the clean RC hash.
5. **A07 — B01 readability.** BUG-032 remains visible; the statue/platform are still too dark at spawn. Art pass required.
6. **A07/A10 — draw-call budget.** BUG-011: 1,661 draw calls at 1080p. FPS is currently acceptable, but the budget is exceeded.
7. **A10 — clean up save/load and transition engine errors.** The F9 `get_node()` error and reflection-probe/texture-RID cleanup messages should be removed or explicitly accepted before release.

---

## 13. Evidence

| Artifact | Path |
|---|---|
| Full GUT | `%TEMP%\opencode\stage5_gut_final2.log` |
| Import | `%TEMP%\opencode\stage5_import2.log` |
| Script audit | `%TEMP%\opencode\stage5_audit_final2.log` |
| Resource audit | `%TEMP%\opencode\stage5_resources_final.log` |
| Route reachability | `%TEMP%\opencode\stage5_reach.log` |
| Route walk | `%TEMP%\opencode\stage5_walk_final.log` |
| Campaign tour | `%TEMP%\opencode\stage5_campaign.log`; `stage5_campaign_shots\` |
| Main menu M1 | `%TEMP%\opencode\stage5_menu_m1.log`; `stage5_menu_m1_shots\` |
| Scenario chain | `%TEMP%\opencode\stage5_scenario3.log` |
| Portal chain | `%TEMP%\opencode\stage5_portal.log` |
| Post-nightmare | `%TEMP%\opencode\stage5_post.log`; `stage5_post_shots\` |
| Labyrinth / SQ | `%TEMP%\opencode\stage5_lab.log`; `stage5_lab_shots\` |
| Finale / save | `%TEMP%\opencode\stage5_final.log`; `stage5_final_shots\` |
| Input / F5 / F9 | `%TEMP%\opencode\stage5_input.log`; `stage5_input_shots\` |
| UI tour | `%TEMP%\opencode\stage5_ui.log`; `stage5_ui_shots\` |
| Character captures | `%TEMP%\opencode\stage5_character_shots\` |
| NPC captures | `%TEMP%\opencode\stage5_cast_shots\`, `stage5_npc_shots\` |
| Performance | `%TEMP%\opencode\stage5_perf_final.log`, `stage5_perf_p05_final.log`, `stage5_perf_b01_final.log` |
| Export build | `%TEMP%\opencode\stage5_export7.log`, `stage5_build_boot5.log`; `build/ShadowSlave.exe`, `build/ShadowSlave.pck` |
| Curated screenshots | `docs/demo_sprint/qa/screenshots/stage5/` (16 key moments) |

## 14. Release gate decision

**FAIL — NOT RELEASE-READY.**

The demo content is playable end-to-end, all side quests pass, transitions and route reachability pass, save/load works, the interfaces are usable, and a Windows build now exists and boots headlessly. However, the release candidate is still tied to a dirty working tree, the build includes dev/QA tooling and `MCPRuntime`, and there is no human full playthrough on a clean commit. Until A00 produces a clean release-only build and A10 completes the human pass, the final build must not be announced as ready.

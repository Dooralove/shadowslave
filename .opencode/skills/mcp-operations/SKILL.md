---
name: MCP Operations
description: Use when driving Blender or Godot through MCP — status checks, screenshots, scene inspection, safe edits, batching, and troubleshooting runtime connections.
---

# MCP Operations

## Start every MCP session with status

- Godot: `tools.godot.get_godot_status()` — editor connection, version, project path.
- Godot runtime: `tools.godot.get_runtime_status()` — `playing`, `runtime_helper_connected`, `last_launched`.
- Blender: `tools.blender.get_addon_status()` — Blender version, addon version, protocol, enabled libraries/generators.
- Blender scene: `tools.blender.get_scene_info()` — objects, counts, units before editing.

MCP tools are called inside `execute`:

```js
const status = await tools.godot.get_godot_status();
const blender = await tools.blender.get_addon_status();
return { status, blender };
```

## Godot MCP

### Safe workflow

1. `stop_scene` before editing code/scenes; avoid errors repeating every frame.
2. Inspect first: `read_scene`, `find_nodes`, `scene_tree_dump`, `get_node_properties`, `get_resource_info`.
3. Use `batch_execute` for multi-step edits on the same scene; one undo entry.
4. `set_node_properties` / `add_node` / `attach_script` — never hand-edit `.tscn` text for scene changes.
5. After mutations: `get_errors` + `run_scene` + screenshot/validation.
6. Do not change gameplay geometry, routes, collisions, controller, or shared systems without an explicit request.

### Runtime screenshots

`take_screenshot` requires `run_scene({wait_for_runtime:true})` and a connected `MCPRuntime`. If the runtime helper is not connected:

- Check `get_errors` and `get_console_log` for parse errors.
- Known current blocker: `CampaignGuide` / `StaminaComponent` / `CombatSettings` / `AttackData` parse errors; `SunnyAnimator` null.
- Do **not** “fix” unrelated user code unless asked; use the read-only capture fallback:
  ```powershell
  godot --path . -s tools/audit/location_capture.gd -- --out="$env:TEMP/opencode/shots_coral"
  ```

### Useful editor tools

- `get_project_settings`, `list_settings("rendering")` — renderer/AA/shadow settings.
- `classdb_query` — verify API before writing GDScript.
- `get_scene_node_properties` — full @export values.
- `validate_script` — parse a GDScript file.
- `mcp_undo` / `mcp_redo` — rollback MCP mutations; prefer over manual reverts.

## Blender MCP

### Safe workflow

1. Launch Blender normally (addon auto-starts server on port 9876 by default).
2. `get_addon_status()`; ensure addon 1.8 / protocol 15 and the expected libraries/generators.
3. `get_scene_info()` before changes; use `execute_blender_code` for read-only checks.
4. Production assets are built by **background Blender scripts**, not by interactive MCP edits.
5. Never hardcode shader node names — find by `node.type`.
6. Never hardcode enum identifiers; read `bl_rna.properties[...]` enum items.
7. Material colors go into shader node inputs; `material.diffuse_color` is viewport only.

### Current configuration

- Server command in OpenCode: `uvx mcp-for-blender==2.2.6` (pinned).
- Addon: `%APPDATA%\Blender Foundation\Blender\5.1\scripts\addons\blender_mcp.py`.
- Auto-start: enabled by default (`Scene.blendermcp_auto_start_server = true`).
- SAFE_MODE: Poly Haven/Sketchfab/Poly Pizza libraries and Tripo/Hunyuan3D/Hyper3D/Meshy generators are **off**.
- OptiX and Node Wrangler are enabled; Cycles GPU is available.

### Background build command

```powershell
& "$env:PROGRAMFILES\Blender Foundation\Blender 5.1\blender.exe" `
  --background --factory-startup `
  --python assets/environments/nightmare/source/build_<kit>.py -- --test
```

## Configuration files

- `opencode.json` — `mcp.servers.godot` (`godot-mcp-server@0.6.1`) and `mcp.servers.blender` (`mcp-for-blender==2.2.6`).
- `.mcp.json` — same two servers for Claude/other MCP clients.
- `project.godot` — `MCPRuntime` autoload and `godot_mcp` editor plugin.
- Skills: `.opencode/skills/graphics-production`, `.opencode/skills/mcp-operations`, `.opencode/skills/forgotten-shore-art`.

If a server is not connected after config changes, restart OpenCode/Blender, then run status checks again. Do not add new MCP servers without a user decision.

CLI check on the desktop build:

```powershell
& "$env:LOCALAPPDATA\Programs\@opencodedesktop\resources\opencode-cli.exe" mcp list
```

Expected: `✓ blender connected`, `✓ godot connected`.

## Troubleshooting

| Symptom | Check | Action |
|---|---|---|
| Godot runtime helper false | `get_errors`, `get_console_log` | fix parse errors or use capture script; do not claim runtime tested |
| Godot editor disconnected | `get_godot_status` | open Godot editor; enable `godot_mcp` plugin |
| Blender MCP cannot connect | Blender open? `get_addon_status` | launch Blender; check server on port 9876; auto-start setting |
| `uvx` version drift | `uvx --from mcp-for-blender==2.2.6 python -c "..."` | keep config pinned; restart |
| Screenshot fails | `get_runtime_status` | run scene with `wait_for_runtime:true`; fallback capture |
| Scene edit unexpectedly persists | `mcp_undo_history` | `mcp_undo`; inspect before batch |

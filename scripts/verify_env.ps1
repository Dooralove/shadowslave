# Проверка окружения ShadowSlave. Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File scripts\verify_env.ps1
# Скрипт только читает состояние и запускает headless-проверки. Ничего не устанавливает и не меняет.

$ErrorActionPreference = "Continue"
$project = Split-Path -Parent $PSScriptRoot
$godot = "C:\Users\user\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
$results = @()

function Add-Result($name, $status, $detail) {
    $script:results += [pscustomobject]@{ Check = $name; Status = $status; Detail = $detail }
}

# Инструменты
if (Test-Path $godot) {
    $v = (& $godot --version 2>&1 | Out-String).Trim()
    Add-Result "Godot version" $(if ($v -like "4.7.2*") { "PASS" } else { "FAIL" }) $v
} else {
    Add-Result "Godot version" "FAIL" "не найден: $godot"
}
foreach ($tool in @(
    @{ Name = "Git"; Cmd = { git --version } },
    @{ Name = "Git LFS"; Cmd = { git lfs version } },
    @{ Name = "Node.js"; Cmd = { node -v } },
    @{ Name = "npm"; Cmd = { npm -v } }
)) {
    try { $out = (& $tool.Cmd 2>&1 | Out-String).Trim(); Add-Result $tool.Name "PASS" $out }
    catch { Add-Result $tool.Name "FAIL" $_.Exception.Message }
}

# Проект
Add-Result "project.godot" $(if (Test-Path "$project\project.godot") { "PASS" } else { "FAIL" }) $project
Add-Result "GUT 9.7.1 addon" $(if (Test-Path "$project\addons\gut\plugin.cfg") { "PASS" } else { "FAIL" }) "addons\gut"
Add-Result "Godot MCP addon" $(if (Test-Path "$project\addons\godot_mcp\plugin.cfg") { "PASS" } else { "FAIL" }) "addons\godot_mcp"

# Headless-импорт
$imp = & $godot --headless --editor --path $project --quit 2>&1 | Out-String
$impErr = ($imp | Select-String -Pattern "SCRIPT ERROR|Parse Error|ERROR:" | Measure-Object).Count
Add-Result "Headless editor import" $(if ($impErr -eq 0) { "PASS" } else { "FAIL" }) "errors found: $impErr"

# GUT
$gut = & $godot --headless --path $project -s addons/gut/gut_cmdln.gd -gdir=res://tests -gprefix=test_ -gexit 2>&1 | Out-String
$gutOk = ($LASTEXITCODE -eq 0) -and ($gut -match "All tests passed")
Add-Result "GUT smoke tests" $(if ($gutOk) { "PASS" } else { "FAIL" }) (($gut -split "`n" | Select-String "passed|failed" | Select-Object -Last 1) -replace '\x1b\[[0-9;]*m', '').Trim()

$results | Format-Table -AutoSize | Out-String | Write-Output

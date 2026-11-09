# Сборка Windows-релиза ShadowSlave.
#
# Обязательный шаг — пересборка кэша классов Godot: после ручных правок и
# экспорта `.godot/global_script_class_cache.cfg` иногда теряет HUD-классы
# (`HudMinimap`, `HudQuickItems` и т.п.), и тогда HUD не загружается в игре.
#
# Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File tools/build/export_windows.ps1
#
# `export_presets.cfg` не хранится в Git (локальный конфиг). Ожидаемый пресет:
#   name="Windows Desktop", export_path="build/ShadowSlave.exe"
#   exclude_filter="tests/*, docs/*, tools/audit/*, addons/gut/*, experiments/*"

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Push-Location $root
try {
    Write-Host "[1/3] Пересборка кэша классов..."
    python tools/audit/rebuild_class_cache.py
    if ($LASTEXITCODE -ne 0) {
        throw "rebuild_class_cache.py завершился с кодом $LASTEXITCODE"
    }

    Write-Host "[2/3] Экспорт Windows Desktop..."
    godot --headless --path . --export-release "Windows Desktop" build/ShadowSlave.exe
    if ($LASTEXITCODE -ne 0) {
        throw "Экспорт завершился с кодом $LASTEXITCODE"
    }

    Write-Host "[3/3] Результат:"
    Get-ChildItem build | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize

    Write-Host "Проверка запуска..."
    $process = Start-Process -FilePath "build\ShadowSlave.exe" `
        -ArgumentList "--headless", "--quit" -PassThru -Wait -NoNewWindow
    Write-Host "Boot exit code: $($process.ExitCode)"
    if ($process.ExitCode -ne 0) {
        throw "Экспорт не прошёл boot-тест"
    }
} finally {
    Pop-Location
}

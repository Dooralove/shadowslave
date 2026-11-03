param(
    [string]$Voice = "Microsoft Irina Desktop"
)

# Temporary Windows SAPI voice generation for prologue/caravan + barks.
# Prerequisite:
#   godot --headless --path . --script res://tools/audio/export_voice_lines.gd
# The generated WAVs are placeholders, not final VO.

Add-Type -AssemblyName System.Speech

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$jsonPath = Join-Path $env:APPDATA "Godot\app_userdata\ShadowSlave\voice_lines.json"
if (-not (Test-Path $jsonPath)) {
    throw "Missing $jsonPath. Run export_voice_lines.gd first."
}

$data = Get-Content -Raw -Encoding UTF8 $jsonPath | ConvertFrom-Json
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.SelectVoice($Voice)
$made = 0

foreach ($record in $data.records) {
    $id = [string]$record.id
    $kind = [string]$record.kind
    $speaker = [string]$record.speaker
    $text = [string]$record.text
    if ([string]::IsNullOrWhiteSpace($text)) { continue }

    $relative = if ($kind -eq "bark") { "assets\audio\voice\barks" } else { "assets\audio\voice\lines" }
    $directory = Join-Path $projectRoot $relative
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $path = Join-Path $directory ($id + ".wav")

    $synth.Rate = if ($speaker -eq "narration") { -1 } elseif ($speaker -eq "sunny") { 1 } else { 0 }
    $synth.SetOutputToWaveFile($path)
    $synth.Speak($text)
    $made++
}

$synth.SetOutputToNull()
$synth.Dispose()
Write-Output "Generated $made SAPI voice placeholders."

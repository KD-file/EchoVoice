# EchoVoice - environment setup (Windows / PowerShell)
# Creates a Python virtual environment and installs the backend dependencies
# listed in Dependencies_Environment/requirements.txt.

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Venv = Join-Path $Root ".venv"
$Requirements = Join-Path $Root "Dependencies_Environment\requirements.txt"
$Py = Join-Path $Venv "Scripts\python.exe"

if (-not (Test-Path $Py)) {
    Write-Host "[1/3] Creating virtual environment at $Venv"
    python -m venv $Venv
}

Write-Host "[2/3] Installing Python dependencies from $Requirements"
& $Py -m pip install --upgrade pip
& $Py -m pip install -r $Requirements

Write-Host "[3/3] Ensuring ffmpeg is available (needed to decode webm/opus browser recordings)"
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
}

Write-Host "Done. Next: .\Build_Config_Scripts\run_backend.ps1"
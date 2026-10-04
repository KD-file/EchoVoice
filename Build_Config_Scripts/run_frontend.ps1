# EchoVoice - serve the frontend on port 5500.
# The backend (run_backend.ps1) must be running too; the page calls its API.
#
#   FRONTEND_PORT  listen port, default 5500
#   FRONTEND_BIND  bind address, default 127.0.0.1

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$SiteDir = Join-Path $Root "Source_Code"
$Python = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) { $Python = "python" }

if (-not $env:FRONTEND_PORT) { $env:FRONTEND_PORT = "5500" }
if (-not $env:FRONTEND_BIND) { $env:FRONTEND_BIND = "127.0.0.1" }

$Index = Join-Path $SiteDir "index.html"
if (-not (Test-Path $Index)) {
    throw "index.html not found in $SiteDir"
}

Write-Host "Serving $SiteDir"
Write-Host "FRONTEND_BIND = $env:FRONTEND_BIND"
Write-Host "FRONTEND_PORT = $env:FRONTEND_PORT"
Write-Host ""
Write-Host "Open http://$($env:FRONTEND_BIND):$($env:FRONTEND_PORT)/index.html"
Write-Host "Use Chrome or Edge - the Web Speech API that transcribes when HuBERT is"
Write-Host "off is not available in Firefox. The backend must be running on port 8000"
Write-Host "(see run_backend.ps1). Press Ctrl+C to stop."
Write-Host ""

& $Python -m http.server $env:FRONTEND_PORT --bind $env:FRONTEND_BIND --directory $SiteDir
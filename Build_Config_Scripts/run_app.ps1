# EchoVoice - start both servers and open the app.
# Run from anywhere:  .\Build_Config_Scripts\run_app.ps1
#
# Starts the FastAPI backend (port 8000) and a static frontend server (port 5500),
# waits for both to answer, then opens the app in your default browser.
#
#   ECHOVOICE_ENABLE_ASR   1 = load HuBERT, 0/unset = browser Web Speech API
#   PORT                  backend port, default 8000
#   FRONTEND_PORT         frontend port, default 5500

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Python = Join-Path $Root ".venv\Scripts\python.exe"
if (-not (Test-Path $Python)) { $Python = "python" }

if (-not $env:PORT) { $env:PORT = "8000" }
if (-not $env:FRONTEND_PORT) { $env:FRONTEND_PORT = "5500" }
if (-not $env:FRONTEND_BIND) { $env:FRONTEND_BIND = "127.0.0.1" }

# Load echovoice.env (must happen before the backend reads its variables).
$EnvFile = Join-Path $PSScriptRoot "echovoice.env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and $line -notmatch "^#") {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2 -and -not [Environment]::GetEnvironmentVariable($parts[0])) {
                Set-Item -Path "Env:$($parts[0])" -Value $parts[1].Trim()
            }
        }
    }
}
if (-not $env:ECHOVOICE_ENABLE_ASR) { $env:ECHOVOICE_ENABLE_ASR = "0" }
if (-not $env:ECHOVOICE_CORS_ORIGINS) { $env:ECHOVOICE_CORS_ORIGINS = "*" }

$BackendUrl = "http://127.0.0.1:$($env:PORT)"
$FrontendUrl = "http://$($env:FRONTEND_BIND):$($env:FRONTEND_PORT)/index.html"

Write-Host "EchoVoice"
Write-Host "  ASR engine   = $(if ($env:ECHOVOICE_ENABLE_ASR -eq '1') { 'HuBERT (backend)' } else { 'browser Web Speech API' })"
Write-Host "  backend      = $BackendUrl"
Write-Host "  frontend     = $FrontendUrl"
Write-Host ""

# ---- backend ----
Write-Host "Starting backend..."
$backend = Start-Process -FilePath $Python `
    -ArgumentList "-m", "uvicorn", "app:app", "--app-dir", (Join-Path $Root "Source_Code"),
                  "--host", "0.0.0.0", "--port", $env:PORT `
    -WorkingDirectory $Root -PassThru -WindowStyle Hidden

# ---- frontend ----
Write-Host "Starting frontend..."
$frontend = Start-Process -FilePath $Python `
    -ArgumentList "-m", "http.server", $env:FRONTEND_PORT,
                  "--bind", $env:FRONTEND_BIND,
                  "--directory", (Join-Path $Root "Source_Code") `
    -WorkingDirectory $Root -PassThru -WindowStyle Hidden

# ---- wait for both ----
$deadline = (Get-Date).AddSeconds(90)
$backendReady = $false
$frontendReady = $false
while ((Get-Date) -lt $deadline -and (-not $backendReady -or -not $frontendReady)) {
    if (-not $backendReady) {
        try {
            $h = Invoke-RestMethod -Uri "$BackendUrl/api/health" -TimeoutSec 5
            $backendReady = $true
            Write-Host "  backend ready: status=$($h.status) asr_enabled=$($h.asr_enabled)"
        } catch { }
    }
    if (-not $frontendReady) {
        try {
            $f = Invoke-WebRequest -Uri $FrontendUrl -TimeoutSec 5 -UseBasicParsing
            if ($f.StatusCode -eq 200) { $frontendReady = $true; Write-Host "  frontend ready" }
        } catch { }
    }
    if (-not $backendReady -or -not $frontendReady) { Start-Sleep -Seconds 2 }
}

if (-not $frontendReady) { Write-Warning "Frontend did not answer yet; it may still be starting." }
if (-not $backendReady) { Write-Warning "Backend did not answer yet. If ASR is enabled the model may still be loading." }

Write-Host ""
Write-Host "Opening $FrontendUrl"
Start-Process $FrontendUrl
Write-Host ""
Write-Host "Both servers are running in the background."
Write-Host "  backend  pid $($backend.Id)"
Write-Host "  frontend pid $($frontend.Id)"
Write-Host "Stop them with:  .\Build_Config_Scripts\stop_app.ps1"
Write-Host "Press Ctrl+C to exit this script (servers keep running)."

while ($true) { Start-Sleep -Seconds 3600 }
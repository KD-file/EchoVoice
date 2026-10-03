# EchoVoice - start the FastAPI ASR backend on port 8000.
# See echovoice.env.example for the configurable environment variables.
#
#   ECHOVOICE_ENABLE_ASR    1 = load the HuBERT acoustic model, 0/unset = skip it
#                           entirely and let the browser Web Speech API transcribe.
#                           Set to 1 to switch back to the HuBERT pipeline.
#   ECHOVOICE_MODEL_DIR     folder saved by trainer.save_model() ("hubert-bcs")
#   ECHOVOICE_CORS_ORIGINS  comma-separated allowed origins, default "*"
#   PORT                    listen port, default 8000

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$AppDir = Join-Path $Root "Source_Code"
$Python = Join-Path $Root ".venv\Scripts\python.exe"
$DefaultModel = Join-Path $Root "hubert-bcs"

# Load the completed configuration (echovoice.env) if present. Values here
# are applied only when the corresponding environment variable isn't already
# set, and before the inline defaults below.
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

if (-not (Test-Path $Python)) { $Python = "python" }
if (-not $env:ECHOVOICE_MODEL_DIR) { $env:ECHOVOICE_MODEL_DIR = $DefaultModel }
if (-not $env:ECHOVOICE_ENABLE_ASR) { $env:ECHOVOICE_ENABLE_ASR = "0" }
if (-not $env:ECHOVOICE_CORS_ORIGINS) { $env:ECHOVOICE_CORS_ORIGINS = "*" }
$Port = if ($env:PORT) { $env:PORT } else { "8000" }

Write-Host "ECHOVOICE_ENABLE_ASR   = $env:ECHOVOICE_ENABLE_ASR  (1 = HuBERT loaded, 0 = browser Web Speech API)"
Write-Host "ECHOVOICE_MODEL_DIR    = $env:ECHOVOICE_MODEL_DIR"
Write-Host "ECHOVOICE_CORS_ORIGINS = $env:ECHOVOICE_CORS_ORIGINS"
Write-Host "PORT                   = $Port"

& $Python -m uvicorn app:app --app-dir $AppDir --host 0.0.0.0 --port $Port
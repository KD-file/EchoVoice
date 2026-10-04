# EchoVoice - stop the servers started by run_app.ps1 / run_backend.ps1.
# Kills whatever is listening on the backend and frontend ports.
#
#   PORT           backend port, default 8000
#   FRONTEND_PORT  frontend port, default 5500

$ErrorActionPreference = "SilentlyContinue"

if (-not $env:PORT) { $env:PORT = "8000" }
if (-not $env:FRONTEND_PORT) { $env:FRONTEND_PORT = "5500" }

foreach ($port in @($env:PORT, $env:FRONTEND_PORT)) {
    $listeners = Get-NetTCPConnection -LocalPort $port -State Listen
    if (-not $listeners) {
        Write-Host "port $port : not running"
        continue
    }
    foreach ($l in $listeners) {
        $pid_ = $l.OwningProcess
        $proc = Get-Process -Id $pid_
        Stop-Process -Id $pid_ -Force
        Write-Host "port $port : stopped pid $pid_ ($($proc.ProcessName))"
    }
}

Write-Host "Done."
# EchoVoice - install ffmpeg on Windows.
# Required so the backend can decode the webm/opus clips the browser's
# MediaRecorder produces (the /api/transcribe decode path in app.py).

winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements

if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    ffmpeg -version
} else {
    Write-Warning "ffmpeg not found on PATH - restart the terminal and check winget output."
}
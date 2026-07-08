# Run PakeUp Admin on Windows.
# Debug builds are blocked by Windows Smart App Control on many PCs.
# This script builds and launches the Release executable instead.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$releaseExe = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\pakeup_admin.exe"

Write-Host "Building PakeUp Admin (Windows Release)..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path $releaseExe)) {
  Write-Error "Release executable not found: $releaseExe"
}

Write-Host "Starting PakeUp Admin..." -ForegroundColor Green
Start-Process -FilePath $releaseExe -WorkingDirectory (Split-Path $releaseExe)

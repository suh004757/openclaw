param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

New-Item -ItemType Directory -Force -Path (Join-Path $root "data/config") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $root "data/workspace") | Out-Null

docker compose up -d clawdbot-gateway
if ($LASTEXITCODE -ne 0) {
  throw "docker compose up failed"
}

Write-Host "Gateway started."
Write-Host "Health URL: http://127.0.0.1:$($env:OPENCLAW_GATEWAY_PORT ?? '18789')/healthz"

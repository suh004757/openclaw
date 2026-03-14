$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$requiredDirs = @(
  "data/config",
  "data/config/identity",
  "data/config/agents/main/agent",
  "data/config/agents/main/sessions",
  "data/workspace"
)

foreach ($dir in $requiredDirs) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

if (-not (Test-Path ".env")) {
  Copy-Item ".env.example" ".env"
  Write-Host "Created Clawdbot_Docker/.env from .env.example"
  Write-Host "Edit Clawdbot_Docker/.env, then rerun start.ps1"
  exit 0
}

docker compose up -d --build clawdbot-gateway
Write-Host "Gateway started: http://127.0.0.1:18789"

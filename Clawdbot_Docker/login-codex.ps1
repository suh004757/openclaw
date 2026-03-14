param(
  [string]$AgentId = "iran-war",
  [string]$ModelRef = "openai-codex/gpt-5.4"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Starting OpenAI Codex OAuth login..."
& docker compose run --rm --no-deps clawdbot-cli models auth login --provider openai-codex
if ($LASTEXITCODE -ne 0) {
  throw "Codex OAuth login failed."
}

Write-Host "Setting model for agent '$AgentId' to '$ModelRef'..."
& docker compose run --rm --no-deps clawdbot-cli models set $ModelRef --agent $AgentId
if ($LASTEXITCODE -ne 0) {
  throw "Failed to set model '$ModelRef' for agent '$AgentId'."
}

Write-Host "Current model status:"
& docker compose run --rm --no-deps clawdbot-cli models status --agent $AgentId
exit $LASTEXITCODE

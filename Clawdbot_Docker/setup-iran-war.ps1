param(
  [string]$AgentId = "iran-war"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$containerWorkspace = "/home/node/.openclaw/workspace-$AgentId"
$containerAgentDir = "/home/node/.openclaw/agents/$AgentId/agent"

function Invoke-ClawbotCli {
  param([string[]]$CliArgs)

  & docker compose run --rm clawdbot-cli @CliArgs
  if ($LASTEXITCODE -ne 0) {
    throw "clawdbot-cli command failed: $($CliArgs -join ' ')"
  }
}

function Test-AgentExists {
  param([string]$Id)

  $json = & docker compose run --rm clawdbot-cli agents list --json 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $json) {
    return $false
  }

  try {
    $parsed = $json | ConvertFrom-Json -Depth 32
    foreach ($agent in $parsed.agents) {
      if ($agent.id -eq $Id) {
        return $true
      }
    }
  } catch {
    return $false
  }

  return $false
}

if (-not (Test-AgentExists -Id $AgentId)) {
  Invoke-ClawbotCli -CliArgs @(
    "agents",
    "add",
    $AgentId,
    "--workspace",
    $containerWorkspace,
    "--agent-dir",
    $containerAgentDir,
    "--non-interactive"
  )
}

Invoke-ClawbotCli -CliArgs @(
  "agents",
  "set-identity",
  "--agent",
  $AgentId,
  "--name",
  "Iran War Briefing",
  "--emoji",
  "🛰️"
)

if ($env:IRAN_WAR_MODEL_REF) {
  Invoke-ClawbotCli -CliArgs @("models", "set", $env:IRAN_WAR_MODEL_REF, "--agent", $AgentId)
}

if ($env:IRAN_WAR_BIND_TELEGRAM -eq "1") {
  Invoke-ClawbotCli -CliArgs @("agents", "bind", "--agent", $AgentId, "--bind", "telegram")
}

if ($env:IRAN_WAR_BIND_WHATSAPP -eq "1") {
  Invoke-ClawbotCli -CliArgs @("agents", "bind", "--agent", $AgentId, "--bind", "whatsapp")
}

Write-Host "Configured agent '$AgentId'."
Write-Host "Workspace: $containerWorkspace"
Write-Host "Agent dir: $containerAgentDir"
if ($env:IRAN_WAR_MODEL_REF) {
  Write-Host "Model set to: $($env:IRAN_WAR_MODEL_REF)"
} else {
  Write-Host "Model not pinned. Configure later if needed:"
  Write-Host "./cli.ps1 models set <provider/model> --agent $AgentId"
}
Write-Host "Codex OAuth login:"
Write-Host "./cli.ps1 models auth login --provider openai-codex"

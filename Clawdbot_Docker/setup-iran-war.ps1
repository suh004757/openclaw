param(
  [string]$AgentId = "iran-war"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

function Invoke-ClawbotCli {
  param([string[]]$CliArgs)

  & docker compose run --rm clawdbot-cli @CliArgs
  if ($LASTEXITCODE -ne 0) {
    throw "clawdbot-cli command failed: $($CliArgs -join ' ')"
  }
}

function Get-AgentExists {
  param([string]$ConfigPath, [string]$Id)

  if (-not (Test-Path $ConfigPath)) {
    return $false
  }

  try {
    $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json -Depth 32
    if ($null -eq $cfg.agents -or $null -eq $cfg.agents.list) {
      return $false
    }

    foreach ($agent in $cfg.agents.list) {
      if ($agent.id -eq $Id) {
        return $true
      }
    }
  } catch {
    Write-Warning "Could not parse $ConfigPath. Proceeding with CLI setup."
  }

  return $false
}

$configDir = Join-Path $root "data/config"
$workspaceDir = Join-Path $configDir "workspace-$AgentId"
$configPath = Join-Path $configDir "openclaw.json"
$templateDir = Join-Path $root "iran-war"

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

if (-not (Get-AgentExists -ConfigPath $configPath -Id $AgentId)) {
  Invoke-ClawbotCli -CliArgs @("agents", "add", $AgentId)
}

New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
Copy-Item (Join-Path $templateDir "SOUL.md") (Join-Path $workspaceDir "SOUL.md") -Force
Copy-Item (Join-Path $templateDir "AGENTS.md") (Join-Path $workspaceDir "AGENTS.md") -Force
Copy-Item (Join-Path $templateDir "USER.md") (Join-Path $workspaceDir "USER.md") -Force

Invoke-ClawbotCli -CliArgs @("agents", "set-identity", "--agent", $AgentId, "--name", "Iran War Briefing", "--emoji", "🛰️")

if ($env:IRAN_WAR_MODEL_REF) {
  Invoke-ClawbotCli -CliArgs @("models", "set", $env:IRAN_WAR_MODEL_REF, "--agent", $AgentId)
}

Write-Host "Configured agent '$AgentId'."
Write-Host "Workspace: $workspaceDir"
if ($env:IRAN_WAR_MODEL_REF) {
  Write-Host "Model set to: $($env:IRAN_WAR_MODEL_REF)"
} else {
  Write-Host "Model not set. Configure it later with:"
  Write-Host "./cli.ps1 models set <provider/model> --agent $AgentId"
}

param(
  [string]$AgentId = "iran-war",
  [string]$Cron = "0 9 * * *",
  [string]$Timezone = "Asia/Seoul"
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

$dailyPrompt = @"
Compute today's absolute date and D+N since 2026-02-28. Refresh only currently verifiable facts. Produce a 3-line executive summary first, then the full iran-war briefing using the workspace bootstrap files. Update scenario probabilities, add confidence labels for dynamic facts, and finish with both Yeong-a and Junhyeok action decisions.
"@

if (-not $env:IRAN_WAR_TELEGRAM_TARGET -and -not $env:IRAN_WAR_WHATSAPP_TARGET) {
  throw "Set IRAN_WAR_TELEGRAM_TARGET and/or IRAN_WAR_WHATSAPP_TARGET in .env before installing cron jobs."
}

if ($env:IRAN_WAR_TELEGRAM_TARGET) {
  $telegramArgs = @(
    "cron", "add",
    "--name", "Iran War Daily Telegram",
    "--cron", $Cron,
    "--tz", $Timezone,
    "--session", "isolated",
    "--agent", $AgentId,
    "--message", $dailyPrompt,
    "--announce",
    "--channel", "telegram",
    "--to", $env:IRAN_WAR_TELEGRAM_TARGET
  )
  Invoke-ClawbotCli -CliArgs $telegramArgs
}

if ($env:IRAN_WAR_WHATSAPP_TARGET) {
  $whatsAppArgs = @(
    "cron", "add",
    "--name", "Iran War Daily WhatsApp",
    "--cron", $Cron,
    "--tz", $Timezone,
    "--session", "isolated",
    "--agent", $AgentId,
    "--message", $dailyPrompt,
    "--announce",
    "--channel", "whatsapp",
    "--to", $env:IRAN_WAR_WHATSAPP_TARGET
  )
  Invoke-ClawbotCli -CliArgs $whatsAppArgs
}

Write-Host "Installed daily iran-war cron jobs."

param(
  [string]$AgentId = "iran-war",
  [string]$Reason = "Urgent war-briefing trigger",
  [switch]$Telegram,
  [switch]$WhatsApp
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

$message = "Urgent iran-war briefing. Trigger reason: $Reason. Compute today's absolute date and D+N since 2026-02-28, refresh dynamic facts with confidence labels, include a 3-line summary and full briefing, then finish with Yeong-a and Junhyeok action decisions."

$sendTelegram = $Telegram -or (-not $Telegram -and -not $WhatsApp -and $env:IRAN_WAR_TELEGRAM_TARGET)
$sendWhatsApp = $WhatsApp -or (-not $Telegram -and -not $WhatsApp -and $env:IRAN_WAR_WHATSAPP_TARGET)

if ($sendTelegram -and -not $env:IRAN_WAR_TELEGRAM_TARGET) {
  throw "IRAN_WAR_TELEGRAM_TARGET is not set."
}

if ($sendWhatsApp -and -not $env:IRAN_WAR_WHATSAPP_TARGET) {
  throw "IRAN_WAR_WHATSAPP_TARGET is not set."
}

if ($sendTelegram) {
  $telegramArgs = @(
    "agent",
    "--agent", $AgentId,
    "--message", $message,
    "--deliver",
    "--reply-channel", "telegram",
    "--reply-to", $env:IRAN_WAR_TELEGRAM_TARGET
  )
  Invoke-ClawbotCli -CliArgs $telegramArgs
}

if ($sendWhatsApp) {
  $whatsAppArgs = @(
    "agent",
    "--agent", $AgentId,
    "--message", $message,
    "--deliver",
    "--reply-channel", "whatsapp",
    "--reply-to", $env:IRAN_WAR_WHATSAPP_TARGET
  )
  Invoke-ClawbotCli -CliArgs $whatsAppArgs
}

Write-Host "Triggered urgent iran-war briefing."

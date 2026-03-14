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

$generatePrompt = @"
Urgent iran-war briefing trigger: $Reason

Requirements:
- Refresh only currently verifiable dynamic facts.
- Use SOUL.md, AGENTS.md, and USER.md as the governing contract.
- Produce the full emergency briefing and write it to briefings/latest.md.
- Update briefings/latest.meta.json and write an archive copy under briefings/archive.
- Keep the output broad, but end with Yeong-a and Junhyeok action calls.
- Keep confidence labels for uncertain facts.
- Reply with a short confirmation summary after writing the files.
"@

$dispatchPrompt = @"
Read briefings/latest.md from the iran-war workspace and output that file's content as the final answer.
Do not recompute, rewrite, or add commentary.
If the file is missing, say that the latest urgent briefing file is missing.
"@

Invoke-ClawbotCli -CliArgs @(
  "agent",
  "--agent", $AgentId,
  "--session-id", "iran-war-daily",
  "--message", $generatePrompt
)

$sendTelegram = $Telegram -or (-not $Telegram -and -not $WhatsApp -and $env:IRAN_WAR_TELEGRAM_TARGET)
$sendWhatsApp = $WhatsApp -or (-not $Telegram -and -not $WhatsApp -and $env:IRAN_WAR_WHATSAPP_TARGET)

if ($sendTelegram) {
  Invoke-ClawbotCli -CliArgs @(
    "agent",
    "--agent", $AgentId,
    "--message", $dispatchPrompt,
    "--deliver",
    "--reply-channel", "telegram",
    "--reply-to", $env:IRAN_WAR_TELEGRAM_TARGET
  )
}

if ($sendWhatsApp) {
  Invoke-ClawbotCli -CliArgs @(
    "agent",
    "--agent", $AgentId,
    "--message", $dispatchPrompt,
    "--deliver",
    "--reply-channel", "whatsapp",
    "--reply-to", $env:IRAN_WAR_WHATSAPP_TARGET
  )
}

Write-Host "Triggered urgent iran-war briefing."

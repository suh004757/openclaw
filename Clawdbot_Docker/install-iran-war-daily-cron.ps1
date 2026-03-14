param(
  [string]$AgentId = "iran-war",
  [string]$GenerateCron = "0 9 * * *",
  [string]$TelegramDispatchCron = "1 9 * * *",
  [string]$WhatsAppDispatchCron = "2 9 * * *",
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

$generatePrompt = @"
Today, produce the iran-war daily briefing for the dedicated workspace.

Requirements:
- Refresh only currently verifiable dynamic facts.
- Use the workspace bootstrap files SOUL.md, AGENTS.md, and USER.md as the governing contract.
- Keep the briefing broad in scope: frontline, diplomacy, energy, QR/Qatar, China, North Korea, and rumor separation.
- Final purpose is still the two action questions for Yeong-a and Junhyeok.
- Write the final outbound briefing to briefings/latest.md.
- Write metadata to briefings/latest.meta.json with date, D+N, scenario probabilities, and both action calls.
- Also write an archive copy to briefings/archive/<timestamp>.md.
- The file content in briefings/latest.md must contain:
  1. a 3-line executive summary
  2. the full briefing
  3. the final Yeong-a and Junhyeok action calls
- If facts remain uncertain, keep them marked with confidence labels instead of forcing certainty.
- Reply with a short confirmation summary after writing the files.
"@

$telegramDispatchPrompt = @"
Read briefings/latest.md from the iran-war workspace and output that file's content as the final answer.
Do not recompute, rewrite, summarize again, or add extra commentary.
If the file is missing, say that today's briefing file is missing.
"@

$whatsAppDispatchPrompt = $telegramDispatchPrompt

Invoke-ClawbotCli -CliArgs @(
  "cron", "add",
  "--name", "Iran War Daily Generate",
  "--cron", $GenerateCron,
  "--tz", $Timezone,
  "--session", "session:iran-war-daily",
  "--agent", $AgentId,
  "--message", $generatePrompt,
  "--no-deliver"
)

if ($env:IRAN_WAR_TELEGRAM_TARGET) {
  Invoke-ClawbotCli -CliArgs @(
    "cron", "add",
    "--name", "Iran War Daily Telegram Dispatch",
    "--cron", $TelegramDispatchCron,
    "--tz", $Timezone,
    "--session", "isolated",
    "--agent", $AgentId,
    "--message", $telegramDispatchPrompt,
    "--announce",
    "--channel", "telegram",
    "--to", $env:IRAN_WAR_TELEGRAM_TARGET
  )
}

if ($env:IRAN_WAR_WHATSAPP_TARGET) {
  Invoke-ClawbotCli -CliArgs @(
    "cron", "add",
    "--name", "Iran War Daily WhatsApp Dispatch",
    "--cron", $WhatsAppDispatchCron,
    "--tz", $Timezone,
    "--session", "isolated",
    "--agent", $AgentId,
    "--message", $whatsAppDispatchPrompt,
    "--announce",
    "--channel", "whatsapp",
    "--to", $env:IRAN_WAR_WHATSAPP_TARGET
  )
}

Write-Host "Installed daily iran-war cron jobs."
Write-Host "Generate: $GenerateCron ($Timezone)"
if ($env:IRAN_WAR_TELEGRAM_TARGET) {
  Write-Host "Telegram dispatch: $TelegramDispatchCron"
}
if ($env:IRAN_WAR_WHATSAPP_TARGET) {
  Write-Host "WhatsApp dispatch: $WhatsAppDispatchCron"
}

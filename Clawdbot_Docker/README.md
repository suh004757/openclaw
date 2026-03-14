# Clawdbot Docker

This folder provides a local Docker setup inside the repo using `clawdbot`-style naming while running the current OpenClaw container build.

## 1) Requirements

- Docker Desktop or Docker Engine with Compose v2
- At least 2 GB RAM recommended for the first image build
- PowerShell on Windows

## 2) Initial setup

```powershell
cd Clawdbot_Docker
Copy-Item .env.example .env
```

Fill at least these values in `.env`:

- `OPENCLAW_GATEWAY_TOKEN`: a long random token
- at least one model key such as `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, or `OPENROUTER_API_KEY`
- any channel token you plan to use
- any Codex/OpenAI OAuth variables you want passed into the container

Defaults:

- UI URL: `http://127.0.0.1:18789`
- bind mode: `loopback`

If you want to access the UI from another device on your network, set `OPENCLAW_GATEWAY_BIND=lan`.

## 3) Start

```powershell
./start.ps1
```

The first run may take a while because it builds the image.

## 3.5) Install the `iran-war` agent

This repo now includes a ready-made `iran-war` agent template:

- `Clawdbot_Docker/iran-war/SOUL.md`
- `Clawdbot_Docker/iran-war/AGENTS.md`
- `Clawdbot_Docker/iran-war/USER.md`

To create the agent and copy the templates into the mounted OpenClaw workspace:

```powershell
./setup-iran-war.ps1
```

If you already know the exact model ref you want for this agent, add it to `.env` first:

```env
# Example only
IRAN_WAR_MODEL_REF=openai/gpt-5.3
```

If you leave `IRAN_WAR_MODEL_REF` unset, the script creates the agent and leaves the model choice for later.

## 4) Common commands

Start the gateway:

```powershell
docker compose up -d clawdbot-gateway
```

Tail logs:

```powershell
docker compose logs -f clawdbot-gateway
```

Run CLI commands:

```powershell
./cli.ps1 dashboard --no-open
./cli.ps1 config get gateway.auth.token
./cli.ps1 channels status --probe
./cli.ps1 agents list
./cli.ps1 models status --agent iran-war
```

Stop everything:

```powershell
docker compose down
```

## 4.5) Daily and urgent `iran-war` briefings

Set delivery targets in `.env`:

```env
IRAN_WAR_TELEGRAM_TARGET=123456789
IRAN_WAR_WHATSAPP_TARGET=+821012345678
```

Install the daily 09:00 KST cron jobs:

```powershell
./install-iran-war-daily-cron.ps1
```

Trigger an urgent briefing immediately:

```powershell
./trigger-iran-war-brief.ps1 -Reason "Qatar air defense alert"
```

Or force only one channel:

```powershell
./trigger-iran-war-brief.ps1 -Reason "Oil spike" -Telegram
./trigger-iran-war-brief.ps1 -Reason "QR suspended flights" -WhatsApp
```

## 5) Folder layout

- `data/config`: OpenClaw config and session data
- `data/workspace`: agent workspace files
- `iran-war`: ready-to-copy briefing-agent bootstrap files

## 6) Useful environment variables

- `OPENCLAW_GATEWAY_TOKEN`
- `OPENCLAW_GATEWAY_BIND`
- `OPENAI_API_KEY`
- `ANTHROPIC_API_KEY`
- `GEMINI_API_KEY`
- `OPENROUTER_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `DISCORD_BOT_TOKEN`
- `SLACK_BOT_TOKEN`
- `SLACK_APP_TOKEN`
- `CLAUDE_AI_SESSION_KEY`
- `CLAUDE_WEB_SESSION_KEY`
- `CLAUDE_WEB_COOKIE`

Optional build extras:

- `OPENCLAW_DOCKER_APT_PACKAGES=ffmpeg git`
- `OPENCLAW_INSTALL_BROWSER=1`
- `OPENCLAW_INSTALL_DOCKER_CLI=1`
- `IRAN_WAR_MODEL_REF=<provider/model>`
- `IRAN_WAR_TELEGRAM_TARGET=<chat-id>`
- `IRAN_WAR_WHATSAPP_TARGET=<phone-or-jid>`

## 7) OAuth and tokens

- OpenAI/Codex: add the official environment variables your setup uses to `.env`
- Claude web session: use `CLAUDE_AI_SESSION_KEY`, `CLAUDE_WEB_SESSION_KEY`, and `CLAUDE_WEB_COOKIE`
- Channel integrations: add the matching channel tokens to `.env`

If you do not want secrets stored in `.env`, set them in the current PowerShell session before running `docker compose` or `./start.ps1`.

# HANDOFF

## Purpose
- Keep `Clawdbot_Docker/` as a separate operational folder inside the `openclaw` repo.
- This folder is a personal Docker setup bundle, separated so additional purpose-specific Docker folders can be added later.
- The current target agent is a dedicated `iran-war` briefing agent.

## Current Structure
- `Clawdbot_Docker/compose.yaml`
- `Clawdbot_Docker/start.ps1`
- `Clawdbot_Docker/cli.ps1`
- `Clawdbot_Docker/setup-iran-war.ps1`
- `Clawdbot_Docker/install-iran-war-daily-cron.ps1`
- `Clawdbot_Docker/trigger-iran-war-brief.ps1`
- `Clawdbot_Docker/iran-war/SOUL.md`
- `Clawdbot_Docker/iran-war/AGENTS.md`
- `Clawdbot_Docker/iran-war/USER.md`

## Design Principles
- `Clawdbot_Docker/` lives inside the parent repo but is treated as a personal operations folder.
- What should move through git: config, prompts, scripts.
- What should not move through git: `.env`, sessions, OAuth state, runtime data.
- Nothing is automatically pushed upstream. Changes stay in the fork unless a PR is created.
- `sync fork` is only for bringing upstream changes into the fork.

## Git / Ignore Policy
`Clawdbot_Docker/.gitignore` was added for these reasons:
- ignore `.env`
- ignore `data/config/*`
- ignore `data/workspace/*`
- keep only `.gitkeep` files

Intent:
- keep personal tokens, OAuth state, sessions, and runtime data out of git
- keep Docker setup files and agent prompt files portable through git

## iran-war Agent Goal
This agent is not meant to be a generic war-news summarizer. Its daily purpose is to answer these two questions:
1. For Youngah in Qatar, should the recommendation be `Move immediately / Stay prepared / Hold position`?
2. For Junhoek in Korea, should the recommendation be `Move immediately / Stay prepared / Hold position`?

## iran-war Prompt Design
### SOUL.md
- 2026 Iran-US war geopolitical intelligence analyst
- Korean-only responses
- fact-based and probability-based reasoning
- mark unknown items as `Unconfirmed`
- separate military success from political termination
- treat political termination as heavily dependent on Iranian regime choices
- separate Trump market messaging from actual battlefield assessment
- describe Qatar as ¡°well-defended but still repeatedly targetable¡±
- distinguish deliberate strikes on Iran from debris/fallout events
- treat Chinese mediation contact as a `Scenario B` accelerator
- distinguish Iranian president statements from IRGC decision authority
- prohibit:
  - liability-shifting advice language
  - emotional reassurance
  - hard claims like `it is safe` / `it is dangerous`
  - turning unverified claims into fixed facts

### AGENTS.md
Fixed top structure:
1. `Situation (facts only)`
2. `Assessment (probability-based)`
3. `Implication for stakeholders`

Fixed section order:
- `?? Frontline Status`
- `?? New Variables`
- `?? QR / Qatar`
- `??? Hormuz / Energy`
- `???? China Position`
- `???? North Korea`
- `?? Key Indicators Table`
- `?? Next 48-72 Hours`
- `?? Today¡¯s Judgment`
- `?? Youngah Action Call`
- `?? Junhoek Action Call`

Tracked items:
- Al Udeid Air Base
- Ras Laffan LNG
- Strait of Hormuz
- Qatar Airways Crew City
- Mojtaba public appearance status
- Iranian missile launch rate (`vs D+1 %`)
- QR flight count (`vs normal 580/day %`)
- Korean government charter / evacuation status
- Trump-Xi summit countdown
- RMB settlement negotiation status

Confidence levels:
- `?? Confirmed`
- `?? Unconfirmed`
- `?? Rumor`

Scenarios:
- `A Short-Term End`
- `B Mid-Term Pause`
- `C Long Grind`
- `D Escalation`
- total must always equal 100%

Scenario triggers:
- Iran presents war-ending terms ¡æ `A +5%`
- China mediation contact confirmed ¡æ `B +10%`
- Mine-laying confirmed ¡æ `C +5%`
- Trump-Xi summit collapse ¡æ `C/D up`
- Attempt to remove Mojtaba ¡æ `D +10%`
- Official US munitions shortage statement ¡æ `B +10%`

Action-call format:
- `?? [Youngah/Junhoek] Action Call: [Move immediately / Stay prepared / Hold position]`
- `Reason: 1 sentence`
- `Trigger: 1-2 conditions that would change the call`

Defaults:
- Youngah: `Stay prepared`
- Junhoek: `Hold position`

### USER.md
Youngah:
- QR Qatar base, Korean national
- currently in Doha
- already returned to Doha
- Crew City B, Bin Mahmoud, Doha
- risk frame: prioritize avoiding irreversible outcomes

Junhoek:
- currently in Korea
- onboarding onto Microsoft Project
- monitors Youngah¡¯s situation and provides information

Fixed watchpoints:
- timing of QR normalization
- whether Youngah needs to evacuate after returning to Doha
- Trump-Xi summit (`2026-03-31` to `2026-04-02`)
- whether Hormuz reopens

## Automation Plan
- manual trigger: `D+[number] briefing`
- scheduled daily briefing: `09:00 KST`
- channels: `Telegram + WhatsApp`
- format: `3-line summary + full briefing`
- urgent triggers:
  - oil move of `$10+`
  - Qatar air raid warning
  - QR suspension / resumption
  - official Mojtaba statement
  - major Trump Truth Social post

## Telegram Status
- Telegram bot token has been created
- target group chat id has been confirmed
- group ID:
  - `-1003418184270`
- group name:
  - `IRANWAR_brief`

Note:
- do not store the actual bot token in this file
- the token belongs in `.env` as `TELEGRAM_BOT_TOKEN`

## Model / Auth Decisions
There was earlier discussion between GPT-family API usage and Codex OAuth.
Current direction:
- prefer `openai-codex` OAuth
- do not rely on a standard OpenAI API key for this setup yet

Important:
- Codex OAuth is not pasted into `.env`
- it must be authenticated through the login command
- command:
  - `./cli.ps1 models auth login --provider openai-codex`

## Environment Variable Decisions
- `.env` is filled manually with personal values
- `OPENCLAW_GATEWAY_TOKEN` is a user-defined gateway token
- Telegram values:
  - `TELEGRAM_BOT_TOKEN`
  - `IRAN_WAR_TELEGRAM_TARGET=-1003418184270`
- sensitive values do not go into git

## Docker Timeline
### Original Goal
- run OpenClaw gateway through Docker Compose inside `Clawdbot_Docker`
- attach the `iran-war` agent on top of that runtime

### Problems Observed
At first Docker Desktop was unstable or not fully running.
Then Docker data was moved to `D:` and retried.

Repeated failures then appeared:
- `ghcr.io/openclaw/openclaw:latest` failed to run
- `node:24-bookworm` failed to run
- repeated `exec format error`

At one point, inspection showed these files as zero-byte files:
- `/usr/local/bin/node`
- `/usr/local/bin/docker-entrypoint.sh`

That suggests Docker was storing corrupted Linux image layers.

### Later Confirmed State
- `docker run --rm hello-world` worked
- but `node:24-bookworm` continued to fail, hang, or behave inconsistently
- as a result, the OpenClaw Docker path was paused

### Current Assessment
- this does not look like a `Clawdbot_Docker` design problem
- it looks more like a Docker Desktop / WSL / image execution layer problem
- a non-Docker local runtime may be the more practical fallback

## compose.yaml History
There was one round of `Clawdbot_Docker/compose.yaml` edits to work around the official `ghcr.io/openclaw/openclaw:latest` image.
However, the `latest` image also appeared broken around entrypoint/user handling, and neither the remote image nor the local build path became stable.

Therefore `compose.yaml` should be reviewed again before relying on it in a fresh environment.
Recommended validation order on a new machine:
1. `docker run --rm hello-world`
2. `docker run --rm node:24-bookworm node -v`
3. only continue with `Clawdbot_Docker` if both succeed

## Migration Strategy for a New PC
This chat session itself does not transfer automatically.
The practical artifacts from this conversation are:
- `Clawdbot_Docker/iran-war/SOUL.md`
- `Clawdbot_Docker/iran-war/AGENTS.md`
- `Clawdbot_Docker/iran-war/USER.md`
- `Clawdbot_Docker/setup-iran-war.ps1`
- `Clawdbot_Docker/install-iran-war-daily-cron.ps1`
- `Clawdbot_Docker/trigger-iran-war-brief.ps1`
- this file: `Clawdbot_Docker/iran-war/HANDOFF.md`

On a new PC, the following must be redone:
- create a fresh `.env`
- re-enter the Telegram bot token
- log in with Codex OAuth again
- continue with Docker only if Docker is healthy
- otherwise switch to a local Node runtime

## Recommended Restart Order
### If retrying the Docker path
1. `docker run --rm hello-world`
2. `docker run --rm node:24-bookworm node -v`
3. confirm both commands work
4. start the gateway from `Clawdbot_Docker`
5. run `./setup-iran-war.ps1`
6. run `./cli.ps1 models auth login --provider openai-codex`

### If switching to local runtime
1. confirm Node / pnpm are available
2. run OpenClaw locally
3. attach the `iran-war` prompt files
4. authenticate Codex OAuth
5. connect Telegram

## Security Notes
- do not store real API keys, real OAuth session files, or real tokens in this document
- the existing `.env` had real secrets at various points, so a new environment should always inject fresh values
- do not commit real secrets to git

## Summary
- Goal: build a dedicated `iran-war` briefing agent
- Prompt and action-call framework is already written into files
- Telegram group ID is confirmed
- Codex OAuth direction is chosen
- Docker is blocked by image execution-layer instability
- local runtime remains the most practical fallback if Docker continues failing

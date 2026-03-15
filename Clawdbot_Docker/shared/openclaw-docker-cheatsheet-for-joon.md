# OpenClaw Docker Cheat Sheet for Joon

## The one-sentence model

**The container is replaceable; `~/.openclaw` is the real machine state; `~/.openclaw/workspace` is the agent’s home.**

## What must persist

Persist these on the host:

- `~/.openclaw/openclaw.json`
- `~/.openclaw/credentials/`
- `~/.openclaw/agents/.../sessions/`
- `~/.openclaw/media/`
- `~/.openclaw/shared/`
- `~/.openclaw/workspace/`

Do **not** rely on the container filesystem for important data.

## Best default Docker stance

- use `docker-setup.sh`
- bind-mount OpenClaw state
- publish gateway to `127.0.0.1` only
- use `restart: unless-stopped`
- store secrets in `.env` / env vars / SecretRefs
- back up before updates

## Minimal mount mental model

| Path | Meaning | Persistence |
|---|---|---|
| `/home/node/.openclaw` | config + credentials + sessions + media + shared | must persist |
| `/home/node/.openclaw/workspace` | agent home/memory | must persist |
| `/home/node/.cache/ms-playwright` | browser downloads | persist if you use browser tool |
| container filesystem | runtime layer | disposable |

## Typical Docker commands

```bash
./docker-setup.sh

docker compose up -d
docker compose build

docker compose run --rm openclaw-cli dashboard --no-open
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli channels login

curl -fsS http://127.0.0.1:18789/healthz
curl -fsS http://127.0.0.1:18789/readyz

openclaw logs --follow
docker compose logs -f openclaw-gateway

openclaw backup create --verify

openclaw update status
openclaw update
```

## Browser rule of thumb

- `openclaw` profile = best default managed browser
- `user` profile = attach to real signed-in Chrome session
- `chrome-relay` = extension attach-tab flow
- in Docker, persist Playwright/browser downloads if you do browser automation a lot

Install Chromium for Dockerized Playwright:

```bash
docker compose run --rm openclaw-cli \
  node /app/node_modules/playwright-core/cli.js install chromium
```

## Safe update flow

```bash
openclaw backup create --verify
git pull
docker compose build
docker compose up -d
curl -fsS http://127.0.0.1:18789/readyz
openclaw status --deep
```

## Safe troubleshooting flow

```bash
docker compose ps
docker compose logs -f openclaw-gateway
openclaw logs --follow
openclaw health --json
```

## Joon’s current real structure

Observed on this machine:

- `/home/node/.openclaw/openclaw.json`
- `/home/node/.openclaw/workspace`
- `/home/node/.openclaw/shared`
- `/home/node/.openclaw/credentials`
- `/home/node/.openclaw/agents/.../sessions`

That is already the right structure. Keep it. Wrap Docker around it.

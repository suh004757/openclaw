# OpenClaw Docker Operations Guide for Joon

## Executive summary

If you run OpenClaw in Docker, think in **three layers**:

1. **Docker image/container** = replaceable runtime.
2. **`~/.openclaw/`** = durable OpenClaw state, config, credentials, sessions, media, logs, and shared files.
3. **`~/.openclaw/workspace/`** = the agent’s "home" and editable memory/project area.

For day-to-day operations, the safest mental model is:

- **Containers are cattle**: rebuild/recreate them freely.
- **`~/.openclaw` is your real state**: bind-mount it from the host and back it up.
- **The workspace is part of your long-term memory**: keep it private, versioned, and separate from credentials.
- **Gateway owns channels**: WhatsApp/Telegram sessions live with the gateway state, not in the image.
- **Browser behavior in Docker is special**: the managed browser is separate from your personal browser, and Playwright/browser downloads need explicit persistence if you want them to survive container recreation.

For Joon’s current machine, the live layout already follows OpenClaw’s default model:

- Config/state root: `/home/node/.openclaw`
- Main workspace: `/home/node/.openclaw/workspace`
- Shared folder: `/home/node/.openclaw/shared`
- Sessions: `/home/node/.openclaw/agents/.../sessions`
- Credentials: `/home/node/.openclaw/credentials`

That is the right structure to preserve when moving into Docker.

---

## 1. First principles: Docker architecture as it matters for OpenClaw

### 1.1 The pieces

For OpenClaw, Docker usually means a setup like this:

- **Image**: a built snapshot of the OpenClaw runtime
- **Container**: a running instance of that image
- **Bind mounts / volumes**: host-backed storage so OpenClaw state survives rebuilds and restarts
- **Compose stack**: a repeatable definition of the gateway container and helper CLI container

OpenClaw docs describe two Docker patterns:

1. **Containerized Gateway**
   - the full gateway runs in Docker
   - state is bind-mounted back to the host
2. **Agent Sandbox**
   - the gateway may run on the host, but tool execution for sessions runs in Docker sandboxes

Those are related, but not the same thing.

### 1.2 What the gateway actually is

OpenClaw’s architecture centers on **one long-lived gateway**:

- it owns messaging surfaces like WhatsApp and Telegram
- it exposes WebSocket + HTTP control endpoints
- it stores session state and credentials under `~/.openclaw`
- it serves the Control UI on the gateway port (default `18789`)

Important invariant from the docs: **one gateway per host** is the owner of channel sessions. In practice, that means you should not treat channel auth as stateless or easy to duplicate across multiple simultaneously active containers.

### 1.3 What should feel disposable vs durable

A good rule:

**Disposable**
- containers
- image layers
- ephemeral tmp files inside the container filesystem
- sandbox containers

**Durable**
- `~/.openclaw/openclaw.json`
- `~/.openclaw/credentials/`
- `~/.openclaw/agents/<agentId>/sessions/`
- `~/.openclaw/media/`
- `~/.openclaw/workspace/`
- optional shared content under `~/.openclaw/shared/`

If you remember only one thing, remember this:

> Never store important OpenClaw state only inside the container filesystem.

---

## 2. The recommended OpenClaw Docker deployment patterns

## 2.1 Easiest official path: `docker-setup.sh`

OpenClaw’s Docker docs recommend starting with:

```bash
./docker-setup.sh
```

That script does the high-level setup for you:

- builds locally or pulls a remote image
- runs onboarding
- starts the gateway with Docker Compose
- generates a gateway token into `.env`

That is the best beginner path because it aligns with the shipped assumptions in the docs.

### Why this matters

It means the default OpenClaw Docker story is not "invent your own Compose file from scratch." It is closer to:

- use the provided setup flow first
- then customize mounts, images, browser persistence, sandboxing, or extra packages later

## 2.2 Manual Compose pattern

The docs also show the manual flow:

```bash
docker build -t openclaw:local -f Dockerfile .
docker compose run --rm openclaw-cli onboard
docker compose up -d openclaw-gateway
```

Use this if you want more explicit control over builds and container lifecycle.

## 2.3 VPS / VM pattern

For Hetzner/GCP-style installs, the docs recommend the same architectural shape:

- gateway in Docker
- host bind mounts for config + workspace
- usually loopback-only published port
- access through SSH tunnel

Typical pattern from docs:

```yaml
volumes:
  - ${OPENCLAW_CONFIG_DIR}:/home/node/.openclaw
  - ${OPENCLAW_WORKSPACE_DIR}:/home/node/.openclaw/workspace
ports:
  - "127.0.0.1:${OPENCLAW_GATEWAY_PORT}:18789"
restart: unless-stopped
```

That is a very sane default for a single-user or small private deployment.

## 2.4 Sandbox pattern

OpenClaw can also use Docker for **tool sandboxing**, separately from whether the gateway itself runs in Docker.

Key distinction:

- **Gateway in Docker** = containerized OpenClaw runtime
- **Session sandboxing** = tools run in isolated containers for safety

The docs default sandboxing to non-main sessions when enabled, and default the sandbox workspace away from your real host workspace unless you explicitly allow read-write access.

That is good security design and worth keeping.

---

## 3. Operational workflows that actually appear in OpenClaw docs

These are not generic Docker tips; they are workflows that the OpenClaw docs explicitly support.

## 3.1 Onboard and start

```bash
./docker-setup.sh
```

Then open:

```text
http://127.0.0.1:18789/
```

If needed, fetch dashboard link again:

```bash
docker compose run --rm openclaw-cli dashboard --no-open
```

## 3.2 Run CLI commands from the helper container

Examples from docs:

```bash
docker compose run -T --rm openclaw-cli gateway probe
docker compose run -T --rm openclaw-cli devices list --json
```

The `-T` is recommended for automation/CI so you avoid pseudo-TTY noise.

## 3.3 Configure channels in Docker

Examples from docs:

```bash
docker compose run --rm openclaw-cli channels login
docker compose run --rm openclaw-cli channels add --channel telegram --token "<token>"
```

This is an important pattern: you generally use the **CLI container** to manipulate the durable OpenClaw state mounted from the host.

## 3.4 Recover from pairing / unauthorized issues

The docs give this flow:

```bash
docker compose run --rm openclaw-cli dashboard --no-open
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli devices approve <requestId>
```

## 3.5 Health and diagnostics

Shallow probes:

```bash
curl -fsS http://127.0.0.1:18789/healthz
curl -fsS http://127.0.0.1:18789/readyz
```

Authenticated deep health snapshot:

```bash
docker compose exec openclaw-gateway node dist/index.js health --token "$OPENCLAW_GATEWAY_TOKEN"
```

Live logs:

```bash
openclaw logs --follow
```

In Docker, you will usually combine both mental models:

- `docker compose logs -f openclaw-gateway` for container stdout/stderr
- `openclaw logs --follow` for OpenClaw’s structured internal log stream

## 3.6 Backup

OpenClaw has a first-class backup command:

```bash
openclaw backup create --verify
```

Also useful:

```bash
openclaw backup create --no-include-workspace
openclaw backup create --only-config
openclaw backup verify ./backup.tar.gz
```

This is better than improvising ad hoc tar commands because the backup command knows about OpenClaw’s config/state/workspace layout.

## 3.7 Update

Docs-supported update path:

```bash
openclaw update
openclaw update status
```

For source-based/Dockerized deployments on a VM, docs also describe the rebuild path:

```bash
git pull
docker compose build
docker compose up -d
```

Both matter:

- `openclaw update` is the first-class product path
- `git pull && docker compose build && up -d` is the practical Docker VM path when you are running from a checkout

---

## 4. How to reason about mounts and state: workspace vs `~/.openclaw` vs container filesystem

This is the most important operational concept.

## 4.1 `~/.openclaw/` = OpenClaw system state

Per docs, `~/.openclaw/` contains:

- `openclaw.json` config
- credentials / OAuth / tokens
- sessions
- media
- logs and runtime state
- shared folders
- device pairing data
- channel auth state

On Joon’s machine, this is already true. Right now there are real examples of:

- `/home/node/.openclaw/openclaw.json`
- `/home/node/.openclaw/credentials/whatsapp/...`
- `/home/node/.openclaw/credentials/telegram-pairing.json`
- `/home/node/.openclaw/agents/main/sessions`
- `/home/node/.openclaw/media/inbound`
- `/home/node/.openclaw/shared`

So in Docker, **this whole tree is the state you care about**.

## 4.2 `~/.openclaw/workspace/` = the agent’s home

OpenClaw’s workspace docs are very explicit:

- the workspace is the agent’s home
- it is the default working directory
- it contains files like `AGENTS.md`, `SOUL.md`, `USER.md`, `TOOLS.md`, `memory/`, and optional `skills/`
- it is separate from `~/.openclaw/` config/credentials/sessions

That sounds contradictory at first because the default workspace lives *inside* `~/.openclaw`. The clean way to understand it is:

- `~/.openclaw` is the broader state root
- `~/.openclaw/workspace` is the human-editable sub-tree meant for memory and files
- you should conceptually separate it from credentials and machine state, even if the default path is nested under the same top-level directory

## 4.3 Container filesystem = ephemeral runtime layer

Anything you install or create only inside the container filesystem can disappear when the container is rebuilt or recreated.

The Docker VM runtime docs explicitly warn:

> Installing binaries inside a running container is a trap.

That applies to:

- OS packages
- helper binaries used by skills
- ad hoc browser/tooling installs
- random runtime tweaks not captured in Dockerfile or mounted storage

If you need it to survive, do one of these:

1. **Bake it into the image**
2. **Persist it via bind mount or volume**
3. **Store it under durable OpenClaw state if that is the right semantic home**

## 4.4 Recommended mount model

For a normal Docker deployment, preserve at least these:

### Minimum

- host `~/.openclaw` -> container `/home/node/.openclaw`
- or, if using the split pattern from docs:
  - host config dir -> `/home/node/.openclaw`
  - host workspace dir -> `/home/node/.openclaw/workspace`

### Optional but useful

- named volume for `/home/node`
- extra host mounts for source repos, tools, or caches

### Why `/home/node` persistence is optional, not primary

The docs allow `OPENCLAW_HOME_VOLUME` to persist `/home/node`, but they still keep the normal config/workspace bind mounts.

That is the right priority order:

- **Primary truth**: mounted config/workspace/state
- **Secondary convenience**: named home volume for caches, browser downloads, tool state

## 4.5 A clean mental model

Use this table.

| Area | What it is | Should persist? | How |
|---|---|---:|---|
| Container filesystem | Runtime layer from image | No | Rebuild anytime |
| `/home/node/.openclaw` | OpenClaw durable state | Yes | Bind mount |
| `/home/node/.openclaw/workspace` | Agent home/memory/project files | Yes | Bind mount or git backup |
| `/home/node/.cache/ms-playwright` | Browser downloads/cache | Usually yes | home volume or dedicated mount |
| `/usr/local/bin` inside image | installed binaries | Yes, but via image | Bake into Dockerfile |
| Sandbox tmpfs | isolated temp runtime | No | ephemeral by design |

---

## 5. Channel, gateway, and browser constraints in Docker

## 5.1 Gateway binding in Docker: use bind modes, not raw host aliases

OpenClaw’s Docker docs explicitly say to use bind mode values like:

- `lan`
- `loopback`
- `custom`
- `tailnet`
- `auto`

Do **not** reason about `gateway.bind` as if it were literally `0.0.0.0` or `localhost`.

For Docker Compose, docs default to:

- `OPENCLAW_GATEWAY_BIND=lan`
- published port to host

But for private VPS use, the safer pattern is often:

```yaml
ports:
  - "127.0.0.1:18789:18789"
```

plus SSH tunnel or Tailscale access.

## 5.2 Gateway + CLI trust boundary in Docker

The Docker docs call out that the bundled `openclaw-cli` uses shared network namespace behavior to reach the gateway reliably. Practical meaning:

- the helper CLI container is in the same trust zone as the gateway
- loopback there is not a security boundary between those containers

So do not treat `openclaw-cli` as an untrusted container.

## 5.3 Channels in Docker

### WhatsApp

Operational reality:

- the gateway owns the WhatsApp linked session
- auth lives under `~/.openclaw/credentials/whatsapp/...`
- if you lose that mounted state, you risk relinking

### Telegram

Operational reality:

- bot token/config live in config/env
- pairing/allowlist/device data still land under `~/.openclaw`
- webhook mode may require separate reverse proxy planning

### General rule

If the gateway container is recreated but `~/.openclaw` is preserved, channel state should survive much better than if you treat the container as the source of truth.

## 5.4 Browser in Docker

There are several browser modes, and Docker changes the tradeoffs.

### Managed `openclaw` browser profile

This is the isolated OpenClaw-managed browser. Good default for automation.

### `user` profile

This attaches to the user’s real signed-in Chrome session. In Docker, that is usually awkward unless the browser is truly reachable from the machine/namespaces involved.

### `chrome-relay`

This depends on the browser extension/tab attachment flow, and usually makes most sense when the browser is on a user machine or node host, not purely inside a headless server container setup.

### Playwright requirement

Some browser features require Playwright. In Docker, docs recommend installing Chromium with:

```bash
docker compose run --rm openclaw-cli \
  node /app/node_modules/playwright-core/cli.js install chromium
```

If you do that, persist browser downloads by setting:

- `PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright`
- and persist `/home/node` or that cache path via volume/mount

### Sandboxed browser

OpenClaw also supports a sandbox browser image for session sandboxes. That is separate from the top-level gateway container and comes with conservative Chromium flags suitable for containers.

## 5.5 Node/browser proxy constraints

For remote browser control, the docs prefer a node host on the machine that actually has the browser.

That is often the cleanest mental model:

- gateway container on server
- browser/node host on the actual desktop/laptop
- gateway proxies browser actions there

Instead of trying to force your personal desktop browser into the same containerized environment.

---

## 6. Security and reliability hardening for Docker deployments

## 6.1 Good baseline defaults

Use these as your normal stance:

- `restart: unless-stopped`
- bind mount OpenClaw state to host
- keep published gateway port loopback-only unless you truly need network exposure
- use SSH tunnel or Tailscale for remote access
- run as non-root if possible
- keep Docker image security-first and add packages only deliberately

## 6.2 Secrets and env handling

The docs support several secrets patterns:

- environment variables
- `.env`
- `~/.openclaw/.env`
- env substitution in config
- SecretRef (`env`, `file`, `exec`) for supported fields

Recommendations:

### Prefer

- tokens in `.env` that is not committed
- or SecretRef-backed values for cleaner separation
- config values that reference env vars rather than hardcoding secrets in `openclaw.json`

### Avoid

- committing `.env`
- hardcoding long-lived browser/CDP tokens in config if possible
- stuffing secrets into workspace files

Remember: workspace docs explicitly say not to commit `~/.openclaw` secrets into the workspace repo.

## 6.3 Binaries and dependencies

Per Docker VM runtime docs:

- install external binaries at image build time
- do not install them ad hoc in a running container if you expect persistence

If a skill depends on `ffmpeg`, `git`, `jq`, `gog`, `wacli`, etc., bake them into the image or use build args like `OPENCLAW_DOCKER_APT_PACKAGES` where appropriate.

## 6.4 Logging and observability

Use multiple layers:

### Basic

- `docker compose logs -f openclaw-gateway`
- `openclaw logs --follow`
- `/healthz` and `/readyz`

### Better

- set `logging.level` appropriately
- persist or collect logs externally if needed
- consider diagnostics + OTLP exporter if you want metrics/traces/log export

Docs note disk growth hotspots worth watching:

- `media/`
- session transcript JSONL data
- `cron/runs/*.jsonl`
- rolling logs

## 6.5 Restart policy and health checks

The image includes a Docker `HEALTHCHECK` against `/healthz`.

That means you should pair it with an appropriate restart policy, normally:

```yaml
restart: unless-stopped
```

For a personal deployment, that is a sensible default.

## 6.6 Backups

A practical backup policy should cover:

1. `openclaw backup create --verify`
2. periodic off-machine copy of backup archives
3. separate private git backup of the workspace
4. optional snapshots of the entire host bind-mounted `.openclaw` tree

### What to prioritize

Highest-value backup targets:

- config
- credentials
- sessions
- workspace
- shared files

If storage is tight or you need speed:

- config-only backup for quick safety
- workspace in git
- full OpenClaw backup on a less frequent schedule

## 6.7 Updates

For a Docker/source deployment, adopt this explicit routine:

1. check status / release notes
2. make a backup
3. rebuild image
4. restart containers
5. verify health and channels

Example:

```bash
openclaw backup create --verify
git pull
docker compose build
docker compose up -d
curl -fsS http://127.0.0.1:18789/readyz
openclaw status --deep
```

That sequence is boring, which is exactly what you want.

---

## 7. Suggested directory structure for Joon

Joon asked to understand “your directory structure.” Here is the structure I recommend for a clean Docker-hosted OpenClaw setup, using the defaults OpenClaw already likes.

## 7.1 Recommended host structure

```text
/home/node/.openclaw/
├── openclaw.json              # main config
├── .env                       # optional global env fallback
├── credentials/               # channel auth, OAuth, tokens, key material
├── devices/                   # paired device info
├── agents/
│   ├── main/
│   │   ├── agent/
│   │   └── sessions/
│   └── <other-agent>/
│       ├── agent/
│       └── sessions/
├── media/
│   └── inbound/
├── logs/                      # some runtime logs/audit files
├── cron/
├── shared/                    # cross-agent, human-accessible shared docs/assets
├── canvas/
├── workspace/                 # main agent home
│   ├── AGENTS.md
│   ├── SOUL.md
│   ├── USER.md
│   ├── TOOLS.md
│   ├── IDENTITY.md
│   ├── HEARTBEAT.md
│   ├── memory/
│   └── skills/
└── workspace-<profile>/       # optional second workspace/profile
```

## 7.2 What each top-level area is for

### `openclaw.json`
System configuration. Treat this as infrastructure config, not workspace memory.

### `credentials/`
Sensitive auth state. Never commit to git.

### `agents/<id>/sessions/`
Conversation/session durability. This is operational state, not hand-authored docs.

### `shared/`
Good place for generated reference docs, exports, reports, and files you want both human and agent to access.

### `workspace/`
The main agent’s living area. Put long-lived notes, conventions, documents, and workspace-specific skills here.

## 7.3 Why this is a good fit for Joon’s current setup

Because Joon’s machine already resembles this structure, moving to Docker should preserve it rather than reinvent it.

Current observed realities:

- main workspace already exists at `/home/node/.openclaw/workspace`
- shared area already exists at `/home/node/.openclaw/shared`
- agent sessions already live under `/home/node/.openclaw/agents/.../sessions`
- credentials already live under `/home/node/.openclaw/credentials`

So the practical advice is:

> Keep this directory structure. Put Docker around it. Do not flatten it into random container-only paths.

---

## 8. Concrete Compose pattern I’d recommend

Here is a studyable baseline pattern based on the docs, adapted into a practical single-host setup.

```yaml
services:
  openclaw-gateway:
    image: ${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}
    restart: unless-stopped
    env_file:
      - .env
    environment:
      HOME: /home/node
      NODE_ENV: production
      TERM: xterm-256color
      OPENCLAW_GATEWAY_BIND: ${OPENCLAW_GATEWAY_BIND:-lan}
      OPENCLAW_GATEWAY_PORT: ${OPENCLAW_GATEWAY_PORT:-18789}
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
      XDG_CONFIG_HOME: /home/node/.openclaw
      PLAYWRIGHT_BROWSERS_PATH: /home/node/.cache/ms-playwright
    volumes:
      - ${OPENCLAW_CONFIG_DIR:-/home/node/.openclaw}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}:/home/node/.openclaw/workspace
      # optional named volume for caches/browser downloads
      # - openclaw_home:/home/node
    ports:
      - "127.0.0.1:${OPENCLAW_GATEWAY_PORT:-18789}:18789"
    command:
      [
        "node",
        "dist/index.js",
        "gateway",
        "--bind",
        "${OPENCLAW_GATEWAY_BIND:-lan}",
        "--port",
        "${OPENCLAW_GATEWAY_PORT:-18789}",
        "--allow-unconfigured"
      ]

  openclaw-cli:
    image: ${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}
    env_file:
      - .env
    environment:
      HOME: /home/node
      NODE_ENV: production
      OPENCLAW_GATEWAY_PORT: ${OPENCLAW_GATEWAY_PORT:-18789}
      OPENCLAW_GATEWAY_TOKEN: ${OPENCLAW_GATEWAY_TOKEN}
    volumes:
      - ${OPENCLAW_CONFIG_DIR:-/home/node/.openclaw}:/home/node/.openclaw
      - ${OPENCLAW_WORKSPACE_DIR:-/home/node/.openclaw/workspace}:/home/node/.openclaw/workspace
    network_mode: "service:openclaw-gateway"
    entrypoint: ["node", "dist/index.js"]
    profiles: ["cli"]

# volumes:
#   openclaw_home:
```

### Notes on this pattern

- Host state is mounted in.
- Gateway is only published to loopback.
- CLI runs against the same state and same gateway namespace.
- Playwright path is explicit so you can persist browser downloads if desired.

---

## 9. Practical checklists

## 9.1 First deployment checklist

- [ ] Decide: local machine, VPS, or hybrid with node/browser host
- [ ] Use `docker-setup.sh` unless you have a clear reason not to
- [ ] Bind-mount `~/.openclaw`
- [ ] Bind-mount or preserve `~/.openclaw/workspace`
- [ ] Keep gateway port loopback-only unless exposure is intentional
- [ ] Set a strong gateway token
- [ ] Store secrets in `.env` or SecretRefs, not workspace files
- [ ] Confirm `http://127.0.0.1:18789/healthz`
- [ ] Confirm Control UI opens
- [ ] Verify channels after onboarding/login

## 9.2 Before enabling browser automation in Docker

- [ ] Decide whether you want managed browser, remote node browser, or user browser attach
- [ ] Install Playwright browser properly
- [ ] Persist browser downloads if you want them to survive container recreation
- [ ] Keep browser/CDP endpoints private and authenticated
- [ ] Prefer node-host/browser-proxy for remote personal-browser workflows

## 9.3 Before adding skills that need extra binaries

- [ ] List required binaries/packages
- [ ] Add them to Dockerfile or supported build args
- [ ] Rebuild image
- [ ] Verify with `which <binary>` inside container
- [ ] Do not rely on runtime-only installs

## 9.4 Backup checklist

- [ ] Run `openclaw backup create --verify`
- [ ] Keep at least one off-machine backup copy
- [ ] Keep workspace in a private git repo
- [ ] Know where credentials and sessions live
- [ ] Test `openclaw backup verify <archive>` occasionally

## 9.5 Update checklist

- [ ] Check update status
- [ ] Create backup first
- [ ] Pull/rebuild image
- [ ] Restart stack
- [ ] Check `/readyz`
- [ ] Check `openclaw status --deep`
- [ ] Verify Telegram/WhatsApp connectivity
- [ ] Verify browser features if you use them

## 9.6 Troubleshooting checklist

- [ ] `docker compose ps`
- [ ] `docker compose logs -f openclaw-gateway`
- [ ] `openclaw logs --follow`
- [ ] `curl /healthz` and `/readyz`
- [ ] check permissions on mounted host dirs (UID 1000 for `node` image user)
- [ ] confirm state is on host mount, not trapped inside container filesystem
- [ ] for pairing issues: refresh dashboard, list devices, approve device

---

## 10. My opinionated recommendations for Joon

If I were setting this up for a beginner-to-intermediate OpenClaw user, I would do this:

1. **Use Docker for the gateway only if you actually want the isolation/repeatability.** If you just want fastest local dev loop, host install is simpler.
2. **Keep all real state on the host under `~/.openclaw`.** Do not make the container filesystem precious.
3. **Keep the workspace separate in your head, even if default path is nested.** Workspace is memory/home; `credentials/` and `sessions/` are operational state.
4. **Use loopback-only port publishing by default.** Reach it through SSH tunnel or Tailscale.
5. **Treat browser automation as its own subsystem.** Especially in Docker, decide explicitly how you want browser state and downloads to persist.
6. **Bake dependencies into images.** Runtime installs are for experiments, not reliable operations.
7. **Back up before updates.** Every time. It is cheap compared to relinking channels or losing memory/session history.
8. **Use the shared folder for generated docs and exports.** It is exactly the right place for reports like this.

---

## 11. Short reference commands

```bash
# initial setup
./docker-setup.sh

# start / rebuild
docker compose up -d
docker compose build

# CLI via helper container
docker compose run --rm openclaw-cli dashboard --no-open
docker compose run --rm openclaw-cli devices list
docker compose run --rm openclaw-cli channels login

# health
curl -fsS http://127.0.0.1:18789/healthz
curl -fsS http://127.0.0.1:18789/readyz
openclaw status --deep
openclaw health --json

# logs
docker compose logs -f openclaw-gateway
openclaw logs --follow

# backup
openclaw backup create --verify

# update
openclaw update status
openclaw update
# or, for source-based docker vm flow:
git pull && docker compose build && docker compose up -d
```

---

## Sources reflected in this guide

This guide was grounded primarily in the local OpenClaw docs on this machine, especially:

- `docs/install/docker.md`
- `docs/install/docker-vm-runtime.md`
- `docs/concepts/architecture.md`
- `docs/concepts/agent-workspace.md`
- `docs/tools/browser.md`
- `docs/gateway/configuration.md`
- `docs/gateway/sandboxing.md`
- `docs/cli/backup.md`
- `docs/cli/update.md`
- `docs/logging.md`
- `docs/gateway/health.md`
- channel docs for Telegram and WhatsApp

And it was cross-checked against this machine’s actual current `.openclaw` layout.

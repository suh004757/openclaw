# Shared Reference Drop Zone

Put files here when you want agents running in Docker to read host-provided reference material.

- Host path: `Clawdbot_Docker/shared`
- Container path: `/home/node/.openclaw/shared`

Recommended use:
- PDFs, notes, source dumps, temporary research files
- Reference-only material you want to keep outside an agent workspace

Avoid storing secrets here unless you intend the agent to read them.

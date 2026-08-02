---
name: connect-servers
description: Map of Chronica's infrastructure servers and how to reach them over SSH. Use whenever a task needs to run commands on a specific server, or when unsure which server hosts something — start here before logs-docker/query-postgres or any other server-touching skill. Read-only (connection info only, not a permission to make changes).
---

Chronica infrastructure lives on dedicated servers, reached only over SSH — nothing runs
locally. This skill is the map of *which* server hosts what and *how* to reach it; once
connected, hand off to a task-specific skill (`logs-docker`, `query-postgres`, ...) or run
commands directly.

## Servers

| Alias | Status | Role |
|-------|--------|------|
| `loki` | active | Everything today: all `dwh-*`/`chr-*` Docker containers (Postgres, ClickHouse, Redis, Redpanda, Ollama, dbt, MinIO, rss-fetcher, moex-fetcher, Evidence dev+prod). See `logs-docker`'s container map for the full list. |
| `odin` | planned, not yet provisioned | Role not yet defined. Don't assume it mirrors `loki` — ask what it's for before writing anything that targets it, and update this table once it exists. |

## Connecting

```
ssh <alias> "<command>"
```

`Bash(ssh loki *)` is already allow-listed in `.claude/settings.local.json`, so `loki` commands
run without a permission prompt. Add the equivalent `Bash(ssh odin *)` entry once `odin` is
actually reachable — no need to pre-add it for a host that doesn't resolve yet.

### How `loki` resolves

No `Host loki` block in `~/.ssh/config` — resolution happens via `/etc/hosts`:

```
192.168.1.15   loki        # LAN IP — normal ssh/skill target
46.138.246.208 ext-loki    # public IP — same box, external side (chronica.life resolves here)
```

`~/.ssh/config` has a wildcard `Host *` applying `User core` and `IdentityFile
~/.ssh/local_ed25519` to any hostname, so a new server typically only needs an `/etc/hosts`
line added (by the user, not Claude) to become reachable the same way — no per-host SSH config
unless it needs a different user or key.

`ext-loki` is the same machine as `loki`, just its internet-facing IP — the reverse proxy
(OpenResty) there only has a vhost/TLS cert for `chronica.life` (prod). There is no working
route for a `dev.*` subdomain — the dev Evidence instance (`chr-evidence-dev`, `:33001`) is
only reachable from `loki`'s LAN side, at `http://192.168.1.15:33001`, not by any domain name.

## When `odin` arrives

Update the table above with its real role, and check whether the existing server-specific
skills (`logs-docker`, `query-postgres`) need a server parameter added, or whether `odin` gets
its own parallel skill instead — depends on what ends up running there.

## Out of scope

This skill only documents how to reach a box. It doesn't cover what to do once connected —
that's `logs-docker`, `query-postgres`, or ad-hoc commands with the user's explicit direction,
same caution as any other server-touching action (no destructive commands, no unrequested
changes).

---
name: logs-docker
description: View logs from any Chronica container running on loki. Use whenever the user asks to check/inspect/tail container logs, debug a pipeline or service by its output, or investigate an error/crash in a specific container. Read-only.
---

All Chronica containers run on the `loki` server — there is no local Docker daemon to check.
All access goes through SSH.

## Connection

```
ssh loki "docker logs <container> <flags>"
```

`ssh loki *` is already allow-listed in `.claude/settings.local.json`, so this runs without
a permission prompt.

## Container map

| Container | What it is |
|-----------|------------|
| `dwh-pg-1` | Postgres (core DB) |
| `dwh-ch-1` | ClickHouse |
| `dwh-rd-1` | Redis (cache) |
| `dwh-rd-insight` | RedisInsight UI |
| `dwh-rp-1` | Redpanda broker |
| `dwh-rp-connect` | Redpanda Connect (Benthos) — runs all `dwh/rpc/*` pipelines |
| `dwh-rp-console` | Redpanda Console UI |
| `dwh-ol-1` | Ollama (local embeddings) |
| `dwh-dbt` | dbt |
| `dwh-minio` | MinIO |
| `chr-rss-fetcher` | rss-fetcher service |
| `chr-moex-fetcher` | moex_fetcher service |
| `chr-evidence-dev` | Evidence.dev dashboard, dev instance (`:33001`, hot reload) |
| `chr-evidence-prod` | Evidence.dev dashboard, prod instance (`:33000`, rebuilds every 20 min) |

If unsure which container is relevant, `ssh loki "docker ps --format '{{.Names}}\t{{.Status}}'"`
lists everything currently running.

## Common invocations

- **Recent tail** (default starting point): `ssh loki "docker logs --tail 200 <container>"`
- **Follow live**: `ssh loki "docker logs -f --tail 50 <container>"` — this blocks, so only use
  it when actively watching something happen; prefer a bounded `--since` window otherwise.
- **Time-bounded**: `ssh loki "docker logs --since 15m <container>"` (also accepts timestamps,
  e.g. `--since 2026-07-06T10:00:00`)
- **Errors only**: pipe through grep, e.g.
  `ssh loki "docker logs --tail 1000 dwh-rp-connect 2>&1 | grep -i error"`
- **stdout/stderr separately**: `docker logs` interleaves both by default; redirect
  (`2>/dev/null` or `1>/dev/null`) to isolate one stream if needed.

For `dwh-rp-connect` specifically, logs are per-pipeline JSON lines — grep on the pipeline's
file name (e.g. `LOAD_DDS_S_NEWS_TEXTS`) to isolate one stream's output.

## Out of scope

This skill is read-only (logs only). Restarting/stopping containers, editing compose files, or
exec-ing into a container for anything beyond reading are outside its scope — do that
explicitly with the user's confirmation instead.
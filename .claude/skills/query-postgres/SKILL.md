---
name: query-postgres
description: Query the Chronica Postgres DB (chronica) on loki. Use whenever the user asks to read/inspect data or schema in Postgres — run a SELECT, count rows, check a table's columns, verify a migration landed, or debug a pipeline's output. Read-only.
---

The Chronica Postgres DB is not reachable locally — it only exists inside the `dwh-pg-1`
Docker container on the `loki` server. All access goes through SSH + `docker exec`.

## Connection

Canonical command — resolve user/db from the container's own environment instead of
hardcoding credentials in a file that's checked into git:

```
ssh loki "docker exec -i dwh-pg-1 sh -c 'psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -c \"...\"'"
```

- Host: `loki` (SSH only, no local tunnel/port-forward is set up)
- Container: `dwh-pg-1`
- `POSTGRES_USER` / `POSTGRES_DB` / `POSTGRES_PASSWORD` are already set as env vars inside
  the container (populated from `.env` on `loki` via `dwh/compose/postgres/docker-compose.yaml`).
  psql picks up `$POSTGRES_USER`/`$POSTGRES_DB` through the `sh -c '...'` wrapper, so no
  actual login/password value ever needs to appear in a command or in this file. No
  password flag is needed at all — local socket auth inside the container doesn't prompt
  for one.

`ssh loki *` is already allow-listed in `.claude/settings.local.json`, so this runs without
a permission prompt.

## Running queries

- **Single-line queries** — use `sh -c '... -c "..."'` as above. Quoting gets nested three
  levels deep (outer double quotes for SSH, `sh -c '...'` single quotes, then the SQL
  itself), so for any query with its own string literals it's simpler to drop to the
  heredoc form below rather than juggling escapes.
- **Multi-line / complex queries** — pipe SQL over stdin via a heredoc instead of fighting
  shell quoting in `-c`:

  ```
  ssh loki "docker exec -i dwh-pg-1 sh -c 'psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\"'" <<'SQL'
  select story_id, count(*)
  from dds.s_news_reactions
  group by 1
  order by 2 desc
  limit 20;
  SQL
  ```

  (The container's `-i` flag plus the heredoc is what lets multi-line SQL reach psql cleanly.
  SQL string literals inside the heredoc can use plain `'...'` since they're not touched by
  the outer shell.)

- **Clean/parseable output** — useful psql flags: `-t` (no headers/footers), `-A`
  (unaligned), `-F','` with `--csv` for CSV, `-P pager=off` to avoid a hanging pager, `-x`
  for expanded output on wide rows.

## Inspecting schema

Use psql's backslash commands through `-c`:

- `\dn` — list schemas
- `\dt ods.*`, `\dt dds.*`, `\dt bds.*`, `\dt dm.*` — list tables in a schema
- `\d dds.s_news_reactions` — describe a table's columns, types, indexes

## Schema map

Four schemas, from `CLAUDE.md`:

| Schema | Role |
|--------|------|
| `ods` | Raw data as ingested from sources |
| `dds` | Data Vault core: hubs, satellites, links, refs |
| `bds` | Business Data Store: (materialized) views with business logic |
| `dm`  | Data marts consumed by the dashboard |

Table prefixes inside `dds`: `h_` hub, `s_` satellite, `t_` transaction/link, `d_`
reference, `st_` state. Inside `bds`: `b_`. A `_d` suffix on a `dm` table means daily grain
(e.g. `dm.story_summaries_d`).

## Column conventions

Common suffixes: `_dttm` (timestamptz), `_dt` (date), `_txt` (free text), `_nm`
(name/enum-like), `_idx` (scale/enum bucket), `_scr` (numeric score), `_prt`
(proportion 0..1), `_id` (identifier), `_vct` (embedding vector), `_cnt` (count), `_json`
(jsonb). Most tables also carry `_loaded_dttm` and `_source_system`. Full reference:
`CLAUDE.md` → "DWH: schemas and naming".

## DDL and writes are out of scope

This skill is read-only. Schema and data changes go through migrations in
`dwh/migrations/pg/` (naming: `NNN_action_schema.object.sql`), never through ad-hoc psql. If
a request needs an `INSERT`/`UPDATE`/`DELETE`/`DROP`/`TRUNCATE` or a schema change, don't run
it directly against the production DB — write or point to a migration file instead.

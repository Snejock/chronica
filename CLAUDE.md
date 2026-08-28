# Chronica

Automated news and market monitoring system. Ingests RSS articles and MOEX trades,
clusters news into "stories", and generates daily LLM summaries so the reader can
track events without noise. See `README.md` (Russian) for the human-facing overview.

## Data flow

```
RSS sources → rss-fetcher ──┐
                             ├──→ Redpanda ──→ Redpanda Connect (dwh/rpc) → PostgreSQL → Evidence.dev
MOEX → moex-fetcher ─────────┘                                                  ↑
                                              Redis (cache)      ClickHouse ←── moex-fetcher
```

## Repo map

| Path | What's there |
|------|--------------|
| `dwh/compose/` | One docker-compose per infra component (postgres, clickhouse, redis, redpanda, ollama, dbt, minio) |
| `dwh/migrations/{pg,ch,rp}/` | Schema migrations (Postgres, ClickHouse, Redpanda schema registry) |
| `dwh/rpc/{ods,dds,bds,dm}/` | Redpanda Connect (Benthos) pipeline configs, one YAML per stream |
| `dwh/dbt/` | dbt project (own README, custom materializations) |
| `services/{rss-fetcher,moex-fetcher}/` | Python data-collector services |
| `services/tg-sender/` | Consumes the `tg_notifications` topic, sends per-subscriber Telegram messages |
| `services/api/` | FastAPI backend for the Signalfire frontend (React/Vue, TBD) |
| `services/template/` | Canonical skeleton for a new service |
| `common/` | Shared package `chronica-common` (Pydantic models, utils), workspace member |
| `evidence/` | Evidence.dev (SvelteKit) BI dashboard |
| `.claude/agents/` | Custom subagents (technical-writer, evidence-developer) |
| `.claude/skills/` | Custom skills (check-dev-site, connect-servers, generate-embedding-ollama, logs-docker, query-postgres, write-anchor) |
| `docker-compose.yaml` (root) | `include:`-only orchestrator; currently pulls in most of the compose files above (`dwh/compose/dbt` and `services/moex-fetcher` are not included/commented out) |

There is **no `ai-translator` service** — translation happens inside the
`dwh/rpc/dds/*_S_NEWS_TEXTS.yaml` pipelines (LLM branch), not a standalone service.

## DWH: schemas and naming

Postgres schemas (`dwh/migrations/pg/001_create_schemas.sql`):

| Schema | Role |
|--------|------|
| `ods` | Raw data as ingested from sources |
| `dds` | Data Vault core: hubs, satellites, links, refs |
| `bds` | Business Data Store: (materialized) views with business logic |
| `dm`  | Data marts consumed by the dashboard |

Table prefixes inside `dds`: `h_` hub, `s_` satellite, `t_` transaction/link, `d_` reference,
`st_` state. Inside `bds`: `b_`. A `_d` suffix on a `dm` table means daily grain
(e.g. `dm.story_summaries_d`).

Column suffix conventions (see `dwh/migrations/pg/015_create_table_dds.s_news_reactions.sql`
for a dense example):

| Suffix | Meaning |
|--------|---------|
| `_dttm` | `timestamp with time zone` |
| `_dt` | `date` |
| `_txt` | free text / content |
| `_nm` | name or enum-like label |
| `_idx` | scale/enum bucket (also used for SQL index names) |
| `_scr` | numeric score |
| `_prt` | proportion/probability, 0..1 |
| `_id` | identifier / key |
| `_vct` | embedding vector (`vector(768)`) |
| `_cnt` | count |
| `_json` | jsonb payload |

Index/constraint naming: `table__field_1_field_2_<suffix>`, double underscore between the bare
table name (no schema prefix) and the field list, single underscore between fields — `<suffix>`
∈ `idx` (regular index), `uidx` (unique index), `pk` (primary key), `fk` (foreign key), `seq`
(explicit standalone sequence).
Field list is every indexed/constrained column, in order. Applies to explicitly named
constraints/indexes only — implicit sequences behind `GENERATED ALWAYS AS IDENTITY` columns keep
Postgres's own default name (e.g. `h_subscribers_subscriber_id_seq`), left unrenamed by
convention. Don't confuse this with the column suffix `_idx` above (scale/enum bucket, e.g.
`reach_idx`) — that's a column name, this is an index/constraint identifier.

`_loaded_dttm` and `_source_system` (leading underscore) are technical columns present on
most tables. Other established bare names: `language_code`, `country_code`, `is_*` (boolean),
`geo_lat`/`geo_lon`.

Migration file naming: `NNN_action_schema.object.sql` with a sequential 3-digit number and
`action` ∈ {create_table, create_view, create_schemas, alter_table, backfill, insert_into}.

## DWH: Redpanda Connect pipelines (`dwh/rpc/`)

One YAML = one stream targeting one table, grouped by layer (`ods/`, `dds/`, `bds/`, `dm/`).
File naming: `{LOAD|RELOAD}_{SCHEMA}_{TABLE}.yaml` (upper snake case, mirrors the DDL name).

- `LOAD_*` — incremental stream, usually consumes a Redpanda topic (consumer group named
  after the file) with Redis-based dedup.
- `RELOAD_*` — periodic backfill: `input.generate` on an interval, selects whatever hasn't
  been processed yet directly from Postgres.

Reference files:
- `dwh/rpc/dds/LOAD_DDS_S_NEWS_TEXTS.yaml` — streaming pattern with an LLM translation branch.
- `dwh/rpc/dds/LOAD_DDS_T_NEWS_LOCATIONS.yaml` — LLM extraction + external API standardization
  (GeoNames) with a `rate_limit` resource and a self-learning alias cache (Redis + `s_*_aliases`);
  `LOAD_DDS_T_NEWS_ACTORS.yaml` is the same pattern against Wikidata.
- `dwh/rpc/dm/LOAD_DM_STORY_SUMMARIES_D.yaml` — periodic LLM-enrichment pattern.
- `dwh/rpc/bds/LOAD_BDS_B_UNEWS.yaml` — trivial `REFRESH MATERIALIZED VIEW` pipeline.

Common periodic-pipeline shape:
`generate(interval) → sql_raw (select candidates, anti-join target table on _loaded_dttm/model_nm)
→ mapping (empty-array guard) → unarchive(json_array) → branch (HTTP call to DeepSeek)
→ output.sql_raw (INSERT ... ON CONFLICT ... DO UPDATE)`.

Postgres DSN is always `postgres://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}?sslmode=disable`.
In-pipeline comments are written in Russian — keep that convention when editing.

## LLM

Production pipelines call the **DeepSeek cloud API**
(`https://api.deepseek.com/chat/completions`, model `deepseek-v4-flash`), via a Benthos
`http` processor with `Authorization: Bearer ${DEEPSEEK_API_KEY}` and
`response_format: json_object`. Rows are tagged `model_nm = 'deepseek-v4-flash:cloud'`.
Temperature varies by task (≈0.0 for translation, 0.3–0.4 for summarization/briefs).
Embeddings (`vector(768)`) are generated locally via Ollama (`http://dwh-ol-1:11434/api/embed`,
see `dwh/rpc/dds/LOAD_DDS_S_NEWS_EMBEDDINGS.yaml`) — Ollama is not used for summaries/briefs.
Non-LLM external APIs: Wikidata (actor resolution) and GeoNames (event-location geocoding,
`GEONAMES__USERNAME` env key, throttled via the `geonames_api` rate-limit resource in
`dwh/compose/redpanda/config/resources.yaml`).

## Services (Python)

uv workspace: root `pyproject.toml` (`members = ["services/*", "common"]`), single root
`uv.lock`, Python ≥3.14. Each service follows the same shape (see `services/template/`):
`<name>.py` entrypoint + `packages/` (`Application.py`, `logger/`, `providers/`,
`parsers/`|`utils/`) + `config/` + `compose/` (Dockerfile + docker-compose.yaml). Shared
Pydantic models/utils live in `common/` as the `chronica-common` package. Only
`rss-fetcher` currently has a test suite (pytest).

## Evidence (BI dashboard)

Evidence.dev / SvelteKit. Single source `evidence/sources/dwh_pg_1/` (Postgres, db `chronica`),
reading from the `bds`/`dm` layers. Pages live under `evidence/pages/*.md`. Dev instance on
`:33001` (hot reload), prod on `:33000` (rebuilds sources every 20 min). Never commit
`connection.options.yaml` (credentials).

## Commands & deploy

- Bring up infra: `docker compose up -d` from repo root (the root compose file is just an
  `include:` list; network is `dwh-net`).
- Env: a single root `.env` is the only active config, read by everything — Compose
  interpolation (`${...}` in `dwh/compose/*`), every service's `env_file:` (`services/*/compose/`,
  `evidence/compose/`), and the shared pydantic `Config` (`common/models/Config.py`). Nested-style
  keys (`POSTGRES__*`, `CLICKHOUSE__*`, `BROKER__*`, `DEEPSEEK__API_KEY`, `GOOGLE_AI__API_KEY`,
  `GEONAMES__USERNAME`).
  Root `.env.server` is an inert copy of local-dev values (external `loki` addresses/ports) —
  nothing reads it automatically; to develop from a laptop, manually copy it over `.env`.
- CI/CD: `.github/workflows/deploy.yaml` — push to `master` triggers an SSH step that runs
  `git fetch origin master && git reset --hard origin/master` on the `loki` host. Pull-based,
  no build/test step in CI.
- No Makefile/justfile — Docker Compose is the only orchestration layer.

## Working conventions

- Direct DB queries: `ssh loki "docker exec -i dwh-pg-1 psql -U core -d chronica -c '...'"`.
- Don't run Evidence dev or Docker locally to verify changes — the user tests on the
  `loki` server (`dev.chronica` → `chr-evidence-dev`) and syncs files there themselves.
- Production deploys go out from `master` via CI onto `loki`.

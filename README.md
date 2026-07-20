# Chronica

**Chronica** — система автоматизированного мониторинга и анализа новостей и рыночных данных. Собирает материалы из RSS-источников и биржевые сделки с MOEX, группирует по темам и формирует ежедневные сводки с помощью LLM, чтобы следить за событиями без лишнего шума.

## Архитектура

```
RSS-источники → rss-fetcher ──┐
                               ├──→ Redpanda ──→ Redpanda Connect → PostgreSQL → Evidence.dev
MOEX → moex-fetcher ──────────┘                                          ↑
                                  ↑                          DeepSeek (cloud LLM) / Ollama (embeddings)
                               Redis (кэш)         ClickHouse ←── moex-fetcher
```

### Сервисы (`/services`)

| Сервис | Описание |
|--------|----------|
| `rss-fetcher` | Периодический опрос RSS-лент, парсинг и публикация новостей в Redpanda |
| `moex-fetcher` | Стриминг биржевых сделок с MOEX ISS API, запись в ClickHouse (`ods.moex_trades`) |
| `tg-sender` | Отправка персонализированных уведомлений о новостях подписчикам в Telegram (консьюмер топика `tg_notifications`) |

### Хранилище данных (`/dwh`)

**PostgreSQL** — основное хранилище новостей и сводок:

| Слой | Описание |
|------|----------|
| `ods` | Сырые данные из источников |
| `dds` | Хабы, сателлиты, справочники, сводки по сюжетам |
| `bds` | Материализованные представления с бизнес-логикой поверх `dds` |
| `dm` | Витрины данных для дашборда (views) |

Инфраструктура DWH:

| Компонент | Описание |
|-----------|----------|
| **PostgreSQL** | Основное хранилище новостей (схемы `ods`, `dds`, `dm`) |
| **ClickHouse** | Аналитическое хранилище биржевых данных · HTTP `http://localhost:38123` |
| **Redpanda** | Kafka-совместимый брокер сообщений |
| **Redpanda Connect** | Потоковый ETL: читает топики, пишет в PostgreSQL (конфигурации в `dwh/rpc/`) |
| **Redpanda Console** | Web UI для управления топиками · `http://localhost:38088` |
| **Redis** | LRU-кэш без персистентности (512 МБ, `allkeys-lru`) |
| **RedisInsight** | Web UI для Redis · `http://localhost:35540` |
| **Ollama** | Локальный запуск LLM для генерации эмбеддингов новостей |
| **DeepSeek** | Облачный LLM API (`deepseek-v4-flash`) для генерации сводок, брифов и реакций на новости — вызывается из процессоров Redpanda Connect (`dwh/rpc/dds/`, `dwh/rpc/dm/`) |
| **dbt** | Трансформации данных поверх DWH |
| **MinIO** | S3-совместимое объектное хранилище |

### Дашборд (`/evidence`)

Evidence.dev — фронтенд для визуализации данных. Показывает ежедневные хроники событий по сюжетам.

- Dev: `http://localhost:33001`
- Prod: `http://localhost:33000`

### Общие компоненты (`/common`)

Pydantic-модели, конфигурации и утилиты, разделяемые между сервисами.

## Технологический стек

- **Python** 3.14+ · [uv](https://github.com/astral-sh/uv)
- **БД**: PostgreSQL, ClickHouse, Redis (LRU-кэш)
- **Брокер**: Redpanda + Redpanda Connect
- **LLM**: DeepSeek (cloud API, сводки/брифы/реакции) · Ollama (локальные эмбеддинги)
- **Дашборд**: Evidence.dev (SvelteKit)
- **Инфраструктура**: Docker Compose

## Запуск

### Требования

- Docker и Docker Compose
- [uv](https://github.com/astral-sh/uv) — для локальной разработки сервисов

### Инфраструктура

```bash
docker compose up -d
```

### Evidence (дашборд)

```bash
# Первый запуск (инициализация)
cd evidence/compose && docker compose run --rm chr-evidence-dev init

# Dev-режим (hot reload)
cd evidence/compose && docker compose up chr-evidence-dev

# Prod-режим
cd evidence/compose && docker compose up chr-evidence-prod
```

## Конфигурация

- RSS-источники: `services/rss-fetcher/config/rss_feeds.yaml`
- MOEX (тикеры, расписание): `services/moex-fetcher/config/config.yml`
- Переменные окружения: `.env` (единственный активный конфиг; `.env.local` — инертная копия
  локальных dev-значений для ручной подмены)
- Миграции PostgreSQL: `dwh/migrations/pg/`
- Миграции ClickHouse: `dwh/migrations/ch/`
# Chronica

**Chronica** — система автоматизированного мониторинга и анализа новостей. Собирает материалы из RSS-источников, группирует их по темам и формирует ежедневные сводки с помощью LLM, чтобы следить за событиями без лишнего шума.

## Архитектура

```
RSS-источники → rss-fetcher → Redpanda → DWH (PostgreSQL) → Evidence.dev
                                                ↑
                                             Ollama (LLM)
```

### Сервисы (`/services`)

| Сервис | Описание |
|--------|----------|
| `rss-fetcher` | Периодический опрос RSS-лент, парсинг и сохранение новостей в stg-слой |

### Хранилище данных (`/dwh`)

Многослойная архитектура PostgreSQL:

| Слой | Описание |
|------|----------|
| `ods` | Сырые данные из источников |
| `dds` | Хабы, сателлиты, справочники, сводки по сюжетам |
| `dm` | Витрины данных для дашборда (views) |

Инфраструктура DWH: **PostgreSQL**, **Redpanda** (Kafka-совместимый брокер), **Redis**, **Ollama** (локальный LLM).

### Дашборд (`/evidence`)

Evidence.dev — фронтенд для визуализации данных. Показывает ежедневные хроники событий по сюжетам.

- Dev: `http://localhost:33001`
- Prod: `http://localhost:33000`

### Общие компоненты (`/common`)

Pydantic-модели, конфигурации и утилиты, разделяемые между сервисами.

## Технологический стек

- **Python** 3.14+ · [uv](https://github.com/astral-sh/uv)
- **БД**: PostgreSQL, Redis
- **Брокер**: Redpanda
- **LLM**: Ollama
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
- Переменные окружения: `.env` в корне проекта
- Миграции БД: `dwh/migrations/pg/`
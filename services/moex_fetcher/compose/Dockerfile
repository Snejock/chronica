FROM python:3.14-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Копирование файлов конфигурации для кэширования слоёв
COPY pyproject.toml uv.lock ./
COPY common/pyproject.toml ./common/
COPY services/moex_fetcher/pyproject.toml ./services/moex_fetcher/

# Установка зависимостей без исходного кода
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --frozen \
    --no-dev \
    --no-install-project \
    --package moex-fetcher

# Копирование исходного кода
COPY common/ ./common/
COPY services/moex_fetcher/ ./services/moex_fetcher/

# Финальная синхронизация с кодом проекта
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --frozen \
    --no-dev \
    --no-editable \
    --package moex-fetcher

WORKDIR /app/services/moex_fetcher

RUN mkdir -p log
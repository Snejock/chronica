FROM python:3.14-slim

# Устанавливается uv, копируя его из официального образа
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Копирование только файлов конфигурации для кэширования слоев
COPY pyproject.toml uv.lock ./
COPY common/pyproject.toml ./common/
COPY services/rss-fetcher/pyproject.toml ./services/rss-fetcher/

# Устанавка зависимостей
# --frozen: гарантирует использование версий строго из uv.lock
# --no-dev: не устанавливаем dev-зависимости
# --no-install-project: устанавливаем только библиотеки, сам проект пока не трогаем
# --package rss-fetcher: установка зависимостей только этого сервиса
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --frozen \
    --no-dev \
    --no-install-project \
    --package rss-fetcher

# Копирование исходного кода
COPY common/ ./common/
COPY services/rss-fetcher/ ./services/rss-fetcher/

# Финальная синхронизация проекта
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --frozen \
    --no-dev \
    --no-editable \
    --package rss-fetcher

# Установка рабочей директории сервиса
WORKDIR /app/services/rss-fetcher

# Создание папки для логов
RUN mkdir -p log
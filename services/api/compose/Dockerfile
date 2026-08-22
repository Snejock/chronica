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
COPY dwh/ ./dwh/
COPY services/api/pyproject.toml ./services/api/

# Устанавка зависимостей
# --frozen: гарантирует использование версий строго из uv.lock
# --no-dev: не устанавливаем dev-зависимости
# --no-install-project: устанавливаем только библиотеки, сам проект пока не трогаем
# --package api: установка зависимостей только этого сервиса
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --no-dev \
    --no-install-project \
    --package api

# Копирование исходного кода
COPY common/ ./common/
COPY services/api/ ./services/api/

# Финальная синхронизация проекта
RUN uv sync \
    --index-url https://mirrors.aliyun.com/pypi/simple \
    --default-index https://mirrors.aliyun.com/pypi/simple \
    --frozen \
    --no-dev \
    --no-editable \
    --package api

# Установка рабочей директории сервиса
WORKDIR /app/services/api

# Создание папки для логов
RUN mkdir -p log

FROM python:3.14-slim

# Устанавливается uv, копируя его из официального образа
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/app/.venv

WORKDIR /app

# Копируются файлы описания зависимостей
# Это делается отдельным слоем до копирования кода, чтобы использовать кэш Docker
# Контекст сборки — корень проекта (там, где uv.lock)
COPY pyproject.toml uv.lock ./
COPY common/pyproject.toml ./common/
COPY services/rss-fetcher/pyproject.toml ./services/rss-fetcher/

# Устанавливаются зависимости
# --frozen: гарантирует использование версий строго из uv.lock
# --no-dev: не устанавливаем dev-зависимости
# --no-install-project: устанавливаем только библиотеки, сам проект пока не трогаем
RUN uv sync --frozen --no-dev --no-install-project

# Копируем исходный код
COPY . /app

# Финальная синхронизация проекта
RUN uv sync --frozen --no-dev

# Добавляется виртуальное окружение в PATH
# uv по умолчанию создает venv в .venv, python добавляется в ENV
ENV PATH="/app/.venv/bin:$PATH"

# Переходим в директорию сервиса
WORKDIR /app/services/rss-fetcher

# Создаем папку для логов (если нужно)
RUN mkdir -p log
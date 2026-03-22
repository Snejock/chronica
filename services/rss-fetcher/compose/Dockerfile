FROM python:3.14-slim

# Устанавливается uv, копируя его из официального образа
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# Копируются файлы описания зависимостей
# Это делается отдельным слоем до копирования кода, чтобы использовать кэш Docker
COPY pyproject.toml uv.lock ./

# Устанавливаются зависимости
# --frozen: гарантирует использование версий строго из uv.lock
# --no-dev: не устанавливаем dev-зависимости
# --no-install-project: устанавливаем только библиотеки, сам проект пока не трогаем
RUN uv sync --frozen --no-dev --no-install-project

# Добавляется виртуальное окружение в PATH
# uv по умолчанию создает venv в .venv, python добавляется в ENV
ENV PATH="/app/.venv/bin:$PATH"

# Копируется исходный код приложения
COPY . /app

# Создаем директорию для логов (как в вашем примере)
RUN mkdir -p /app/log

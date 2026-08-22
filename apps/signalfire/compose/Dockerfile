# Dev: живой Vite dev-сервер. Исходники монтируются volume'ами в docker-compose.yaml,
# поэтому здесь ничего не копируется — npm install и запуск происходят при старте контейнера.
FROM node:24-alpine AS dev
WORKDIR /app
CMD ["sh", "-c", "npm install && npm run dev -- --host 0.0.0.0 --port 3000"]

# Build: собирает продакшн-бандл (tsc -b && vite build) в отдельном слое, кэшируется по
# package-lock.json — исходники добавляются только после npm ci.
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Prod: неизменяемый образ, раздаёт собранную статику. Пересобирается вручную при деплое
# (docker compose up -d --build), без фоновых процессов внутри контейнера.
FROM node:24-alpine AS prod
WORKDIR /app
RUN npm install --global serve
COPY --from=build /app/dist ./dist
EXPOSE 3000
CMD ["serve", "-s", "-l", "3000", "dist"]

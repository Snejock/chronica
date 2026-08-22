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

# Prod: неизменяемый образ, раздаёт собранную статику через nginx. Пересобирается вручную
# при деплое (docker compose up -d --build), без фоновых процессов и без обращений к npm
# registry на этом этапе — только сам базовый образ nginx.
FROM nginx:1.27-alpine AS prod
COPY --from=build /app/dist /usr/share/nginx/html
COPY compose/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

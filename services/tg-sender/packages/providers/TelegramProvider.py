import asyncio
import logging
import httpx

logger = logging.getLogger(__name__)

TELEGRAM_API_URL = "https://api.telegram.org"
CAPTION_LIMIT = 1024


class TelegramProvider:
    """Асинхронный клиент Telegram Bot API"""
    def __init__(self, config, timeout_sec: int = 15):
        self._token = config.telegram.bot_token
        self._proxy_url = (
            f"http://{config.proxy.user}:{config.proxy.password}@{config.proxy.host}:{config.proxy.port}"
        )
        self._client: httpx.AsyncClient | None = None
        self._lock = asyncio.Lock()
        self._timeout = timeout_sec

    async def open(self) -> None:
        async with self._lock:
            if self._client is None:
                self._client = httpx.AsyncClient(
                    base_url=f"{TELEGRAM_API_URL}/bot{self._token}",
                    http2=True,
                    timeout=self._timeout,
                    proxy=self._proxy_url,
                )
                logger.info("Telegram client initialized")

    async def send_photo(self, chat_id: int, photo_url: str, caption: str) -> None:
        if self._client is None:
            raise RuntimeError("Telegram client is not connected. Call open() first.")

        try:
            response = await self._client.post(
                "/sendPhoto",
                json={
                    "chat_id": chat_id,
                    "photo": photo_url,
                    "caption": caption[:CAPTION_LIMIT],
                    "parse_mode": "HTML",
                },
            )
            self._raise_for_status(response)
        except Exception:
            logger.exception(f"sendPhoto failed for chat_id={chat_id}, falling back to sendMessage")
            await self.send_message(chat_id, caption)

    async def send_message(self, chat_id: int, text: str) -> None:
        if self._client is None:
            raise RuntimeError("Telegram client is not connected. Call open() first.")

        response = await self._client.post(
            "/sendMessage",
            json={
                "chat_id": chat_id,
                "text": text,
                "parse_mode": "HTML",
            },
        )
        self._raise_for_status(response)

    @staticmethod
    def _raise_for_status(response: httpx.Response) -> None:
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError:
            logger.error(f"Telegram API error {response.status_code}: {response.text}")
            raise

    async def close(self) -> None:
        async with self._lock:
            if self._client is not None:
                try:
                    await self._client.aclose()
                except Exception:
                    logger.exception("Telegram client close failed")
                finally:
                    self._client = None
                    logger.info("Telegram client closed")

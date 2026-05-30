import asyncio
import logging
import httpx

from config.schema import AppConfig

logger = logging.getLogger(__name__)


class MoexProvider:
    """Асинхронный провайдер данных MOEX ISS"""

    def __init__(self, config: AppConfig, timeout_sec: int = 10):
        self.config = config
        self._client: httpx.AsyncClient | None = None
        self._lock = asyncio.Lock()
        self._timeout = timeout_sec
        self._params = {"next_trade": 1}

    async def connect(self) -> None:
        async with self._lock:
            if self._client is None:
                self._client = httpx.AsyncClient(
                    http2=True,
                    timeout=self._timeout,
                    follow_redirects=True,
                    headers={
                        "User-Agent": "moex-stream-service/1.0"
                    }
                )
                logger.info("MOEX client initialized")

    async def fetch(self, url: str, cursor: int | None = None) -> dict | None:
        if self._client is None:
            raise RuntimeError("MOEX Client is not connected. Call connect() first.")

        if cursor is not None:
            self._params["tradeno"] = cursor

        response = await self._client.get(url, params=self._params)
        response.raise_for_status()
        return response.json()

    async def close(self) -> None:
        async with self._lock:
            if self._client is not None:
                try:
                    await self._client.aclose()
                except Exception:
                    logger.exception("MOEX client close failed")
                finally:
                    self._client = None
                    logger.info("MOEX client closed")

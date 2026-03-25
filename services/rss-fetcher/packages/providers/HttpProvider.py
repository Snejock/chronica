import httpx
import logging
from pydantic import HttpUrl

logger = logging.getLogger(__name__)


class HttpProvider:
    def __init__(self, timeout_sec: int = 10, proxy_url: str | None = None):
        self._client: httpx.AsyncClient | None = None
        self._timeout = timeout_sec
        self._proxy_url = proxy_url

    async def open(self):
        if self._client is None:
            self._client = httpx.AsyncClient(
                http2=True,
                timeout=self._timeout,
                follow_redirects=True,
                headers={"User-Agent": "rss-fetcher/1.0"},
                proxy=self._proxy_url
            )
            logger.info("HTTP client initialized")

    async def fetch(self, url: str | HttpUrl) -> str:
        if self._client is None:
            raise RuntimeError("Client not connected")

        response = await self._client.get(str(url))
        response.raise_for_status()
        return response.text

    async def close(self):
        if self._client:
            await self._client.aclose()
            self._client = None
            logger.info("HTTP client closed")

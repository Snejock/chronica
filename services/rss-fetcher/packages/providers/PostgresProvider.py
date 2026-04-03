import asyncio
import logging
import asyncpg

logger = logging.getLogger(__name__)


class PostgresProvider:
    """Провайдер для работы с базой данных Postgres"""

    def __init__(self, config):
        self.config = config
        self._pool = None
        self._lock = asyncio.Lock()

    async def open(self) -> None:
        async with self._lock:
            if self._pool is None:
                self._pool = await asyncpg.create_pool(
                    host=self.config.postgres.host,
                    port=self.config.postgres.port,
                    user=self.config.postgres.user,
                    password=self.config.postgres.password,
                    database=self.config.postgres.database
                )
                logger.info("Postgres connection pool created")

    async def close(self) -> None:
        async with self._lock:
            if self._pool is not None:
                await self._pool.close()
                self._pool = None
                logger.info("Postgres connection pool closed")

    async def execute(self, query: str, *args):
        if self._pool is None:
            await self.open()
        return await self._pool.execute(query, *args)

    async def fetch(self, query: str, *args):
        if self._pool is None:
            await self.open()
        return await self._pool.fetch(query, *args)

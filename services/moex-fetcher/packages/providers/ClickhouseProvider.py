import asyncio
import logging
from clickhouse_connect import get_async_client

logger = logging.getLogger(__name__)


class ClickhouseProvider:
    """Провайдер для работы с базой данных Clickhouse"""

    def __init__(self, config):
        self.config = config
        self._client = None
        self._lock = asyncio.Lock()

    async def connect(self) -> None:
        async with self._lock:
            if self._client is None:
                self._client = await get_async_client(
                    host=self.config.clickhouse.host,
                    port=self.config.clickhouse.port,
                    username=self.config.clickhouse.user,
                    password=self.config.clickhouse.password,
                    secure=getattr(self.config.clickhouse, "secure", False),
                )
                logger.info("Clickhouse client launched")

    async def close(self) -> None:
        async with self._lock:
            if self._client is not None:
                try:
                    await self._client.close()
                except Exception:
                    logger.exception("Clickhouse client close failed")
                finally:
                    self._client = None
                    logger.info("Clickhouse client closed")

    async def async_insert(self, table: str, columns: list, data: list):
        """
        Вставка данных в Clickhouse.

        :param table: Название таблицы (можно с именем базы: "db.table")
        :param columns: Список колонок
        :param data: Список значений одной строки
        """
        if self._client is None:
            await self.connect()
        try:
            await self._client.insert(
                table=table,
                column_names=columns,
                data=data,  # оборачиваем строку в список списков
                settings={
                    'async_insert': 1,
                    'wait_for_async_insert': 0
                }
            )

        except Exception:
            logger.exception(f"ClickhouseProvider error")

    async def query(self, sql: str, params: dict|None = None) -> list[tuple|list]:
        """
        Выполнить запрос и вернуть строки результата.
        :param sql: SQL запрос
        :param params: параметры запроса (placeholders: %(name)s)
        :return: list[list|tuple]
        """
        if self._client is None:
            await self.connect()
        try:
            response = await self._client.query(sql, parameters=params)
            return response.result_rows

        except Exception:
            logger.exception("ClickhouseProvider.query error")
            raise

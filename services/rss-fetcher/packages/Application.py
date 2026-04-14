import asyncio
import logging
import yaml
from datetime import datetime, timezone

from models import Config, RSSFeed, RSSFeedList, RSSNews
from packages.providers import HttpProvider, PostgresProvider, BrokerProvider
from packages.parsers import RSSFeedParser

logger = logging.getLogger(__name__)


class Application:
    def __init__(self, config_path: str = "./config/rss_feeds.yml", cursor: int | None = None):
        logger.info("Initialize application...")
        self.config = Config()
        self.feed_list = None
        self.http_provider = HttpProvider(
            timeout_sec=30,
            proxy_url=f"http://{self.config.proxy.user}:{self.config.proxy.password}@{self.config.proxy.host}:{self.config.proxy.port}"
        )
        self.pg_provider = PostgresProvider(config=self.config)
        self.br_provider = BrokerProvider(config=self.config)
        self.parser = RSSFeedParser()

    async def processing(self, feed: RSSFeed) -> None:
        logger.info(f"Starting worker for source: {feed.name}")
        if feed.cursor is None:
            await self._get_cursor(feed)

        try:
            while True:
                try:
                    response = await self.http_provider.fetch(feed.link)
                    item_list = self.parser.parse(response)
                    max_cursor = feed.cursor

                    for item in item_list:
                        try:
                            item = RSSNews(**item)

                            if item.published_utc > feed.cursor:
                                item.feed_id = feed.id
                                item.feed_nm = feed.name

                                # Отправка в брокер
                                payload = item.model_dump()
                                payload["published_utc"] = int(item.published_utc.timestamp())
                                self.br_provider.produce(payload, topic=self.config.rss_fetcher.topic)

                                if item.published_utc > max_cursor:
                                    max_cursor = item.published_utc

                        except Exception as err:
                            logger.warning(f"Invalid item in feed_nm {feed.name} (feed_id {feed.id}): {err}")
                            continue

                    # Курсор обновляется только после обработки всего батча
                    feed.cursor = max_cursor

                except Exception as err:
                    logger.error(f"Error in processing for feed_nm {feed.name} (feed_id {feed.id}): {err}", exc_info=True)

                await asyncio.sleep(feed.interval)

        except asyncio.CancelledError:
            logger.info(f"Worker for feed_nm {feed.name} (feed_id {feed.id}) was cancelled")

    async def run(self):
        """Запуск приложения: инициализация ресурсов и создание корутин"""
        try:
            logger.debug("Initializing providers...")
            await asyncio.gather(
                self.http_provider.open(),
                self.pg_provider.open(),
                self.br_provider.open(schema=self.config.rss_fetcher.schema_nm),
            )
            logger.info("All components have been successfully initialized")

            self.feed_list = await self._load_feeds_from_db()

            tasks = [asyncio.create_task(self.processing(feed)) for feed in self.feed_list]
            logger.info(f"Started {len(tasks)} workers. Press Ctrl+C to stop.")
            await asyncio.gather(*tasks)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.http_provider.close()
            await self.pg_provider.close()
            await self.br_provider.close()
            logger.info("Providers have been successfully closed")

    @staticmethod
    def _load_feeds_from_file(path: str) -> list[RSSFeed]:
        """Загрузка списка RSS-лент из YAML файла."""
        try:
            with open(path, "r") as f:
                data = yaml.safe_load(f)
                feed_list = RSSFeedList(**data)
                return feed_list.rss_feeds
        except FileNotFoundError:
            logger.error(f"RSS sources file not found: {path}")
            raise
        except Exception as err:
            logger.error(f"Failed to load feeds from file {path}: {err}")
            raise

    async def _load_feeds_from_db(self) -> list[RSSFeed]:
        """Загрузка списка RSS-лент из базы данных (Postgres)."""
        try:
            result = await self.pg_provider.fetch("""
                SELECT 
                    feed_id AS id, 
                    feed_nm AS name, 
                    feed_link AS link, 
                    feed_type AS type, 
                    country_code,
                    city_nm AS city, 
                    language_code,
                    interval_sec AS interval,
                    is_active
                FROM dtl.d_chr_rss_feeds 
                WHERE is_active = true;
            """)

            feeds = []
            for row in result:
                d = dict(row)

                # Формируем вложенную структуру для Location
                # (Pydantic требует объект location, а не плоские поля)
                d["location"] = {
                    "country_code": d.pop("country_code"),
                    "city": d.pop("city")
                }

                feeds.append(RSSFeed(**d))

            return feeds

        except Exception as err:
            logger.error(f"Failed to load feeds from database: {err}")

    async def _get_cursor(self, feed):
        logger.info("Getting initial cursor from database...")

        while True:
            try:
                result = await self.pg_provider.fetch(
                    """
                        SELECT max(published_utc)
                        FROM stg.chr_rss_news
                        WHERE feed_id = $1
                    """,
                    feed.id
                )

                if result and result[0][0] is not None:
                    feed.cursor = result[0][0].replace(tzinfo=timezone.utc)
                else:
                    logger.warning("Table is empty or NULL returned, setting cursor to min datetime")
                    feed.cursor = datetime.min.replace(tzinfo=timezone.utc)

                logger.info(f"Cursor initialized for feed_nm {feed.name} (feed_id {feed.id}): {feed.cursor}")
                return

            except Exception as err:
                logger.error(f"Failed to get cursor: {err}. Retrying in 5 seconds...")
                await asyncio.sleep(5)

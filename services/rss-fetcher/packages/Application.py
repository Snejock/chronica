import asyncio
import logging
import yaml
from datetime import datetime, timezone

from models import Config, RSSFeed, RSSFeedList, RSSItem
from packages.providers import RSSProvider, ClickhouseProvider, BrokerProvider
from packages.parsers import RSSFeedParser

logger = logging.getLogger(__name__)

TOPIC = "chronica.stg.rss_news"


class Application:
    def __init__(self, config_path: str = "./config/rss_feeds.yml", cursor: int | None = None):
        logger.info("Initialize application...")
        self.config = Config()
        self.feed_list = self._load_rss_feeds(config_path)
        self.topic = TOPIC

        logger.debug("Initializing providers...")
        self.ch_provider = ClickhouseProvider(config=self.config)
        self.rss_provider = RSSProvider(timeout_sec=10)
        self.br_provider = BrokerProvider(config=self.config)
        self.parser = RSSFeedParser()

        logger.info("All components have been successfully initialized")

    async def processing(self, feed: RSSFeed) -> None:
        logger.info(f"Starting worker for source: {feed.name}")
        if feed.cursor is None:
            await self._get_cursor(feed)

        try:
            while True:
                try:
                    response = await self.rss_provider.fetch(feed.link)
                    item_list = self.parser.parse(response)
                    max_cursor = feed.cursor

                    for item in item_list:
                        try:
                            item = RSSItem(**item)

                            if item.published_utc > feed.cursor:
                                item.feed_id = feed.id
                                item.feed_nm = feed.name

                                # Отправка в брокер
                                payload = item.model_dump()
                                payload["published_loc"] = item.published
                                payload["published_utc"] = int(item.published_utc.timestamp())
                                self.br_provider.produce(payload, topic=self.topic)

                                if item.published_utc > max_cursor:
                                    max_cursor = item.published_utc

                        except Exception as err:
                            logger.warning(f"Invalid item in feed {feed.name} (id {feed.id}): {err}")
                            continue

                    # Курсор обновляется только после обработки всего батча
                    feed.cursor = max_cursor

                except Exception as err:
                    logger.error(f"Error in processing for {feed.name} (id: {feed.id}): {err}", exc_info=True)

                await asyncio.sleep(feed.interval)

        except asyncio.CancelledError:
            logger.info(f"Worker for {feed.name} (id: {feed.id}) was cancelled")

    async def run(self):
        """Запуск приложения: инициализация ресурсов и создание корутин"""
        try:
            await asyncio.gather(
                self.rss_provider.open(),
                self.ch_provider.open(),
                self.br_provider.open(),
            )
            await self._init_db()

            tasks = [asyncio.create_task(self.processing(feed)) for feed in self.feed_list]
            logger.info(f"Started {len(tasks)} workers. Press Ctrl+C to stop.")
            await asyncio.gather(*tasks)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.rss_provider.close()
            await self.ch_provider.close()
            await self.br_provider.close()
            logger.info("Providers have been successfully closed")

    @staticmethod
    def _load_rss_feeds(path: str) -> list[RSSFeed]:
        """Загрузка и валидация списка RSS-лент."""
        try:
            with open(path, "r") as f:
                data = yaml.safe_load(f)
                feed_list = RSSFeedList(**data)
                return feed_list.rss_feeds
        except FileNotFoundError:
            logger.error(f"RSS sources file not found: {path}")
            raise
        except Exception as err:
            logger.error(f"Failed to parse RSS feed list: {err}")
            raise

    async def _init_db(self) -> None:
        try:
            await self.ch_provider.query("CREATE DATABASE IF NOT EXISTS chr_stg")

            await self.ch_provider.query(f"""
                CREATE TABLE IF NOT EXISTS chr_stg.kafka_rss_news
                (
                    source_system   LowCardinality(String),
                    news_id         String,
                    published_utc   DateTime,
                    feed_id         Int32,
                    feed_nm         LowCardinality(String),
                    title           String,
                    summary         Nullable(String),
                    link            Nullable(String)
                )
                ENGINE = Kafka
                SETTINGS kafka_broker_list = '{self.config.broker.host}:{self.config.broker.port}',
                         kafka_topic_list = '{self.topic}',
                         kafka_group_name = 'chronica.ch_rss_news',
                         kafka_format = 'AvroConfluent',
                         format_avro_schema_registry_url = '{self.config.broker.schema_registry_url}'
            """)

            await self.ch_provider.query("""
                CREATE TABLE IF NOT EXISTS chr_stg.rss_news
                (
                    loaded          DateTime DEFAULT now(),
                    source_system   LowCardinality(String),
                    news_id         String,
                    published_utc   DateTime,
                    feed_id         Int32,
                    feed_nm         LowCardinality(String),
                    title           String,
                    summary         String,
                    link            String
                )
                ENGINE = ReplacingMergeTree
                ORDER BY (published_utc, feed_id, news_id)                    
            """)

            await self.ch_provider.query("""
                CREATE MATERIALIZED VIEW IF NOT EXISTS chr_stg.mv_rss_news TO chr_stg.rss_news AS
                SELECT
                    source_system,
                    news_id,
                    published_utc,
                    feed_id,
                    feed_nm,
                    title,
                    coalesce(summary, '')   AS summary,
                    coalesce(link, '')      AS link
                FROM chr_stg.kafka_rss_news
            """)

            logger.info("ClickHouse schema ensured (database/table present)")
        except Exception:
            logger.exception("Failed to initialize ClickHouse schema")
            raise

    async def _get_cursor(self, feed):
        logger.info("Getting initial cursor from ClickHouse...")

        while True:
            try:
                result = await self.ch_provider.query(
                    """
                        SELECT max(published_utc)
                        FROM chr_stg.rss_news
                        WHERE feed_id = {feed_id:int}
                    """,
                    {"feed_id": feed.id}
                )

                if result and result[0][0] is not None:
                    feed.cursor = result[0][0].replace(tzinfo=timezone.utc)
                else:
                    logger.warning("Table is empty or NULL returned, setting cursor to min datetime")
                    feed.cursor = datetime.min.replace(tzinfo=timezone.utc)

                logger.info(f"Cursor initialized for {feed.name} (id: {feed.id}): {feed.cursor}")
                return

            except Exception as err:
                logger.error(f"Failed to get cursor: {err}. Retrying in 5 seconds...")
                await asyncio.sleep(5)

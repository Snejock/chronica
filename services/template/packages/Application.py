import asyncio
import logging

from packages.models.config import AppConfig
from packages.providers import BrokerProvider

logger = logging.getLogger(__name__)


class Application:
    def __init__(self):
        logger.info("Initializing application...")
        self.config = AppConfig.load()
        self.br_provider = BrokerProvider(config=self.config)

    async def processing(self, key: str, data: dict):
        """Бизнес-логика обработки одного сообщения из брокера."""
        try:
            logger.info(f"Processing message key={key}")
            # TODO: реализовать обработку сообщения
        except Exception as e:
            logger.error(f"Error processing message key={key}: {e}", exc_info=True)

    async def run(self):
        """Инициализация провайдеров и запуск основного цикла."""
        try:
            logger.debug("Initializing providers...")
            await self.br_provider.open(topic=self.config.broker.topic_in)
            logger.info("All providers initialized")

            await self.br_provider.consume_loop(self.processing)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.br_provider.close()
            logger.info("Providers closed")
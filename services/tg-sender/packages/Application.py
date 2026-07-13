import asyncio
import logging

from models import Config
from packages.providers import BrokerProvider, TelegramProvider

logger = logging.getLogger(__name__)

TOPIC = "story_subscriber_news"


class Application:
    def __init__(self):
        logger.info("Initializing application...")
        self.config = Config()
        self.br_provider = BrokerProvider(config=self.config)
        self.tg_provider = TelegramProvider(config=self.config)

    async def processing(self, key: str, data: dict) -> None:
        """Отправка одной новости подписанного сюжета в Telegram."""
        try:
            chat_id = data["chat_id"]
            caption_parts = [p for p in (data.get("story_nm"), data.get("title_txt")) if p]
            caption = "\n\n".join(caption_parts)
            if data.get("summary_txt"):
                caption = f"{caption}\n\n{data['summary_txt']}"

            image_url = data.get("image_url") or ""
            if image_url:
                await self.tg_provider.send_photo(chat_id, image_url, caption)
            else:
                await self.tg_provider.send_message(chat_id, caption)

            logger.info(f"Sent news_id={data.get('news_id')} to chat_id={chat_id}")
        except Exception as e:
            logger.error(f"Error processing message key={key}: {e}", exc_info=True)

    async def run(self):
        """Инициализация провайдеров и запуск основного цикла."""
        try:
            logger.debug("Initializing providers...")
            await self.tg_provider.connect()
            await self.br_provider.open(topic=TOPIC)
            logger.info("All providers initialized")

            await self.br_provider.consume_loop(self.processing)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.br_provider.close()
            await self.tg_provider.close()
            logger.info("Providers closed")

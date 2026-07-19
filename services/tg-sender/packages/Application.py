import asyncio
import html
import logging
from datetime import datetime
from zoneinfo import ZoneInfo

from babel.core import UnknownLocaleError
from babel.dates import format_datetime

from models import Config
from packages.providers import BrokerProvider, TelegramProvider

logger = logging.getLogger(__name__)
TOPIC = "tg_notifications"
CONSUMER_GROUP_ID = "TG-SENDER"
MOSCOW_TZ = ZoneInfo("Europe/Moscow")
DEFAULT_LOCALE = "ru"
FEED_FALLBACK_NM = {"ru": "Источник", "en": "Source"}


class Application:
    def __init__(self):
        logger.info("Initializing application...")
        self.config = Config()
        self.br_provider = BrokerProvider(config=self.config)
        self.tg_provider = TelegramProvider(config=self.config)

    @staticmethod
    def _format_published_dttm(raw_dttm: str | None, language_code: str | None) -> str:
        """Приводит ISO-строку даты публикации (UTC) к читаемому виду по Москве на языке подписчика."""
        if not raw_dttm:
            return ""
        try:
            dt = datetime.fromisoformat(raw_dttm).astimezone(MOSCOW_TZ)
            return format_datetime(dt, "d MMMM y HH:mm", locale=language_code or DEFAULT_LOCALE)
        except (ValueError, UnknownLocaleError):
            logger.warning(f"Could not format published_dttm={raw_dttm!r} for locale={language_code!r}")
            return ""

    async def processing(self, key: str, data: dict) -> None:
        """Отправка одной новости подписанного сюжета в Telegram."""
        try:
            chat_id = int(data["channel_link"])
            language_code = data.get("language_code") or DEFAULT_LOCALE
            story_nm = html.escape(data.get("story_nm") or "")
            title_txt = html.escape(data.get("title_txt") or "")
            summary_txt = html.escape(data.get("summary_txt") or "")
            feed_nm = html.escape(data.get("feed_nm") or FEED_FALLBACK_NM.get(language_code, FEED_FALLBACK_NM[DEFAULT_LOCALE]))
            news_link = html.escape(data.get("news_link") or "", quote=True)
            published_dttm = self._format_published_dttm(data.get("published_dttm"), language_code)

            # сборка сообщения
            caption = story_nm
            if title_txt:
                caption = f"{caption}\n\n<b>{title_txt}</b>" if caption else f"<b>{title_txt}</b>"

            if summary_txt:
                caption = f"{caption}\n{summary_txt}"

            # сборка мета данных
            meta = published_dttm
            if news_link:
                link = f'<a href="{news_link}">{feed_nm}</a>'
                meta = f"{meta} · {link}" if meta else link
            if meta:
                caption = f"{caption}\n\n{meta}"

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
            await self.tg_provider.open()
            await self.br_provider.open(topic=TOPIC, group_id=CONSUMER_GROUP_ID)
            logger.info("All providers initialized")

            await self.br_provider.consume_loop(self.processing)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.br_provider.close()
            await self.tg_provider.close()
            logger.info("Providers closed")

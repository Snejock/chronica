import asyncio
import logging
import signal

from packages.Application import Application
from packages.logger.logger_setup import logger_setup

logger = logging.getLogger(__name__)


def handle_sigterm(signum, frame):
    raise SystemExit("Received SIGTERM from Docker")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, handle_sigterm)  # для корректного завершения процесса при закрытии контейнера
    try:
        logger_setup(log_file_path="log/rss-fetcher.log", level=logging.INFO)
        app = Application()
        # Запускаем основной цикл приложения
        asyncio.run(app.run())
    except (KeyboardInterrupt, SystemExit) as err:
        logger.info(f"Stopping service: {err}")

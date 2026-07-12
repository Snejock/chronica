import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path

DEFAULT_FORMAT = "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
DATETIME_FORMAT = "%Y-%m-%d %H:%M:%S"

_def_configured = False


def logger_setup(log_file_path: str = "log/main.log", level: int = logging.INFO) -> logging.Logger:
    global _def_configured
    root_logger = logging.getLogger()
    if _def_configured:
        return root_logger

    Path(log_file_path).parent.mkdir(parents=True, exist_ok=True)

    root_logger.setLevel(level)

    # Консоль
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(logging.Formatter(DEFAULT_FORMAT, datefmt=DATETIME_FORMAT))

    # Файл с ротацией
    file_handler = RotatingFileHandler(log_file_path, maxBytes=5_000_000, backupCount=3, encoding="utf-8")
    file_handler.setLevel(level)
    file_handler.setFormatter(logging.Formatter(DEFAULT_FORMAT, datefmt=DATETIME_FORMAT))

    root_logger.addHandler(console_handler)
    root_logger.addHandler(file_handler)

    _def_configured = True
    root_logger.info("Logging setup complete")
    return root_logger

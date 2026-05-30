import asyncio
import logging
import yaml
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from config.schema import AppConfig
from packages.providers import ClickhouseProvider, MoexProvider
from packages.utils import MoexCalendar

logger = logging.getLogger(__name__)


class Application:
    def __init__(self, config_path: str = "./config/config.yml", cursor: int | None = None):
        logger.info("Initialize applications...")
        self.config = self._load_config(config_path)
        self.cursor = cursor
        self.calendar = MoexCalendar(self.config.moex_calendar)
        self.tz_local = ZoneInfo(self.config.moex_calendar.timezone)
        self.tz_utc = timezone.utc

        logger.debug("Initializing providers...")
        self.ch_provider = ClickhouseProvider(config=self.config)
        self.moex_provider = MoexProvider(config=self.config, timeout_sec=10)

        logger.info("All components have been successfully initialized")

    async def main_process(self):
        try:
            logger.info("Launching the clients...")
            await asyncio.gather(
                self.ch_provider.connect(),
                self.moex_provider.connect()
            )
            await self._init_db()

            logger.info("Application is running, press Ctrl+C to stop")

            if self.cursor is None:
                await self._get_cursor()

            while True:
                await self._wait_until_market_open()

                try:
                    data = await self.moex_provider.fetch(
                        url="https://iss.moex.com/iss/engines/stock/markets/shares/trades.json",
                        cursor=self.cursor
                    )
                    columns = data.get("trades", {}).get("columns", [])
                    rows = data.get("trades", {}).get("data", [])
                    loaded_dttm = datetime.now(self.tz_utc)

                    # Порядок колонок может измениться, поэтому здесь выполняется определение индекса колонок
                    if rows and columns:
                        try:
                            idx = {col: i for i, col in enumerate(columns)}
                            if "TRADENO" not in idx or "TRADETIME" not in idx:
                                logger.error("Critical columns missing in MOEX response")
                                await asyncio.sleep(5)
                                continue

                        except Exception as e:
                            logger.error(f"Error parsing columns: {e}")
                            await asyncio.sleep(5)
                            continue

                        payload = []
                        max_cursor = self.cursor

                        # сборка payload для вставки
                        for i in rows:
                            current_cursor = i[idx["TRADENO"]]

                            if current_cursor > max_cursor:
                                max_cursor = current_cursor

                            # приведение времени к UTC
                            trade_local = datetime.strptime(
                                f"{i[idx["TRADEDATE"]]} {i[idx["TRADETIME"]]}", "%Y-%m-%d %H:%M:%S"
                            ).replace(tzinfo=self.tz_local)
                            trade_utc = trade_local.astimezone(self.tz_utc)

                            systime_local = datetime.strptime(i[idx["SYSTIME"]], "%Y-%m-%d %H:%M:%S"
                            ).replace(tzinfo=self.tz_local)
                            systime_utc = systime_local.astimezone(self.tz_utc)

                            row = [
                                loaded_dttm,
                                "MSS",
                                i[idx["TRADENO"]],
                                trade_utc,
                                i[idx["BOARDID"]],
                                i[idx["SECID"]],
                                i[idx["PRICE"]],
                                i[idx["QUANTITY"]],
                                i[idx["VALUE"]],
                                i[idx["PERIOD"]],
                                i[idx["TRADETIME_GRP"]],
                                systime_utc,
                                i[idx["BUYSELL"]],
                                i[idx["DECIMALS"]],
                                i[idx["TRADINGSESSION"]],
                                datetime.strptime(i[idx["TRADE_SESSION_DATE"]], "%Y-%m-%d").date()
                            ]

                            payload.append(row)

                        # Вставка данных
                        if payload:
                            logger.info(f"Insert {len(payload)} trades, last id: {max_cursor}")

                            await self.ch_provider.async_insert(
                                table="ods.moex_trades",
                                columns=[
                                    "loaded_dttm",
                                    "source_system",
                                    "trade_no",
                                    "trade_dttm",
                                    "board_id",
                                    "sec_id",
                                    "price_amt",
                                    "quantity_cnt",
                                    "trade_value",
                                    "period_code",
                                    "tradetime_grp",
                                    "systime_dttm",
                                    "buysell_code",
                                    "decimals_cnt",
                                    "tradingsession_code",
                                    "trade_session_dt"
                                ],
                                data=payload
                            )

                            # Обновляем курсор только после успешной вставки
                            self.cursor = max_cursor
                    else:
                        logger.debug("Received empty trades list")

                except Exception as e:
                    logger.exception("Unexpected error in main loop")

                await asyncio.sleep(0.5)

        except asyncio.CancelledError:
            logger.info("Application stopping...")
        finally:
            logger.info("Cleaning up resources...")
            await self.moex_provider.close()
            await self.ch_provider.close()
            logger.info("Providers have been successfully closed")

    def run(self):
        try:
            asyncio.run(self.main_process())
        except KeyboardInterrupt:
            logger.info("Application stopping...")

    @staticmethod
    def _load_config(path: str) -> AppConfig:
        try:
            with open(path, "r") as f:
                data = yaml.safe_load(f)
                return AppConfig(**data)
        except FileNotFoundError:
            raise FileNotFoundError(f"Config file not found: {path}")

    async def _init_db(self) -> None:
        try:
            await self.ch_provider.query("CREATE DATABASE IF NOT EXISTS ods")

            await self.ch_provider.query("""
                CREATE TABLE IF NOT EXISTS ods.moex_trades
                (
                    loaded_dttm         DateTime('UTC'),
                    source_system       LowCardinality(String),
                    trade_no            UInt64,
                    trade_dttm          DateTime('UTC'),
                    board_id            LowCardinality(String),
                    sec_id              LowCardinality(String),
                    price_amt           Decimal(18, 6),
                    quantity_cnt        UInt64,
                    trade_value         Decimal(18, 6),
                    period_code         LowCardinality(String),
                    tradetime_grp       Int32,
                    systime_dttm        DateTime('UTC'),
                    buysell_code        LowCardinality(String),
                    decimals_cnt        UInt8,
                    tradingsession_code LowCardinality(String),
                    trade_session_dt    Date,
                
                    INDEX idx_sec_id sec_id TYPE set(100) GRANULARITY 1,
                    INDEX idx_trade_dttm trade_dttm TYPE minmax GRANULARITY 1
                )
                ENGINE = ReplacingMergeTree
                PARTITION BY toYYYYMM(trade_dttm)
                ORDER BY (sec_id, trade_dttm, trade_no)
                SETTINGS index_granularity = 8192
            """)
            logger.info("ClickHouse schema ensured (database/table present)")
        except Exception:
            logger.exception("Failed to initialize ClickHouse schema")
            raise

    async def _get_cursor(self):
        logger.info("Getting initial cursor from ClickHouse...")

        while True:
            try:
                result = await self.ch_provider.query(sql="SELECT max(trade_no) FROM ods.moex_trades")

                if result and result[0] and result[0][0] is not None:
                    self.cursor = int(result[0][0])
                else:
                    logger.warning("Table is empty or NULL returned, setting cursor to 0")
                    self.cursor = 0

                logger.info(f"Cursor initialized: {self.cursor}")
                return

            except Exception as e:
                logger.error(f"Failed to get cursor: {e}. Retrying in 5 seconds...")
                await asyncio.sleep(5)

    async def _wait_until_market_open(self):
        if self.calendar.is_open():
            return
        next_open_dttm = self.calendar.get_next_open_dttm()
        now_dttm = datetime.now(self.calendar.timezone)
        wait_sec = max(0, int((next_open_dttm - now_dttm).total_seconds()))
        logger.info(f"MOEX is closed. Waiting {timedelta(seconds=int(wait_sec))} until it opens at: {next_open_dttm.isoformat()}")
        await asyncio.sleep(wait_sec)

from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Annotated
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent.parent
ENV_PATH = BASE_DIR / "common" / ".env"


class RSSFetcherConfig(BaseModel):
    topic: str = "stg_rss_news"
    schema_nm: str = "RSSNews"

class BrokerConfig(BaseModel):
    host: str
    port: int
    client_id: str
    schema_registry_url: str
    linger_ms: int
    batch_size: int
    compression_type: str
    acks: int

class ClickhouseConfig(BaseModel):
    host: str
    port: int
    user: str
    password: str
    secure: bool

class PostgresConfig(BaseModel):
    host: str
    port: int
    user: str
    password: str
    database: str

class GoogleAIConfig(BaseModel):
    api_key: str

class ProxyConfig(BaseModel):
    host: str
    port: int
    user: str
    password: str

class Config(BaseSettings):
    broker: Annotated[BrokerConfig | None, Field(default=None)]
    clickhouse: Annotated[ClickhouseConfig | None, Field(default=None)]
    postgres: Annotated[PostgresConfig | None, Field(default=None)]
    google_ai: Annotated[GoogleAIConfig | None, Field(default=None)]
    proxy: Annotated[ProxyConfig | None, Field(default=None)]
    rss_fetcher: Annotated[RSSFetcherConfig | None, Field(default=RSSFetcherConfig())]

    model_config = SettingsConfigDict(
        env_file=ENV_PATH,
        env_file_encoding="utf-8",
        env_nested_delimiter="__"
    )

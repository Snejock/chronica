import yaml
from pydantic import BaseModel


class BrokerConfig(BaseModel):
    host: str
    port: int
    client_id: str
    schema_registry_url: str
    topic_in: str
    topic_out: str
    linger_ms: int = 5
    batch_size: int = 65536
    compression_type: str = "lz4"
    acks: int = 1


class AppConfig(BaseModel):
    broker: BrokerConfig
    # TODO: добавить конфиги других провайдеров

    @classmethod
    def load(cls, path: str = "./config/config.yaml") -> "AppConfig":
        with open(path, "r") as f:
            return cls(**yaml.safe_load(f))
import asyncio
import logging
from confluent_kafka import SerializingProducer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import StringSerializer

logger = logging.getLogger(__name__)

RSS_NEWS_SCHEMA = """
{
    "type": "record",
    "name": "RSSNews",
    "namespace": "chronica",
    "fields": [
        {"name": "source_system", "type": "string"},
        {"name": "published_loc", "type": "string"},
        {"name": "published_utc", "type": "long"},
        {"name": "feed_id", "type": "int"},
        {"name": "feed_nm", "type": "string"},
        {"name": "title", "type": "string"},
        {"name": "summary", "type": ["null", "string"], "default": null},
        {"name": "link", "type": ["null", "string"], "default": null}
    ]
}
"""


class BrokerProvider:
    def __init__(self, config):
        self.config = config.broker
        self._producer = None
        self._lock = asyncio.Lock()

    async def open(self) -> None:
        async with self._lock:
            if self._producer is None:
                try:
                    schema_registry_url = self.config.schema_registry_url
                    sr_client = SchemaRegistryClient({'url': schema_registry_url})
                    avro_serializer = AvroSerializer(
                        schema_registry_client=sr_client,
                        schema_str=RSS_NEWS_SCHEMA,
                        conf={'auto.register.schemas': True}
                    )
                    string_serializer = StringSerializer('utf_8')


                    conf = {
                        'bootstrap.servers': f"{self.config.host}:{self.config.port}",
                        'client.id': self.config.client_id,
                        "linger.ms": self.config.linger_ms,
                        "batch.size": self.config.batch_size,
                        "compression.type": self.config.compression_type,
                        "acks": self.config.acks,
                        'key.serializer': string_serializer,
                        'value.serializer': avro_serializer,
                    }
                    self._producer = SerializingProducer(conf)
                    logger.info("Broker avro producer initialized")

                except Exception:
                    logger.exception("Failed to initialize broker producer")
                    raise

    async def close(self) -> None:
        async with self._lock:
            if self._producer is not None:
                loop = asyncio.get_running_loop()
                await loop.run_in_executor(None, self._producer.flush)
                self._producer = None
                logger.info("Broker producer closed")

    def produce(self, message: dict, topic: str) -> None:
        if self._producer is None:
            raise RuntimeError("Producer is not connected")

        try:
            self._producer.produce(
                topic=topic,
                key=str(message["link"]),
                value=message,
                on_delivery=self._delivery_report
            )
        except Exception:
            logger.exception("Error producing to broker")

        # Вызывается poll(0) для обработки внутренних событий библиотеки
        self._producer.poll(0)

    @staticmethod
    def _delivery_report(err, msg):
        """
        Вызывается один раз для каждого сообщения при успешной доставке или ошибке.
        Выполняется внутри метода poll() или flush().
        """
        if err is not None:
            logger.error(f"Message delivery failed: {err}")
        else:
            logger.debug(f"Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}")

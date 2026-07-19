import asyncio
import logging
from confluent_kafka import DeserializingConsumer, SerializingProducer, KafkaError
from confluent_kafka.serialization import StringDeserializer, StringSerializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer, AvroSerializer

logger = logging.getLogger(__name__)


class BrokerProvider:
    def __init__(self, config):
        self.config = config.broker
        self._consumer = None
        self._producer = None
        self._lock = asyncio.Lock()
        self._running = False

    async def open(self, topic: str, group_id: str, avro_schema: str | None = None) -> None:
        """
        Открывает AVRO-consumer и подписывается на topic.
        avro_schema — JSON-строка схемы; если None, схема берётся из Schema Registry.
        """
        async with self._lock:
            if self._consumer is not None:
                return
            try:
                sr_client = SchemaRegistryClient({"url": self.config.schema_registry_url})
                avro_deserializer = AvroDeserializer(
                    schema_registry_client=sr_client,
                    schema_str=avro_schema,
                )
                conf = {
                    "bootstrap.servers": f"{self.config.host}:{self.config.port}",
                    "group.id": group_id,
                    "auto.offset.reset": "earliest",
                    "enable.auto.commit": False,
                    "key.deserializer": StringDeserializer("utf_8"),
                    "value.deserializer": avro_deserializer,
                }
                self._consumer = DeserializingConsumer(conf)
                self._consumer.subscribe([topic])
                self._running = True
                logger.info(f"Consumer started. Subscribed to: {topic}")
            except Exception:
                logger.exception("Failed to start consumer")
                raise

    async def consume_loop(self, callback) -> None:
        """Бесконечный цикл чтения; callback(key, data) вызывается на каждое сообщение."""
        if self._consumer is None:
            raise RuntimeError("Consumer is not open")

        logger.info("Starting consume loop...")
        loop = asyncio.get_running_loop()

        while self._running:
            try:
                message = await loop.run_in_executor(None, self._consumer.poll, 1.0)
                if message is None:
                    continue
                if message.error():
                    if message.error().code() != KafkaError._PARTITION_EOF:
                        logger.error(f"Consumer error: {message.error()}")
                    continue

                await callback(message.key(), message.value())
                await loop.run_in_executor(None, self._consumer.commit, message)

            except Exception as e:
                logger.error(f"Error in consume loop: {e}", exc_info=True)
                await asyncio.sleep(1)

    async def produce(self, topic: str, key: str, message: dict) -> None:
        """Отправляет сообщение в topic."""
        if self._producer is None:
            raise RuntimeError("Producer is not open")

        loop = asyncio.get_running_loop()
        await loop.run_in_executor(
            None,
            lambda: self._producer.produce(
                topic=topic,
                key=key,
                value=message,
                on_delivery=self._delivery_report,
            ),
        )
        await loop.run_in_executor(None, self._producer.poll, 0)

    async def close(self) -> None:
        async with self._lock:
            self._running = False
            if self._producer is not None:
                try:
                    await asyncio.get_running_loop().run_in_executor(None, self._producer.flush, 10)
                except Exception as e:
                    logger.warning(f"Error flushing producer: {e}")
                self._producer = None
                logger.info("Producer closed")
            if self._consumer is not None:
                try:
                    self._consumer.close()
                except Exception as e:
                    logger.warning(f"Error closing consumer: {e}")
                self._consumer = None
                logger.info("Consumer closed")

    def _delivery_report(self, err, msg):
        if err is not None:
            logger.error(f"Delivery failed: {err}")
        else:
            logger.debug(f"Delivered to {msg.topic()} [{msg.partition()}] offset {msg.offset()}")

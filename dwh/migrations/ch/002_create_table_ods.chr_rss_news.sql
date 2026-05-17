CREATE TABLE IF NOT EXISTS ods.kafka_rss_news
(
    source_system   LowCardinality(String),
    published_dttm   DateTime,
    feed_id         Int32,
    feed_nm         LowCardinality(String),
    title           String,
    summary         Nullable(String),
    link            Nullable(String)
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'dwh-rp-1:9092',
         kafka_topic_list = 'ods.rss_news',
         kafka_group_name = 'ch.rss_news',
         kafka_format = 'AvroConfluent',
         format_avro_schema_registry_url = 'http://dwh-rp-1:8081'
;

CREATE TABLE IF NOT EXISTS ods.rss_news
(
    loaded              DateTime DEFAULT now(),
    source_system       LowCardinality(String),
    news_id             UInt64,
    published_dttm       DateTime,
    feed_id             Int32,
    feed_nm             LowCardinality(String),
    title               String,
    summary             String,
    link                String
)
ENGINE = ReplacingMergeTree
ORDER BY (news_id)
;

CREATE MATERIALIZED VIEW IF NOT EXISTS ods.mv_rss_news TO ods.rss_news AS
    SELECT
        source_system,
        xxHash64(link)          AS news_id,
        published_dttm,
        feed_id,
        feed_nm,
        title,
        coalesce(summary, '')   AS summary,
        coalesce(link, '')      AS link
    FROM ods.kafka_rss_news
;
CREATE TABLE IF NOT EXISTS chr_stg.kafka_rss_news
(
    source_system   LowCardinality(String),
    published_utc   DateTime,
    feed_id         Int32,
    feed_nm         LowCardinality(String),
    title           String,
    summary         Nullable(String),
    link            Nullable(String)
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'dwh-rp-1:9092',
         kafka_topic_list = 'chronica.stg.rss_news',
         kafka_group_name = 'chronica.ch.rss_news',
         kafka_format = 'AvroConfluent',
         format_avro_schema_registry_url = 'http://dwh-rp-1:8081'
;

CREATE TABLE IF NOT EXISTS chr_stg.rss_news
(
    loaded              DateTime DEFAULT now(),
    source_system       LowCardinality(String),
    news_id             UInt64,
    published_utc       DateTime,
    feed_id             Int32,
    feed_nm             LowCardinality(String),
    title               String,
    summary             String,
    link                String
)
ENGINE = ReplacingMergeTree
ORDER BY (news_id)
;

CREATE MATERIALIZED VIEW IF NOT EXISTS chr_stg.mv_rss_news TO chr_stg.rss_news AS
    SELECT
        source_system,
        xxHash64(link)          AS news_id,
        published_utc,
        feed_id,
        feed_nm,
        title,
        coalesce(summary, '')   AS summary,
        coalesce(link, '')      AS link
    FROM chr_stg.kafka_rss_news
;
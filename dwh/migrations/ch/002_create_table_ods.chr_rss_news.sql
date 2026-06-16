DROP TABLE IF EXISTS ods.kafka_rss_news;
CREATE TABLE IF NOT EXISTS ods.kafka_rss_news
(
    source_system   LowCardinality(String),
    published_utc   DateTime,
    feed_id         Int32,
    feed_nm         LowCardinality(String),
    title           String,
    summary         Nullable(String),
    link            Nullable(String),
    image_url       Nullable(String)
)
ENGINE = Kafka
SETTINGS kafka_broker_list = 'dwh-rp-1:9092',
         kafka_topic_list = 'rss_news',
         kafka_group_name = 'LOAD_CH_ODS_RSS_NEWS',
         kafka_format = 'AvroConfluent',
         format_avro_schema_registry_url = 'http://dwh-rp-1:8081'
;

DROP TABLE IF EXISTS ods.rss_news;
CREATE TABLE IF NOT EXISTS ods.rss_news
(
    _loaded_dttm        DateTime DEFAULT now(),
    _source_system      LowCardinality(String),
    news_id             String,
    published_dttm      DateTime,
    feed_id             Int32,
    feed_nm             LowCardinality(String),
    title               String,
    summary             String,
    link                String,
    image_url           String
)
ENGINE = ReplacingMergeTree
ORDER BY (news_id)
;

DROP VIEW IF EXISTS ods.mv_rss_news;
CREATE MATERIALIZED VIEW IF NOT EXISTS ods.mv_rss_news TO ods.rss_news AS
    SELECT
        source_system           AS _source_system,
        lower(hex(xxHash64(coalesce(link, '')))) AS news_id,
        published_utc           AS published_dttm,
        feed_id,
        feed_nm,
        title,
        coalesce(summary, '')   AS summary,
        coalesce(link, '')      AS link,
        coalesce(image_url, '') AS image_url
    FROM ods.kafka_rss_news
;
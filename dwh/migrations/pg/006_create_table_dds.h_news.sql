CREATE TABLE IF NOT EXISTS dds.h_news (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    _source_system  text,
    news_id         text CONSTRAINT h_news__news_id_pk PRIMARY KEY,
    news_link       text,
    published_dttm  timestamp(0) with time zone,
    feed_id         integer
);
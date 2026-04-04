DROP TABLE IF EXISTS dtl.h_chr_rss_news;
CREATE TABLE IF NOT EXISTS dtl.h_chr_rss_news (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    _source_system  text,
    news_id         text PRIMARY KEY,
    news_link       text,
    published_utc   timestamp(0),
    feed_id         integer
);
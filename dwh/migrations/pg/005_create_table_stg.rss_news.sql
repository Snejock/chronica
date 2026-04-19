CREATE TABLE IF NOT EXISTS stg.rss_news (
    _loaded_dttm   timestamp(0) default now(),
    _source_system text,
    published_utc  timestamp(0),
    feed_id        integer,
    feed_nm        text,
    title          text,
    summary        text,
    link           text
);
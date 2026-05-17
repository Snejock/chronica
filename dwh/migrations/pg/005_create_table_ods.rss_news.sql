CREATE TABLE IF NOT EXISTS ods.rss_news (
    _loaded_dttm   timestamp(0) with time zone DEFAULT now(),
    _source_system text,
    published_dttm  timestamp(0) with time zone,
    feed_id        integer,
    feed_nm        text,
    title          text,
    summary        text,
    link           text
);
CREATE TABLE IF NOT EXISTS dtl.d_rss_feeds (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    feed_id         integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    feed_nm         text,
    feed_link       text,
    feed_type       text,
    country_code    text,
    city_nm         text,
    language_code   text,
    interval_sec    smallint,
    is_active       boolean
);
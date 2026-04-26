CREATE OR REPLACE VIEW dm.rss_feeds AS
SELECT
    feed_id
    , feed_nm
    , feed_link
    , feed_type
    , country_code
    , city_nm
    , language_code
    , interval_sec
    , is_active
FROM dtl.d_rss_feeds
;
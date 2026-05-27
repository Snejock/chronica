-- DROP VIEW IF EXISTS bds.b_rss_feeds;
CREATE OR REPLACE VIEW bds.b_rss_feeds AS
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
FROM dds.d_rss_feeds
;
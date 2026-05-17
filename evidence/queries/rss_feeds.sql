SELECT
    feed_id
    , feed_nm
    , feed_link
    , feed_type
    , country_code
    , city_nm
    , language_code
FROM dwh_pg_1.rss_feeds
WHERE is_active
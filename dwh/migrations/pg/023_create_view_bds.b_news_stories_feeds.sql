-- DROP VIEW IF EXISTS bds.b_news_stories_feeds;
CREATE OR REPLACE VIEW bds.b_news_stories_feeds AS
SELECT
    n.story_id
    , n.news_id
    , n.model_nm
    , n.published_dttm
    , h.news_link
    , f.feed_nm
    , f.feed_type
    , f.country_code
    , f.city_nm
    , f.language_code
    , n.distance_prt
    , m.image_url
FROM dds.t_news_stories n
JOIN dds.h_news h ON n.news_id = h.news_id
JOIN dds.d_rss_feeds f ON h.feed_id = f.feed_id
LEFT JOIN dds.s_news_media m ON m.news_id = n.news_id
;
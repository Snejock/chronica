SELECT
    b.story_id
    , b.news_id
    , b.published_dttm
    , b.news_link
    , b.feed_nm
    , b.feed_type
    , b.country_code
    , b.city_nm
    , s.title_txt
    , s.summary_txt
FROM bds.b_news_stories_feeds b
LEFT JOIN dds.s_news_texts s ON s.news_id = b.news_id
      AND s.language_code = 'ru'
WHERE b.model_nm = 'embeddinggemma:300m'
ORDER BY b.story_id, b.news_id, b.model_nm, s.model_nm
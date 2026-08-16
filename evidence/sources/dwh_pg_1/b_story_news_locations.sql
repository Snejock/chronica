SELECT
    b.story_id
    , b.location_id
    , b.news_id
    , b.published_dttm
    , b.news_link
    , b.location_nm
    , b.canonical_nm
    , b.location_type
    , b.confidence_prt
    , b.geo_lat
    , b.geo_lon
    , b.continent_code
    , b.country_code
    , b.region_nm
    , b.feature_code
    -- метаданные источника новости для ленты на странице локации; country_code
    -- фида переименован, чтобы не столкнуться со страной самой локации выше
    , f.feed_nm
    , f.feed_type
    , f.country_code AS news_country_code
    , f.city_nm
    , f.image_url
    , s.title_txt
    , s.summary_txt
FROM bds.b_story_news_locations b
LEFT JOIN bds.b_story_feed_news f
      ON f.story_id = b.story_id
     AND f.news_id = b.news_id
     AND f.model_nm = b.model_nm
LEFT JOIN dds.s_news_texts s ON s.news_id = b.news_id
      AND s.language_code = 'ru'
WHERE b.model_nm = 'embeddinggemma:300m'
ORDER BY b.story_id, b.location_id, b.news_id, b.model_nm, s.model_nm

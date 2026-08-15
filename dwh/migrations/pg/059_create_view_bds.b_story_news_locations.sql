DROP VIEW IF EXISTS bds.b_story_news_locations;
CREATE OR REPLACE VIEW bds.b_story_news_locations AS
SELECT
    tsn.story_id
    , tnl.location_id
    , u.news_id
    , u.model_nm
    , u.published_dttm
    , h.news_link
    , u.language_code
    , tnl.location_nm
    , tnl.confidence_prt
    , coalesce(d.canonical_nm, en.canonical_nm) AS canonical_nm
    , hl.location_type
    , g.geo_lat
    , g.geo_lon
    , g.continent_code
    , g.country_code
    , g.region_nm
    , g.feature_code
FROM bds.b_unews u
JOIN dds.t_story_news tsn
    ON tsn.news_id = u.news_id
   AND tsn.model_nm = u.model_nm
JOIN dds.t_news_locations tnl
    ON tnl.news_id = u.news_id
JOIN dds.h_news h ON h.news_id = u.news_id
JOIN dds.h_locations hl ON hl.location_id = tnl.location_id
LEFT JOIN dds.s_location_details d
    ON d.location_id = tnl.location_id
   AND d.language_code = u.language_code
LEFT JOIN dds.s_location_details en
    ON en.location_id = tnl.location_id
   AND en.language_code = 'en'
LEFT JOIN dds.s_location_geo g ON g.location_id = tnl.location_id
WHERE u.language_code = 'ru'
;
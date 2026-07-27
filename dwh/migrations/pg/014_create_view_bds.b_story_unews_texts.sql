-- DROP VIEW IF EXISTS bds.b_story_unews_texts;
CREATE OR REPLACE VIEW bds.b_story_unews_texts AS
-- связь story<->news взята из dds.t_story_news (anchor/LLM-проверенная в
-- LOAD_DDS_S_NEWS_EMBEDDINGS.yaml)
-- bds.b_unews является источником текста - он уже схлопывает почти дублирующиеся
-- новости с разных фидов (см. uniq_news в 011_create_view_bds.b_unews.sql).
-- джойн по (news_id, model_nm)
SELECT
    u.published_dttm
    , tsn.story_id
    , sd.story_nm
    , u.feed_nm
    , u.language_code
    , u.news_id
    , CASE
        WHEN right(trim(u.title_txt), 1) IN ('.', '?', '!')
            THEN u.title_txt || ' ' || u.summary_txt
        ELSE u.title_txt || '. ' || u.summary_txt
      END AS news_txt
FROM bds.b_unews u
JOIN dds.t_story_news tsn
    ON tsn.news_id = u.news_id
   AND tsn.model_nm = u.model_nm
JOIN dds.s_story_details sd
    ON sd.story_id = tsn.story_id
   AND sd.language_code = u.language_code
   AND sd.is_active = true
ORDER BY u.published_dttm DESC
;
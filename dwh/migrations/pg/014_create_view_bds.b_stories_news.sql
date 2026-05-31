-- DROP VIEW IF EXISTS bds.b_stories_news;
CREATE OR REPLACE VIEW bds.b_stories_news AS
WITH
    story AS (
        SELECT story_id, story_nm, embedding_vct
        FROM bds.d_stories
        WHERE is_active = true
        -- AND story_id = 1
        ),
    news AS (
        SELECT
            un.*
            , s.story_id
            , s.story_nm
            , s.embedding_vct <=> un.embedding_vct AS distance
            , row_number() OVER (PARTITION BY story_id, news_id, language_code ORDER BY s.embedding_vct <=> un.embedding_vct) AS rn
        FROM bds.b_news_unified un
        JOIN story s ON un.embedding_vct <=> s.embedding_vct < 0.52)
SELECT
    published_dttm
    , story_id
    , story_nm
    , feed_nm
    , language_code
    , news_id
    , CASE
        WHEN right(trim(title_txt), 1) IN ('.', '?', '!')
            THEN title_txt || ' ' || summary_txt
        ELSE title_txt || '. ' || summary_txt
      END AS news_txt
FROM news
WHERE rn = 1
ORDER BY published_dttm DESC
;

-- DROP VIEW IF EXISTS bds.b_story_unews_texts;
CREATE OR REPLACE VIEW bds.b_story_unews_texts AS
WITH
    storyline AS (
        SELECT story_id, embedding_vct
        FROM dds.s_story_storylines
        WHERE is_active = true
    ),
    news AS (
        SELECT
            un.*
            , sl.story_id
            , sl.embedding_vct <=> un.embedding_vct AS distance_prt
            , row_number() OVER (PARTITION BY sl.story_id, un.news_id, un.language_code
                                 ORDER BY sl.embedding_vct <=> un.embedding_vct) AS rn
        FROM bds.b_unews un
        JOIN storyline sl ON un.embedding_vct <=> sl.embedding_vct < 0.52
    )
SELECT
    n.published_dttm
    , n.story_id
    , sd.story_nm
    , n.feed_nm
    , n.language_code
    , n.news_id
    , CASE
        WHEN right(trim(n.title_txt), 1) IN ('.', '?', '!')
            THEN n.title_txt || ' ' || n.summary_txt
        ELSE n.title_txt || '. ' || n.summary_txt
      END AS news_txt
FROM news n
JOIN dds.s_story_details sd
    ON sd.story_id = n.story_id
   AND sd.language_code = n.language_code
   AND sd.is_active = true
WHERE n.rn = 1
ORDER BY n.published_dttm DESC
;

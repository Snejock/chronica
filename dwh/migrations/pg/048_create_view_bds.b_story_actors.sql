-- DROP VIEW IF EXISTS bds.b_story_actors;
CREATE OR REPLACE VIEW bds.b_story_actors AS
WITH
    mentions AS (
        SELECT
            tsn.story_id
            , tna.actor_id
            , count(DISTINCT tna.news_id) AS mentions_cnt
            , min(u.published_dttm)       AS first_dttm
            , max(u.published_dttm)       AS last_dttm
            , max(tna.confidence_prt)     AS confidence_prt
        FROM bds.b_unews u
        JOIN dds.t_story_news tsn ON tsn.news_id = u.news_id AND tsn.model_nm = u.model_nm
        JOIN dds.t_news_actors tna ON tna.news_id = u.news_id
        WHERE u.language_code = 'ru'
        GROUP BY tsn.story_id, tna.actor_id
    ),
    langs AS (
        -- витрина двуязычная, как и s_story_details
        SELECT unnest(ARRAY['ru', 'en']) AS language_code
    ),
    enriched AS (
        SELECT
            m.story_id
            , m.actor_id
            , l.language_code
            -- у части актёров нет ru-описания из Wikidata - fallback на en
            , coalesce(d.canonical_nm,    en.canonical_nm)    AS canonical_nm
            , coalesce(d.description_txt, en.description_txt) AS description_txt
            , coalesce(d.source_link,     en.source_link)     AS source_link
            , md.photo_link
            , md.author_nm
            , md.license_nm
            , m.mentions_cnt
            , m.first_dttm
            , m.last_dttm
            , m.confidence_prt
        FROM mentions m
        CROSS JOIN langs l
        LEFT JOIN dds.s_actor_details d ON d.actor_id = m.actor_id AND d.language_code = l.language_code
        LEFT JOIN dds.s_actor_details en ON en.actor_id = m.actor_id AND en.language_code = 'en'
        LEFT JOIN dds.s_actor_media md ON md.actor_id = m.actor_id
    )
SELECT
    story_id
    , actor_id
    , language_code
    , canonical_nm
    , description_txt
    , source_link
    , photo_link
    , author_nm
    , license_nm
    , mentions_cnt
    , first_dttm
    , last_dttm
    , confidence_prt
    , row_number() OVER (
          PARTITION BY story_id, language_code
          ORDER BY mentions_cnt DESC, last_dttm DESC
      ) AS rank_idx
FROM enriched
WHERE canonical_nm IS NOT NULL
;
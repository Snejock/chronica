WITH story AS (
    SELECT story_id, model_nm, embedding_vct
    FROM dds.s_story_storylines
    WHERE is_active = true
),
ranked AS (
    SELECT
        s.story_id,
        ne.news_id,
        s.model_nm,
        h.published_dttm,
        (s.embedding_vct <=> ne.embedding_vct)::numeric(4, 3) AS distance_prt,
        row_number() OVER (
            PARTITION BY s.story_id, ne.news_id
            ORDER BY s.embedding_vct <=> ne.embedding_vct
        ) AS rn
    FROM dds.s_news_embeddings ne
    JOIN dds.h_news h ON h.news_id = ne.news_id
    JOIN story s
        ON s.model_nm = ne.model_nm
       AND s.embedding_vct <=> ne.embedding_vct < 0.52
)
INSERT INTO dds.t_news_stories (story_id, news_id, model_nm, published_dttm, distance_prt)
SELECT story_id, news_id, model_nm, published_dttm, distance_prt
FROM ranked
WHERE rn = 1
ON CONFLICT (story_id, news_id, model_nm) DO NOTHING;

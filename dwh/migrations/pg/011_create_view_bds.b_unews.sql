DROP MATERIALIZED VIEW IF EXISTS bds.b_unews CASCADE;
CREATE MATERIALIZED VIEW bds.b_unews AS
WITH uniq_news AS (
    SELECT
        ne.news_id
        , ne.model_nm
        , ne.embedding_vct
    FROM dds.h_news h
    JOIN dds.s_news_embeddings ne ON h.news_id = ne.news_id
    WHERE NOT EXISTS (SELECT 1
                      FROM (SELECT ne2.embedding_vct
                            FROM dds.h_news h2
                            JOIN dds.s_news_embeddings ne2 ON h2.news_id = ne2.news_id
                            WHERE ne.model_nm = ne2.model_nm
                              AND ne.news_id <> ne2.news_id
                              AND h.published_dttm >= h2.published_dttm - INTERVAL '1 day'
                              AND h.published_dttm > h2.published_dttm
                            ORDER BY ne.embedding_vct <=> ne2.embedding_vct
                            LIMIT 1) closest_match
                      WHERE ne.embedding_vct <=> closest_match.embedding_vct < 0.20)
)
SELECT
    now()::timestamptz(0) AS _loaded_dttm
    , u.news_id
    , h.published_dttm
    , d.feed_nm
    , s.language_code
    , s.title_txt
    , s.summary_txt
    , u.model_nm
    , u.embedding_vct
FROM uniq_news u
JOIN dds.h_news h ON u.news_id = h.news_id
JOIN dds.d_rss_feeds d ON h.feed_id = d.feed_id
JOIN dds.s_news_texts s ON u.news_id = s.news_id AND s.language_code IN ('en', 'ru')
;

CREATE INDEX b_unews_embedding_idx ON bds.b_unews USING hnsw (embedding_vct vector_cosine_ops);

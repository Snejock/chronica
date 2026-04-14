CREATE OR REPLACE VIEW dm.uniq_news AS
WITH uniq_news AS (
    SELECT news_id
    FROM dtl.s_chr_rss_news_embeddings ne
    WHERE NOT EXISTS (SELECT 1
                      FROM (SELECT ne2.embedding_vct
                            FROM dtl.s_chr_rss_news_embeddings ne2
                            WHERE ne.model_nm = ne2.model_nm
                              AND ne.news_id <> ne2.news_id
                              AND ne2._loaded_dttm > ne._loaded_dttm - interval '1 day'
                              AND (
                                ne2._loaded_dttm < ne._loaded_dttm
                                    OR (ne2._loaded_dttm = ne._loaded_dttm AND ne2.news_id < ne.news_id)
                                )
                            ORDER BY ne.embedding_vct <=> ne2.embedding_vct
                            LIMIT 1) closest_match
                      WHERE (ne.embedding_vct <=> closest_match.embedding_vct) < 0.20)
)
SELECT
    u.news_id
    , h.published_utc
    , s.language_code
    , s.title_txt
    , s.summary_txt
    , e.model_nm
    , e.embedding_vct
FROM uniq_news u
JOIN dtl.h_chr_rss_news h ON u.news_id = h.news_id
JOIN dtl.s_chr_rss_news_texts s ON u.news_id = s.news_id
JOIN dtl.s_chr_rss_news_embeddings e ON u.news_id = e.news_id
WHERE language_code = 'ru'
ORDER BY published_utc DESC
;

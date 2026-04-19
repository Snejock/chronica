CREATE TABLE IF NOT EXISTS dtl.s_rss_news_embeddings (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    embedding_vct   vector(768),

    CONSTRAINT s_rss_news_embeddings_pkey
        PRIMARY KEY (news_id, model_nm)
);

CREATE INDEX s_rss_news_embeddings_idx ON dtl.s_rss_news_embeddings USING hnsw (embedding_vct vector_cosine_ops);
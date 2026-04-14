CREATE TABLE IF NOT EXISTS dtl.s_chr_rss_news_embeddings (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    embedding_vct   vector(768),

    CONSTRAINT s_chr_rss_news_embeddings_pkey
        PRIMARY KEY (news_id, model_nm)
);

CREATE INDEX idx_news_embeddings_hnsw ON dtl.s_chr_rss_news_embeddings USING hnsw (embedding_vct vector_cosine_ops)
;
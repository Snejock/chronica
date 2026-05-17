CREATE TABLE IF NOT EXISTS dds.s_news_embeddings (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    embedding_vct   vector(768),

    CONSTRAINT s_news_embeddings_pkey
        PRIMARY KEY (news_id, model_nm)
);

CREATE INDEX s_news_embeddings_embedding_idx ON dds.s_news_embeddings USING hnsw (embedding_vct vector_cosine_ops);
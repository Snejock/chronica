DROP TABLE IF EXISTS bds.b_unews;
CREATE TABLE bds.b_unews (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    published_dttm  timestamp(0) with time zone,
    feed_nm         text,
    language_code   text NOT NULL,
    title_txt       text,
    summary_txt     text,
    model_nm        text NOT NULL,
    embedding_vct   vector(768),

    CONSTRAINT b_unews__news_id_language_code_model_nm_pk
        PRIMARY KEY (news_id, language_code, model_nm)
);

CREATE INDEX b_unews__embedding_vct_idx ON bds.b_unews USING hnsw (embedding_vct vector_cosine_ops);
CREATE INDEX b_unews__published_dttm_idx ON bds.b_unews (published_dttm DESC);
CREATE UNIQUE INDEX b_unews__news_id_language_code_model_nm_uidx ON bds.b_unews (news_id, language_code, model_nm);
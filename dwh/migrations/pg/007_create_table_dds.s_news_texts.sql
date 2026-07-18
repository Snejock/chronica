CREATE TABLE IF NOT EXISTS dds.s_news_texts (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    language_code   text NOT NULL,
    title_txt       text,
    summary_txt     text,
    model_nm        text NOT NULL,

    CONSTRAINT s_news_texts__news_id_language_code_model_nm_pk
        PRIMARY KEY (news_id, language_code, model_nm)
);
CREATE TABLE IF NOT EXISTS dtl.s_rss_news_texts (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    news_id         text NOT NULL,
    language_code   text NOT NULL,
    title_txt       text,
    summary_txt     text,

    CONSTRAINT s_rss_news_texts_pkey
        PRIMARY KEY (news_id, language_code)
);
CREATE TABLE IF NOT EXISTS dds.s_news_media (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    image_url       text,

    CONSTRAINT s_news_media__news_id_pk PRIMARY KEY (news_id)
);
CREATE TABLE IF NOT EXISTS dds.t_story_news_sent (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    chat_id         bigint  NOT NULL,
    story_id        integer NOT NULL,
    news_id         text    NOT NULL,

    CONSTRAINT t_story_news_sent_pkey
        PRIMARY KEY (chat_id, story_id, news_id)
);

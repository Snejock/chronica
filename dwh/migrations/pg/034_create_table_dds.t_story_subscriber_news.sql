CREATE TABLE IF NOT EXISTS dds.t_story_subscriber_news (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    subscriber_id   integer NOT NULL REFERENCES dds.h_subscribers(subscriber_id),
    news_id         text    NOT NULL,

    CONSTRAINT t_story_subscriber_news_pkey
        PRIMARY KEY (story_id, subscriber_id, news_id)
);

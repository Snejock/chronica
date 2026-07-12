CREATE TABLE IF NOT EXISTS dds.t_story_subs_news (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    subscriber_id   integer NOT NULL REFERENCES dds.h_subscribers(subscriber_id),
    story_id        integer NOT NULL,
    news_id         text    NOT NULL,

    CONSTRAINT t_story_subs_news_pkey
        PRIMARY KEY (subscriber_id, story_id, news_id)
);

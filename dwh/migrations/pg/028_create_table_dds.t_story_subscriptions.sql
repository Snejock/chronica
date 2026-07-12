CREATE TABLE IF NOT EXISTS dds.t_story_subscriptions (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    chat_id         bigint  NOT NULL,
    story_id        integer NOT NULL,
    language_code   text    NOT NULL DEFAULT 'ru',
    is_active       boolean NOT NULL DEFAULT true,

    CONSTRAINT t_story_subscriptions_pkey
        PRIMARY KEY (chat_id, story_id)
);

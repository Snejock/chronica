CREATE TABLE IF NOT EXISTS dds.l_story_tg_subs (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    chat_id         bigint  NOT NULL,
    language_code   text    NOT NULL DEFAULT 'ru',
    is_active       boolean NOT NULL DEFAULT true,

    CONSTRAINT l_story_tg_subs_pkey
        PRIMARY KEY (story_id, chat_id)
);

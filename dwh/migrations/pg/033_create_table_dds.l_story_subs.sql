CREATE TABLE IF NOT EXISTS dds.l_story_subs (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    subscriber_id   integer NOT NULL REFERENCES dds.h_subscribers(subscriber_id),
    is_active       boolean NOT NULL DEFAULT true,

    CONSTRAINT l_story_subs_pkey
        PRIMARY KEY (story_id, subscriber_id)
);

CREATE TABLE IF NOT EXISTS dds.l_story_subscriber (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL CONSTRAINT l_story_subscriber__story_id_fk REFERENCES dds.h_stories(story_id),
    subscriber_id   integer NOT NULL CONSTRAINT l_story_subscriber__subscriber_id_fk REFERENCES dds.h_subscribers(subscriber_id),
    is_active       boolean NOT NULL DEFAULT true,

    CONSTRAINT l_story_subscriber__story_id_subscriber_id_pk
        PRIMARY KEY (story_id, subscriber_id)
);

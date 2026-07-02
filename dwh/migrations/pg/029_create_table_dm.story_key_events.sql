-- DROP TABLE IF EXISTS dm.story_key_events;

CREATE TABLE IF NOT EXISTS dm.story_key_events (
    _loaded_dttm     timestamp(0) with time zone DEFAULT now(),
    story_id         integer NOT NULL,
    model_nm         text    NOT NULL,
    language_code    text    NOT NULL,
    is_active        boolean DEFAULT true,
    events_json      jsonb,
    coverage_from_dt date,
    coverage_to_dt   date,

    CONSTRAINT story_key_events_pkey
        PRIMARY KEY (story_id, model_nm, language_code, is_active),

    CONSTRAINT story_key_events_story_id_fkey
        FOREIGN KEY (story_id) REFERENCES dds.h_stories(story_id)
);

CREATE INDEX IF NOT EXISTS story_key_events_is_active_idx
    ON dm.story_key_events(story_id, language_code, is_active);

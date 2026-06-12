DROP TABLE IF EXISTS dds.s_story_details;

CREATE TABLE IF NOT EXISTS dds.s_story_details (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL REFERENCES dds.h_stories(story_id),
    language_code   text NOT NULL,
    story_nm        text,
    geo_lat         numeric(9, 6),
    geo_lon         numeric(9, 6),
    is_active       boolean DEFAULT true,

    CONSTRAINT s_story_details_pkey
        PRIMARY KEY (story_id, language_code)
);
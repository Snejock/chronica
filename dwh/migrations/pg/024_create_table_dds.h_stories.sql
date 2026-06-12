DROP TABLE IF EXISTS dds.h_stories;

CREATE TABLE IF NOT EXISTS dds.h_stories (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer PRIMARY KEY,
    story_link      text
);
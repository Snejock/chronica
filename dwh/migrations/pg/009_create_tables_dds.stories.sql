DROP TABLE IF EXISTS dds.h_stories;

CREATE TABLE IF NOT EXISTS dds.h_stories (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer PRIMARY KEY,
    story_link      text
);

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

DROP TABLE IF EXISTS dds.s_story_storylines;

CREATE TABLE IF NOT EXISTS dds.s_story_storylines (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL REFERENCES dds.h_stories(story_id),
    storyline_id    integer NOT NULL,
    storyline_txt   text,
    model_nm        text NOT NULL,
    embedding_vct   vector(768),
    is_active       boolean DEFAULT true,
    CONSTRAINT s_story_storylines_pkey
        PRIMARY KEY (story_id, storyline_id, model_nm)
);
CREATE INDEX IF NOT EXISTS s_story_storylines_embedding_idx ON dds.s_story_storylines USING hnsw (embedding_vct vector_cosine_ops);

DROP TABLE IF EXISTS dds.h_stories;

CREATE TABLE IF NOT EXISTS dds.h_stories (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer CONSTRAINT h_stories__story_id_pk PRIMARY KEY
);

DROP TABLE IF EXISTS dds.s_story_details;

CREATE TABLE IF NOT EXISTS dds.s_story_details (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL CONSTRAINT s_story_details__story_id_fk REFERENCES dds.h_stories(story_id),
    language_code   text NOT NULL,
    story_nm        text,
    geo_lat         numeric(9, 6),
    geo_lon         numeric(9, 6),
    is_active       boolean DEFAULT true,
    CONSTRAINT s_story_details__story_id_language_code_pk
        PRIMARY KEY (story_id, language_code)
);

DROP TABLE IF EXISTS dds.s_story_storylines;

CREATE TABLE IF NOT EXISTS dds.s_story_storylines (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL CONSTRAINT s_story_storylines__story_id_fk REFERENCES dds.h_stories(story_id),
    storyline_id    text GENERATED ALWAYS AS (xxh64(storyline_txt)) STORED,
    model_nm        text NOT NULL,
    is_active       boolean DEFAULT true,
    storyline_txt   text,
    embedding_vct   vector(768),
    anchor_txt      text,
    CONSTRAINT s_story_storylines__story_id_storyline_id_model_nm_pk
        PRIMARY KEY (story_id, storyline_id, model_nm)
);
CREATE INDEX IF NOT EXISTS s_story_storylines__embedding_vct_idx ON dds.s_story_storylines USING hnsw (embedding_vct vector_cosine_ops);

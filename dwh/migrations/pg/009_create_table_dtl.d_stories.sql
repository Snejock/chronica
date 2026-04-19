CREATE TABLE IF NOT EXISTS dtl.d_stories (
    _loaded_dttm    timestamp(0) DEFAULT now(),
    story_id        integer,
    story_nm        text,
    storyline_txt   text,
    model_nm        text,
    embedding_vct   vector(768),
    is_active       boolean,

    CONSTRAINT d_stories_pkey
        PRIMARY KEY (story_id, storyline_txt, model_nm)
);
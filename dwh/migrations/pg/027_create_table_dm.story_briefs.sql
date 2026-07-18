CREATE TABLE IF NOT EXISTS dm.story_briefs (
    _loaded_dttm     timestamp(0) with time zone DEFAULT now(),
    story_id         integer   NOT NULL,
    model_nm         text      NOT NULL,
    language_code    text      NOT NULL,
    lead_txt         text,
    brief_txt        text,
    coverage_from_dt date,
    coverage_to_dt   date,
    is_active        boolean   DEFAULT true,

    CONSTRAINT story_briefs__story_id_model_nm_language_code_is_active_pk
        PRIMARY KEY (story_id, model_nm, language_code, is_active),

    CONSTRAINT story_briefs__story_id_fk
        FOREIGN KEY (story_id) REFERENCES dds.h_stories(story_id)
);

CREATE INDEX story_briefs__story_id_language_code_is_active_idx ON dm.story_briefs(story_id, language_code, is_active);
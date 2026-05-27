-- DROP TABLE IF EXISTS dm.stories_summaries_d;

CREATE TABLE IF NOT EXISTS dm.stories_summaries_d (
    _loaded_dttm  timestamp(0) with time zone default now(),
    story_id      integer      NOT NULL,
    dt            date         NOT NULL,
    model_nm      text         NOT NULL,
    language_code text         NOT NULL,
    headline_txt  text,
    summary_txt   text,

    CONSTRAINT stories_summaries_d_pkey
        PRIMARY KEY (story_id, dt, model_nm, language_code)
);
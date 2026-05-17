DROP TABLE IF EXISTS dds.s_story_daily_summaries;

CREATE TABLE IF NOT EXISTS dds.s_story_daily_summaries (
    _loaded_dttm  timestamp(0) with time zone default now(),
    story_id      integer      NOT NULL,
    dt            date         NOT NULL,
    model_nm      text         NOT NULL,
    language_code text         NOT NULL,
    headline_txt  text,
    summary_txt   text,

    PRIMARY KEY (story_id, dt, model_nm, language_code)
);
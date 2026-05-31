DROP TABLE IF EXISTS dds.t_news_stories;
CREATE TABLE IF NOT EXISTS dds.t_news_stories (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    published_dttm  timestamp(0) with time zone,
    distance_prt    numeric(4, 3),

    CONSTRAINT t_news_stories_pkey
        PRIMARY KEY (story_id, news_id, model_nm)
);

CREATE INDEX IF NOT EXISTS t_news_stories_story_id_idx ON dds.t_news_stories(story_id);
CREATE INDEX IF NOT EXISTS t_news_stories_story_id_published_dttm_idx ON dds.t_news_stories(story_id, published_dttm);
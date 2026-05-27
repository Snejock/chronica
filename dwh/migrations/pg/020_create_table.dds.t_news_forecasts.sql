DROP TABLE IF EXISTS dds.t_news_forecasts;
CREATE TABLE dds.t_news_forecasts (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    news_id         text NOT NULL,
    published_dttm  timestamp(0) with time zone NOT NULL,
    forecast_id     integer NOT NULL,
    model_nm        text NOT NULL,
    p_confirm_prt   numeric(4, 3) NOT NULL CHECK (p_confirm_prt   BETWEEN 0.001 AND 0.999),
    p_refute_prt    numeric(4, 3) NOT NULL CHECK (p_refute_prt    BETWEEN 0.001 AND 0.999),
    reason_txt      text,

    CONSTRAINT t_news_forecasts_pkey
        PRIMARY KEY (news_id, forecast_id, model_nm),

    CONSTRAINT t_news_forecasts_news_id_fkey
        FOREIGN KEY (news_id) REFERENCES dds.h_news(news_id)
);

CREATE INDEX t_news_forecasts_story_id_idx ON dds.t_news_forecasts(story_id);
CREATE INDEX t_news_forecasts_published_dttm_idx ON dds.t_news_forecasts(published_dttm);

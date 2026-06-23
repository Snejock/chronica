DROP TABLE IF EXISTS dds.t_forecast_news;
CREATE TABLE dds.t_forecast_news (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    news_id         text NOT NULL,
    published_dttm  timestamp(0) with time zone NOT NULL,
    forecast_id     integer NOT NULL,
    model_nm        text NOT NULL,
    p_confirm_prt   numeric(4, 3) NOT NULL CHECK (p_confirm_prt   BETWEEN 0.001 AND 0.999),
    p_refute_prt    numeric(4, 3) NOT NULL CHECK (p_refute_prt    BETWEEN 0.001 AND 0.999),
    reason_txt      text,

    CONSTRAINT t_forecast_news_pkey
        PRIMARY KEY (news_id, forecast_id, model_nm),

    CONSTRAINT t_forecast_news_news_id_fkey
        FOREIGN KEY (news_id) REFERENCES dds.h_news(news_id)
);

CREATE INDEX t_forecast_news_story_id_idx ON dds.t_forecast_news(story_id);
CREATE INDEX t_forecast_news_published_dttm_idx ON dds.t_forecast_news(published_dttm);

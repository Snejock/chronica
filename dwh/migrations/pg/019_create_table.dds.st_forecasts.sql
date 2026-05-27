DROP TABLE IF EXISTS dds.st_forecasts;
CREATE TABLE dds.st_forecasts (
    _loaded_dttm            timestamp(0) with time zone DEFAULT now(),
    story_id                integer NOT NULL,
    forecast_id             integer NOT NULL,
    p_posterior_prt         numeric(4,3) NOT NULL CHECK (p_posterior_prt BETWEEN 0.001 AND 0.999),
    news_cnt                integer NOT NULL DEFAULT 0,
    last_news_id            text,
    last_published_dttm     timestamp(0) with time zone,

    CONSTRAINT st_forecasts_pkey
        PRIMARY KEY (forecast_id),

    CONSTRAINT st_forecasts_news_id_fkey
        FOREIGN KEY (last_news_id) REFERENCES dds.h_news(news_id)
);

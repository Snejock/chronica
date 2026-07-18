DROP TABLE IF EXISTS dds.d_forecasts CASCADE;
CREATE TABLE IF NOT EXISTS dds.d_forecasts (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    story_id        integer NOT NULL,
    forecast_id     integer NOT NULL,
    language_code   text NOT NULL,
    forecast_nm     text NOT NULL,
    forecast_txt    text NOT NULL,
    horizon_days    integer NOT NULL,
    p_prior_prt     numeric(4, 3) NOT NULL CHECK (p_prior_prt BETWEEN 0.001 AND 0.999),
    is_active       boolean DEFAULT true,

    CONSTRAINT d_forecasts__forecast_id_language_code_pk
        PRIMARY KEY (forecast_id, language_code)
);

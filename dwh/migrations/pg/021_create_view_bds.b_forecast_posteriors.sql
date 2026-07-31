DROP VIEW IF EXISTS bds.b_forecast_posteriors;
CREATE TABLE bds.b_forecast_posteriors (
    _loaded_dttm      timestamp(0) with time zone DEFAULT now(),
    forecast_id       integer NOT NULL,
    language_code     text NOT NULL,
    forecast_nm       text,
    news_id           text NOT NULL,
    published_dttm    timestamp(0) with time zone,
    p_confirm_prt     numeric(4, 3),
    p_refute_prt      numeric(4, 3),
    p_posterior_prt   numeric(4, 3),
    alpha             numeric(6, 2),
    beta              numeric(6, 2),
    effective_n       numeric(5, 1),
    p_lower_95_prt    numeric(4, 3),
    p_upper_95_prt    numeric(4, 3),

    CONSTRAINT b_forecast_posteriors__forecast_id_language_code_news_id_pk
        PRIMARY KEY (forecast_id, language_code, news_id)
);

CREATE INDEX b_forecast_posteriors__news_id_idx ON bds.b_forecast_posteriors (news_id);
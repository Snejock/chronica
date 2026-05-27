-- DROP TABLE IF EXISTS dds.s_news_ticker_reactions;

CREATE TABLE IF NOT EXISTS dds.s_news_ticker_reactions (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    ticker_code     text NOT NULL,
    category_nm     text,
    impact_scr      smallint,
    confidence_prt  numeric(3, 2),
    reason_txt      text,

    CONSTRAINT s_news_ticker_reactions_pkey
        PRIMARY KEY (news_id, ticker_code, model_nm)
);
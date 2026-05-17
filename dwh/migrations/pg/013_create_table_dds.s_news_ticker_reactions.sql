DROP TABLE IF EXISTS dds.s_news_ticker_reactions;

CREATE TABLE IF NOT EXISTS dds.s_news_ticker_reactions (
    _loaded_dttm    timestamp(0) with time zone default now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    ticker_code     text NOT NULL,
    category_nm     text,
    impact_scr      smallint,
    confidence_prt  numeric(3, 2),
    language_code   text NOT NULL,
    reason_txt      text,

    PRIMARY KEY (news_id, ticker_code, model_nm, language_code)
);
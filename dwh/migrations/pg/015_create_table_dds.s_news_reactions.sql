DROP TABLE IF EXISTS dds.s_news_reactions;

CREATE TABLE IF NOT EXISTS dds.s_news_reactions (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    reach_idx       text,
    impact_scr      integer,
    duration_days   integer,
    scale_nm        text,
    confidence_prt  numeric(3, 2),
    language_code   text NOT NULL,
    reason_txt      text,

    CONSTRAINT s_news_reactions_pkey
        PRIMARY KEY (news_id, model_nm, language_code)
);
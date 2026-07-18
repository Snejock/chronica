-- DROP TABLE IF EXISTS dds.s_news_reactions;

CREATE TYPE dds.reach_idx_enum AS ENUM (
    '1k', '10k', '100k', '1m', '10m', '100m', '1b', '10b'
);

CREATE TYPE dds.geoscale_nm_enum AS ENUM (
    'local', 'national', 'regional', 'global'
);

CREATE TABLE IF NOT EXISTS dds.s_news_reactions (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    model_nm        text NOT NULL,
    reach_idx       dds.reach_idx_enum,
    impact_scr      integer,
    duration_days   integer,
    geoscale_nm     dds.geoscale_nm_enum,
    confidence_prt  numeric(3, 2),
    reason_txt      text,

    CONSTRAINT s_news_reactions__news_id_model_nm_pk
        PRIMARY KEY (news_id, model_nm)
);
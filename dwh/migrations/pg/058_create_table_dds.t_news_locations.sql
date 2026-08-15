CREATE TABLE IF NOT EXISTS dds.t_news_locations (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    location_id     text NOT NULL,
    model_nm        text NOT NULL,
    published_dttm  timestamp(0) with time zone NOT NULL,
    location_nm     text,
    confidence_prt  numeric(3, 2),

    CONSTRAINT t_news_locations__news_id_location_id_model_nm_pk
        PRIMARY KEY (news_id, location_id, model_nm),

    CONSTRAINT t_news_locations__news_id_fk
        FOREIGN KEY (news_id) REFERENCES dds.h_news(news_id),

    CONSTRAINT t_news_locations__location_id_fk
        FOREIGN KEY (location_id) REFERENCES dds.h_locations(location_id)
);

CREATE INDEX t_news_locations__location_id_idx ON dds.t_news_locations (location_id);
CREATE INDEX t_news_locations__location_id_published_dttm_idx ON dds.t_news_locations (location_id, published_dttm);
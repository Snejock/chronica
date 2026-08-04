CREATE TABLE IF NOT EXISTS dds.t_news_actors (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    actor_id        text NOT NULL,
    model_nm        text NOT NULL,
    published_dttm  timestamp(0) with time zone NOT NULL,
    actor_nm        text,
    confidence_prt  numeric(3, 2),

    CONSTRAINT t_news_actors__news_id_actor_id_model_nm_pk
        PRIMARY KEY (news_id, actor_id, model_nm),

    CONSTRAINT t_news_actors__news_id_fk
        FOREIGN KEY (news_id) REFERENCES dds.h_news(news_id),

    CONSTRAINT t_news_actors__actor_id_fk
        FOREIGN KEY (actor_id) REFERENCES dds.h_actors(actor_id)
);

CREATE INDEX t_news_actors__actor_id_idx ON dds.t_news_actors (actor_id);
CREATE INDEX t_news_actors__actor_id_published_dttm_idx ON dds.t_news_actors (actor_id, published_dttm);

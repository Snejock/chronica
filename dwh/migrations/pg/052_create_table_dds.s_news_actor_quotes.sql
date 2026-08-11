-- DROP TABLE IF EXISTS dds.s_news_actor_quotes;

-- цитата актора из конкретной новости, на обоих базовых языках витрины (ru/en) --
-- по форме как dds.s_news_texts (news_id, language_code, model_nm), с добавлением
-- actor_id: сателлит на связь dds.t_news_actors (news_id, actor_id), а не
-- самостоятельный линк -- сама связь "новость-актор" остаётся одной строкой
-- в t_news_actors, языковые варианты цитаты просто историзуются здесь.
CREATE TABLE IF NOT EXISTS dds.s_news_actor_quotes (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    news_id         text NOT NULL,
    actor_id        text NOT NULL,
    language_code   text NOT NULL,
    model_nm        text NOT NULL,
    quote_txt       text NOT NULL,

    CONSTRAINT s_news_actor_quotes__news_id_actor_id_language_code_model_nm_pk
        PRIMARY KEY (news_id, actor_id, language_code, model_nm),

    CONSTRAINT s_news_actor_quotes__news_id_fk
        FOREIGN KEY (news_id) REFERENCES dds.h_news(news_id),

    CONSTRAINT s_news_actor_quotes__actor_id_fk
        FOREIGN KEY (actor_id) REFERENCES dds.h_actors(actor_id)
);

CREATE INDEX s_news_actor_quotes__actor_id_idx ON dds.s_news_actor_quotes (actor_id);

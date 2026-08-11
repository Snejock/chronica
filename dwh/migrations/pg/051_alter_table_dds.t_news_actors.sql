-- quote_txt переезжает в dds.t_actor_quotes (052) -- цитата нужна на двух базовых
-- языках (ru/en), а t_news_actors, в отличие от неё, языка не знает: actor_nm,
-- confidence_prt и published_dttm от языка не зависят. На проде это поле уже
-- накоплено для 4 строк (только на английском) -- переносить их некуда, дропаем.
ALTER TABLE dds.t_news_actors
    DROP COLUMN IF EXISTS quote_txt;

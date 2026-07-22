-- storyline_id становится генерируемой (STORED) колонкой: значение всегда
-- детерминированный хэш от storyline_txt (xxh64), как news_id в остальном dds.
ALTER TABLE dds.s_story_storylines
    DROP CONSTRAINT s_story_storylines__story_id_storyline_id_model_nm_pk;

ALTER TABLE dds.s_story_storylines
    DROP COLUMN storyline_id;

ALTER TABLE dds.s_story_storylines
    ADD COLUMN storyline_id text GENERATED ALWAYS AS (xxh64(storyline_txt)) STORED;

ALTER TABLE dds.s_story_storylines
    ADD CONSTRAINT s_story_storylines__story_id_storyline_id_model_nm_pk
        PRIMARY KEY (story_id, storyline_id, model_nm);

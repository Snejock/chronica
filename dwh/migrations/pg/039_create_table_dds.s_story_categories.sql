CREATE TABLE IF NOT EXISTS dds.s_story_categories (
    _loaded_dttm    timestamp(0) with time zone DEFAULT now(),
    category_nm     text NOT NULL,
    language_code   text NOT NULL,
    label_nm        text NOT NULL,
    sort_order_idx  smallint NOT NULL,
    CONSTRAINT s_story_categories__category_nm_language_code_pk
        PRIMARY KEY (category_nm, language_code)
);

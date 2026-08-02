CREATE OR REPLACE VIEW bds.b_story_categories AS
SELECT
    category_nm
    , language_code
    , label_nm
    , sort_order_idx
FROM dds.s_story_categories;

INSERT INTO dds.s_story_categories (category_nm, language_code, label_nm, sort_order_idx) VALUES
    ('geopolitics', 'ru', 'Геополитика', 10),
    ('geopolitics', 'en', 'Geopolitics', 10),
    ('companies',   'ru', 'Компании',    20),
    ('companies',   'en', 'Companies',   20)
ON CONFLICT (category_nm, language_code) DO NOTHING;

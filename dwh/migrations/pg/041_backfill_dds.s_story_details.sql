UPDATE dds.s_story_details
SET category_nm = 'geopolitics'
WHERE story_id IN (1, 2);

UPDATE dds.s_story_details
SET category_nm = 'companies'
WHERE story_id IN (3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17);

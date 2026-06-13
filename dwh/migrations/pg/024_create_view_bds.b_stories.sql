-- DROP VIEW IF EXISTS bds.b_stories;

CREATE OR REPLACE VIEW bds.b_stories AS
SELECT
    story_id
    , language_code
    , story_nm
    , geo_lat
    , geo_lon
FROM dds.s_story_details
WHERE is_active = true
;
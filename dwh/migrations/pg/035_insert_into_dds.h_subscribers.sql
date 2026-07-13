WITH new_subscriber AS (
    INSERT INTO dds.h_subscribers DEFAULT VALUES
    RETURNING subscriber_id
), sc AS (
    INSERT INTO dds.s_subscriber_channels (subscriber_id, channel_nm, channel_link)
    SELECT subscriber_id, 'telegram', '359268279'
    FROM new_subscriber
), sd AS (
    INSERT INTO dds.s_subscriber_details (subscriber_id, language_code)
    SELECT subscriber_id, 'ru'
    FROM new_subscriber
)
INSERT INTO dds.l_story_subscriber (story_id, subscriber_id, is_active)
SELECT 1, subscriber_id, true
FROM new_subscriber;

SELECT
    ke.story_id
    , ke.language_code
    , ke.coverage_from_dt
    , ke.coverage_to_dt
    , (event->>'dt')::date  AS dt
    , event->>'event_nm'    AS event_nm
FROM dm.story_key_events ke,
     jsonb_array_elements(ke.events_json) AS event
WHERE ke.is_active = true
  AND ke.events_json IS NOT NULL

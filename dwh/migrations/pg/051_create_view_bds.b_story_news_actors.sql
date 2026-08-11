-- DROP VIEW IF EXISTS bds.b_story_news_actors;

-- связь story<->news взята из dds.t_story_news (тот же джойн по (news_id, model_nm),
-- что и в bds.b_story_unews_texts); bds.b_unews уже схлопывает почти дублирующиеся
-- новости с разных фидов -- без этого один и тот же материал, подхваченный
-- несколькими фидами, размножился бы в ленте актёра на несколько карточек.
-- language_code фиксирован на 'ru' -- эта секция сейчас только для ru.
--
-- добавлено quote_txt (dds.t_news_actors) -- цитата этого актора из данной новости,
-- извлекается тем же LLM-вызовом, что резолвит самого актора; null, если в статье
-- прямой речи этого человека нет.
CREATE OR REPLACE VIEW bds.b_story_news_actors AS
SELECT
    tsn.story_id
    , tna.actor_id
    , u.news_id
    , u.model_nm
    , u.published_dttm
    , h.news_link
    , f.feed_nm
    , f.feed_type
    , f.country_code
    , f.city_nm
    , u.language_code
    , m.image_url
    , tna.quote_txt
FROM bds.b_unews u
JOIN dds.t_story_news tsn
    ON tsn.news_id = u.news_id
   AND tsn.model_nm = u.model_nm
JOIN dds.t_news_actors tna
    ON tna.news_id = u.news_id
JOIN dds.h_news h ON h.news_id = u.news_id
JOIN dds.d_rss_feeds f ON h.feed_id = f.feed_id
LEFT JOIN dds.s_news_media m ON m.news_id = u.news_id
WHERE u.language_code = 'ru'
;

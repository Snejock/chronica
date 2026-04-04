INSERT INTO dtl.d_chr_rss_feeds (
   feed_id, feed_nm, feed_link, feed_type, country_code, city_nm, language_code, interval_sec, is_active
) VALUES
    (1, 'Interfax', 'https://www.interfax.ru/rss', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    (2, 'RBC', 'https://rssexport.rbc.ru/rbcnews/news/30/full.rss', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    (3, 'Kommersant', 'https://www.kommersant.ru/rss/news.xml', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    (4, 'BBC News', 'https://feeds.bbci.co.uk/news/world/rss.xml', 'independent', 'gb', 'London', 'en', 60, true),
    (5, 'The New York Times', 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml', 'independent', 'us', 'New York', 'en', 60, true),
    (6, 'Al Jazeera', 'https://www.aljazeera.com/xml/rss/all.xml', 'independent', 'qa', 'Doha', 'en', 60, true)
;
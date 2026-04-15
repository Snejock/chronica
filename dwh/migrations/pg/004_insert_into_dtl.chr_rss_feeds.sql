INSERT INTO dtl.d_chr_rss_feeds (
   feed_nm, feed_link, feed_type, country_code, city_nm, language_code, interval_sec, is_active
) VALUES
    ('Interfax', 'https://www.interfax.ru/rss', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    ('RBC', 'https://rssexport.rbc.ru/rbcnews/news/30/full.rss', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    ('Kommersant', 'https://www.kommersant.ru/rss/news.xml', 'independent', 'ru', 'Moscow', 'ru', 60, true),
    ('BBC News', 'https://feeds.bbci.co.uk/news/world/rss.xml', 'independent', 'gb', 'London', 'en', 60, true),
    ('The New York Times', 'https://rss.nytimes.com/services/xml/rss/nyt/World.xml', 'independent', 'us', 'New York', 'en', 60, true),
    ('Al Jazeera', 'https://www.aljazeera.com/xml/rss/all.xml', 'independent', 'qa', 'Doha', 'en', 60, true),
    ('Iran Front Page', 'https://ifpnews.com/feed/', 'independent', 'ir', 'Tehran', 'en', 60, true),
    ('Doha News', 'https://dohanews.co/feed/', 'independent', 'qa', 'Doha', 'en', 60, true),
    ('Haaretz', 'https://www.haaretz.com/srv/haaretz-latest-headlines', 'independent', 'il', 'Jerusalem', 'en', 60, true),
    ('Globes', 'https://www.globes.co.il/WebService/Rss/RssFeeder.asmx/FeederNode?iID=942', 'independent', 'il', 'Jerusalem', 'en', 60, true),
    ('The Jerusalem Post', 'https://www.jpost.com/rss/rssfeedsfrontpage.aspx', 'independent', 'il', 'Jerusalem', 'en', 60, true),
    ('Emirates 24|7', 'https://www.emirates247.com/rss/mobile/v2/flash-news.rss', 'independent', 'ae', 'Dubai', 'en', 60, true)
;
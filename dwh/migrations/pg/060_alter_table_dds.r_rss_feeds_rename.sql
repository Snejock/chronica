-- Переименование dds.d_rss_feeds → dds.r_rss_feeds: r_ (reference) — стандартная
-- номенклатура DV 2.0 для reference-таблиц
ALTER TABLE dds.d_rss_feeds RENAME TO r_rss_feeds;

ALTER TABLE dds.r_rss_feeds
    RENAME CONSTRAINT d_rss_feeds__feed_id_pk TO r_rss_feeds__feed_id_pk;
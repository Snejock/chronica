stg_chr_rss_news = """
{
    "type": "record",
    "name": "RSSNews",
    "namespace": "chronica",
    "fields": [
        {"name": "source_system", "type": "string"},
        {"name": "published_loc", "type": "string"},
        {"name": "published_utc", "type": "long"},
        {"name": "feed_id", "type": "int"},
        {"name": "feed_nm", "type": "string"},
        {"name": "title", "type": "string"},
        {"name": "summary", "type": "string", "default": ""},
        {"name": "link", "type": "string", "default": ""}
    ]
}
"""
import feedparser


class RSSFeedParser:
    def parse(self, xml_text: str) -> list[dict]:
        feed = feedparser.parse(xml_text)

        item_list = []
        for entry in feed.entries:
            item_list.append(
                {
                    "news_id": getattr(entry, "id", getattr(entry, "link", "")),
                    "published": getattr(entry, "published", None),
                    "title": getattr(entry, "title", ""),
                    "summary": getattr(entry, "summary", ""),
                    "link": getattr(entry, "link", ""),
                }
            )
        return item_list

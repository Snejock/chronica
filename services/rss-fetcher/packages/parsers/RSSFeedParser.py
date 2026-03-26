import feedparser
import ftfy


class RSSFeedParser:
    def parse(self, xml_text: str) -> list[dict]:
        feed = feedparser.parse(xml_text)

        item_list = []
        for entry in feed.entries:
            item_list.append(
                {
                    "published_loc": getattr(entry, "published", None),
                    "title": ftfy.fix_text(getattr(entry, "title", "")),
                    "summary": ftfy.fix_text(getattr(entry, "summary", "")),
                    "link": getattr(entry, "link", ""),
                }
            )
        return item_list

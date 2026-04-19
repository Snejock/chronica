import feedparser
import ftfy
from bs4 import BeautifulSoup


class RSSFeedParser:
    def parse(self, text: str) -> list[dict]:
        feed = feedparser.parse(text)

        item_list = []
        for entry in feed.entries:
            item_list.append(
                {
                    "published_loc": getattr(entry, "published", None),
                    "title": self._clean(getattr(entry, "title", "")),
                    "summary": self._clean(getattr(entry, "summary", "")),
                    "link": getattr(entry, "link", "").removeprefix("https://").removeprefix("http://").removeprefix("www."),
                }
            )
        return item_list

    def _clean(self, text: str) -> str:
        if not text:
            return ""
        self.soup = BeautifulSoup(text, "html.parser")
        text = self.soup.get_text(separator=" ", strip=True)
        return ftfy.fix_text(text).strip()
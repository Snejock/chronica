"""
Unit-тесты извлечения image_url из RSS-записей.
Каждый fixture — реальный пример из лент RBC, Kommersant, NYT, Haaretz.
"""
import pytest
from packages.parsers import RSSFeedParser


def _wrap(item_xml: str) -> str:
    """Обернуть <item> в минимальный валидный RSS-документ."""
    return (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<rss version="2.0"'
        ' xmlns:media="http://search.yahoo.com/mrss/"'
        ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
        '>'
        "<channel>"
        "<title>Test</title>"
        "<link>https://example.com</link>"
        + item_xml
        + "</channel></rss>"
    )


@pytest.fixture
def parser():
    return RSSFeedParser()


RBC_ITEM = """
<item>
  <title>РЖД задумались о снижении тарифов</title>
  <link>https://www.rbc.ru/business/17/06/2026/6a3160d09a794791c8176ea8</link>
  <pubDate>Wed, 17 Jun 2026 00:00:44 +0300</pubDate>
  <description>Тест</description>
  <enclosure url="https://s0.rbk.ru/v6_top_pics/media/img/1/45/347816219105451.jpeg"
             type="image/jpeg" length="0"/>
</item>
"""

KOMMERSANT_ITEM = """
<item>
  <guid>https://www.kommersant.ru/doc/8739546</guid>
  <title>Ушаков: Путин и Трамп</title>
  <link>https://www.kommersant.ru/doc/8739546</link>
  <enclosure url="https://im2.kommersant.ru/Issues.photo2/NEWS/2026/06/16/KMO_207588_00052_1_t219_223711.jpg"
             type="image/jpeg" length="10371"/>
  <pubDate>Tue, 16 Jun 2026 22:29:20 +0300</pubDate>
  <description>Тест</description>
</item>
"""

NYT_ITEM = """
<item>
  <title>After a Bitter Split</title>
  <link>https://www.nytimes.com/2026/06/16/world/europe/trump-g7-leaders-europe.html</link>
  <pubDate>Tue, 16 Jun 2026 19:32:29 +0000</pubDate>
  <description>A peace framework</description>
  <media:content height="1800" medium="image"
    url="https://static01.nyt.com/images/2026/06/16/multimedia/16int-europe-trump-1-pflc/16int-europe-trump-1-pflc-mediumSquareAt3X.jpg"
    width="1800"/>
</item>
"""

HAARETZ_ITEM = """
<item>
  <title>Reports: U.S.-Iran deal</title>
  <link>https://www.haaretz.com/middle-east-news/iran/2026-06-16/ty-article/0000019e</link>
  <pubDate>Tue, 16 Jun 2026 21:42:29 +0300</pubDate>
  <description>Al Arabiya</description>
  <enclosure url="https://img.haarets.co.il/bs/0000019e-d1bd/394592.jpg?width=108&amp;height=81"
             type="image/jpg" length="0"/>
  <media:content width="140"
    url="https://img.haarets.co.il/bs/0000019e-d1bd/394592.jpg?height=81"/>
</item>
"""


def test_rbc_enclosure(parser):
    """RBC: картинка в <enclosure type="image/jpeg">"""
    items = parser.parse(_wrap(RBC_ITEM))
    assert len(items) == 1
    assert items[0]["image_url"] == "https://s0.rbk.ru/v6_top_pics/media/img/1/45/347816219105451.jpeg"


def test_kommersant_enclosure(parser):
    """Kommersant: картинка в <enclosure type="image/jpeg">"""
    items = parser.parse(_wrap(KOMMERSANT_ITEM))
    assert len(items) == 1
    assert items[0]["image_url"] == (
        "https://im2.kommersant.ru/Issues.photo2/NEWS/2026/06/16/KMO_207588_00052_1_t219_223711.jpg"
    )


def test_nyt_media_content(parser):
    """NYT: картинка только в <media:content>, enclosure отсутствует"""
    items = parser.parse(_wrap(NYT_ITEM))
    assert len(items) == 1
    assert items[0]["image_url"] == (
        "https://static01.nyt.com/images/2026/06/16/multimedia/"
        "16int-europe-trump-1-pflc/16int-europe-trump-1-pflc-mediumSquareAt3X.jpg"
    )


def test_haaretz_prefers_media_content_and_strips_resize(parser):
    """Haaretz: media:content предпочтительнее enclosure; ?height= снимается из URL"""
    items = parser.parse(_wrap(HAARETZ_ITEM))
    assert len(items) == 1
    # media:content (prio 0) выбирается над enclosure (prio 1)
    # параметр height снимается, т.к. путь кончается на .jpg
    assert items[0]["image_url"] == "https://img.haarets.co.il/bs/0000019e-d1bd/394592.jpg"


def test_no_image_returns_none(parser):
    """Без картинки image_url должен быть None"""
    item = """
    <item>
      <title>No image</title>
      <link>https://example.com/article/1</link>
      <pubDate>Tue, 16 Jun 2026 10:00:00 +0000</pubDate>
      <description>Plain text only</description>
    </item>
    """
    items = parser.parse(_wrap(item))
    assert len(items) == 1
    assert items[0]["image_url"] is None
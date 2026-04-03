from pydantic import BaseModel, Field, field_validator
from datetime import datetime, timezone
from typing import Annotated
from dateutil import parser
import xxhash


class RSSItem(BaseModel):
    source_system:  Annotated[str, Field(default="RSS", description="Код системы источника")]
    published_loc:  Annotated[str, Field(description="Дата и время публикации в исходном формате и таймзоне")]
    feed_id:        Annotated[int | None, Field(default=None)]
    feed_nm:        Annotated[str | None, Field(default=None)]
    title:          Annotated[str, Field(..., min_length=1, description="Заголовок сообщения")]
    link:           Annotated[str, Field(..., description="Ссылка на сообщение")]
    summary:        Annotated[str | None, Field(description="Краткое содержание")]

    @property
    def published_utc(self) -> datetime:
        return parser.parse(self.published_loc).astimezone(timezone.utc)

    @property
    def news_id(self) -> str:
        return xxhash.xxh64(self.link.encode('utf-8'), seed=0).hexdigest()


class RSSItemTranslation(BaseModel):
    news_id:            Annotated[str, Field(description="Уникальный идентификатор новости")]
    language_code:      Annotated[str, Field(description="Код языка перевода (ISO 639-1)")]
    translation_engine: Annotated[str | None, Field(default=None, description="Движок перевода")]
    title:              Annotated[str, Field(..., min_length=1, description="Заголовок сообщения")]
    link:               Annotated[str, Field(..., description="Ссылка на сообщение")]
    summary:            Annotated[str | None, Field(default=None, description="Краткое содержание")]

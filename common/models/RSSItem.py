from pydantic import BaseModel, Field, field_validator
from datetime import datetime, timezone
from typing import Annotated
from dateutil import parser


class RSSItem(BaseModel):
    source_system:  Annotated[str, Field(default="RSS", description="Код системы источника")]
    published:      Annotated[str, Field(description="Дата и время публикации в исходном формате и таймзоне")]
    feed_id:        Annotated[int | None, Field(default=None)]
    feed_nm:        Annotated[str | None, Field(default=None)]
    title:          Annotated[str, Field(..., min_length=1, description="Заголовок сообщения")]
    link:           Annotated[str, Field(..., description="Ссылка на сообщение")]
    summary:        Annotated[str | None, Field(description="Краткое содержание")]

    @property
    def published_utc(self) -> datetime:
        return parser.parse(self.published).astimezone(timezone.utc)

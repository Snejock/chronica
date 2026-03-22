from typing import Annotated
from pydantic import BaseModel, Field, ConfigDict, field_validator


class Location(BaseModel):
    country_code: Annotated[str, Field(min_length=2, max_length=2, description="Код страны в формате ISO 3166-1 alpha-2")]
    city: Annotated[str | None, Field(default=None)]

    model_config = ConfigDict(str_strip_whitespace=True)

    @field_validator('country_code')
    @classmethod
    def country_code_lowercase(cls, v: str) -> str:
        return v.lower()

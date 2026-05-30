from typing import Dict, List
from pydantic import BaseModel, Field


class ClickhouseConfig(BaseModel):
    host: str
    port: int
    user: str
    password: str
    secure: bool

class DayRule(BaseModel):
    week_day: int
    is_work_day: int
    start_time: str
    stop_time: str

class SpecialDateRule(BaseModel):
    date: str
    is_work_day: int
    start_time: str
    stop_time: str

class MoexCalendar(BaseModel):
    timezone: str
    weekly: List[DayRule]
    special: List[SpecialDateRule] = []
    lag_start_minutes: int = 0
    lag_stop_minutes: int = 0

class AppConfig(BaseModel):
    clickhouse: ClickhouseConfig
    moex_calendar: MoexCalendar

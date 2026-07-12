import datetime as dt
from zoneinfo import ZoneInfo  # Python 3.9+

class MoexCalendar:
    def __init__(self, moex_calendar):  # moex_calendar = AppConfig.moex_calendar
        self.timezone = ZoneInfo(moex_calendar.timezone)
        self.weekly = {w.week_day: w for w in moex_calendar.weekly}
        self.special = {e.date: e for e in moex_calendar.special}
        self.lag_start = dt.timedelta(minutes=moex_calendar.lag_start_minutes)
        self.lag_stop = dt.timedelta(minutes=moex_calendar.lag_stop_minutes)

    def _get_day_rule(self, date: dt.date):
        date_str = date.isoformat()

        # Проверка, есть ли дата в списке исключений
        if date_str in self.special:
            e = self.special[date_str]
            return (
                e.is_work_day == 1,
                self._convert_to_dt(date, e.start_time),
                self._convert_to_dt(date, e.stop_time),
            )

        # Возвращается общее правило для дня недели
        w = self.weekly.get(date.isoweekday())
        if not w:
            return False, self._convert_to_dt(date, "00:00:00"), self._convert_to_dt(date, "00:00:00")
        return (
            w.is_work_day == 1,
            self._convert_to_dt(date, w.start_time),
            self._convert_to_dt(date, w.stop_time),
        )

    def _convert_to_dt(self, date: dt.date, time_str: str) -> dt.datetime:
        h, m, s = map(int, time_str.split(":"))
        return dt.datetime(date.year, date.month, date.day, h, m, s, tzinfo=self.timezone)

    def is_open(self, at: dt.datetime | None = None) -> bool:
        at = (at or dt.datetime.now(self.timezone)).astimezone(self.timezone)
        for date in (at.date() - dt.timedelta(days=1), at.date()):
            is_work, start_dttm, stop_dttm = self._get_day_rule(date)
            start_dttm = start_dttm + self.lag_start
            stop_dttm = stop_dttm + self.lag_stop
            if is_work and start_dttm <= at <= stop_dttm:
                return True
        return False

    def get_next_open_dttm(self, now: dt.datetime | None = None) -> dt.datetime:
        now = (now or dt.datetime.now(self.timezone)).astimezone(self.timezone)

        if self.is_open(now):
            return now

        # Если сегодня рабочий день и текущее время меньше start_dttm, то возвращается start_dttm сегодняшнего дня
        is_work, start_dttm, end_dttm = self._get_day_rule(now.date())
        if is_work and now < start_dttm + self.lag_start:
            return start_dttm + self.lag_start

        # Иначе выполняется поиск первого рабочего дня и возвращается его start_dttm
        date = now.date()
        for _ in range(366):
            date += dt.timedelta(days=1)
            is_work, start_dttm, end_dttm = self._get_day_rule(date)
            if is_work:
                return start_dttm + self.lag_start
        raise RuntimeError("Next open day not found in schedule window")

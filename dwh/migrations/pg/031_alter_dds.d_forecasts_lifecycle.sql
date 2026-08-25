-- Жизненный цикл прогнозов: status, даты, sequence для forecast_id

-- 1. Новые колонки
ALTER TABLE dds.d_forecasts
    ADD COLUMN IF NOT EXISTS status          text        NOT NULL DEFAULT 'open',
    ADD COLUMN IF NOT EXISTS opened_dttm     timestamp(0) with time zone NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS deadline_dttm   timestamp(0) with time zone,
    ADD COLUMN IF NOT EXISTS resolved_dttm   timestamp(0) with time zone,
    ADD COLUMN IF NOT EXISTS resolution_txt  text;

ALTER TABLE dds.d_forecasts
    ADD CONSTRAINT d_forecasts_status_check
        CHECK (status IN ('open', 'resolved_yes', 'resolved_no', 'expired'));

-- 2. Бэкфилл существующих строк
UPDATE dds.d_forecasts
SET opened_dttm   = _loaded_dttm,
    deadline_dttm = _loaded_dttm + horizon_days * INTERVAL '1 day'
WHERE opened_dttm = now();   -- только что добавленные со значением DEFAULT

-- 3. Sequence для автогенерации forecast_id
CREATE SEQUENCE IF NOT EXISTS dds.d_forecasts__forecast_id_seq;

SELECT setval(
    'dds.d_forecasts__forecast_id_seq',
    COALESCE((SELECT max(forecast_id) FROM dds.d_forecasts), 0) + 1,
    false
);

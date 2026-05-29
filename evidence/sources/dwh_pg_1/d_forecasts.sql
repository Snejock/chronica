SELECT
    forecast_id
    , language_code
    , story_id
    , forecast_nm
    , forecast_txt
    , horizon_days
    , p_prior_prt
    , is_active
FROM dds.d_forecasts

SELECT
    b.forecast_id
    , b.language_code
    , b.forecast_nm
    , b.news_id
    , b.published_dttm
    , b.p_confirm_prt
    , b.p_refute_prt
    , b.p_posterior_prt
    , b.alpha
    , b.beta
    , b.effective_n
    , b.p_lower_95_prt
    , b.p_upper_95_prt
    , f.story_id
    , f.horizon_days
    , f.forecast_txt
FROM bds.b_forecast_posteriors b
JOIN dds.d_forecasts f
    ON  f.forecast_id   = b.forecast_id
    AND f.language_code = b.language_code

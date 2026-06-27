DROP VIEW IF EXISTS bds.b_forecast_posteriors;
CREATE OR REPLACE VIEW bds.b_forecast_posteriors AS
WITH RECURSIVE
    ordered_news AS (
        SELECT
            n.forecast_id,
            f.language_code,
            n.news_id,
            n.published_dttm,
            n.p_confirm_prt::numeric AS p_confirm_prt,
            n.p_refute_prt::numeric  AS p_refute_prt,
            f.forecast_nm,
            -- приор задаётся весом N=5:
            -- чтобы сдвинуть с приора, нужно ~N "средних" новостей
            f.p_prior_prt::numeric        * 5.0 AS alpha_init,
            (1.0 - f.p_prior_prt::numeric) * 5.0 AS beta_init,
            row_number() OVER (
                PARTITION BY n.forecast_id, f.language_code
                ORDER BY n.published_dttm
            ) AS rn
        FROM dds.t_forecast_news n
        JOIN dds.d_forecasts f
            ON f.forecast_id = n.forecast_id
    ),
    n_max AS (SELECT 15.0::numeric AS val),
    bayes AS (
        -- базовый случай: приор + первая новость
        SELECT
            forecast_id,
            language_code,
            forecast_nm,
            news_id,
            published_dttm,
            p_confirm_prt,
            p_refute_prt,
            alpha_init,
            beta_init,
            rn,
            alpha_init + greatest(p_confirm_prt - p_refute_prt, 0) * 3.0 AS alpha,
            beta_init  + greatest(p_refute_prt - p_confirm_prt, 0) * 3.0 AS beta
        FROM ordered_news
        WHERE rn = 1

        UNION ALL

        SELECT
            n.forecast_id,
            n.language_code,
            n.forecast_nm,
            n.news_id,
            n.published_dttm,
            n.p_confirm_prt,
            n.p_refute_prt,
            n.alpha_init,
            n.beta_init,
            n.rn,
            -- затухание + cap: ограничиваем effective_n перед добавлением сигнала
            (SELECT
                CASE WHEN a_dec + b_dec > nm.val
                     THEN a_dec * nm.val / (a_dec + b_dec)
                     ELSE a_dec
                END + greatest(n.p_confirm_prt - n.p_refute_prt, 0) * 3.0
             FROM n_max nm,
             LATERAL (SELECT
                n.alpha_init + (b.alpha - n.alpha_init) * exp(
                    -extract(EPOCH FROM (n.published_dttm - b.published_dttm))::numeric
                    / (3.0 * 86400) * ln(2.0)
                ) AS a_dec,
                n.beta_init + (b.beta - n.beta_init) * exp(
                    -extract(EPOCH FROM (n.published_dttm - b.published_dttm))::numeric
                    / (3.0 * 86400) * ln(2.0)
                ) AS b_dec
             ) decayed
            ) AS alpha,
            (SELECT
                CASE WHEN a_dec + b_dec > nm.val
                     THEN b_dec * nm.val / (a_dec + b_dec)
                     ELSE b_dec
                END + greatest(n.p_refute_prt - n.p_confirm_prt, 0) * 3.0
             FROM n_max nm,
             LATERAL (SELECT
                n.alpha_init + (b.alpha - n.alpha_init) * exp(
                    -extract(EPOCH FROM (n.published_dttm - b.published_dttm))::numeric
                    / (3.0 * 86400) * ln(2.0)
                ) AS a_dec,
                n.beta_init + (b.beta - n.beta_init) * exp(
                    -extract(EPOCH FROM (n.published_dttm - b.published_dttm))::numeric
                    / (3.0 * 86400) * ln(2.0)
                ) AS b_dec
             ) decayed
            ) AS beta
        FROM ordered_news n
        JOIN bayes b
            ON  b.forecast_id   = n.forecast_id
            AND b.language_code = n.language_code
            AND b.rn            = n.rn - 1
    )
SELECT
    forecast_id,
    language_code,
    forecast_nm,
    news_id,
    published_dttm,
    p_confirm_prt,
    p_refute_prt,
    round((alpha / (alpha + beta))::numeric, 3)            AS p_posterior_prt,
    -- диагностика:
    round(alpha::numeric, 2)                               AS alpha,
    round(beta::numeric, 2)                                AS beta,
    round((alpha + beta)::numeric, 1)                      AS effective_n,  -- накопленный вес
    -- 95% доверительный интервал (нормальная аппроксимация Beta)
    round((alpha / (alpha + beta)
      - 1.96 * sqrt(alpha * beta / ((alpha + beta)^2 * (alpha + beta + 1))))::numeric, 3
    ) AS p_lower_95_prt,
    round((alpha / (alpha + beta)
      + 1.96 * sqrt(alpha * beta / ((alpha + beta)^2 * (alpha + beta + 1))))::numeric, 3
    ) AS p_upper_95_prt
FROM bayes
ORDER BY forecast_id, language_code, published_dttm;
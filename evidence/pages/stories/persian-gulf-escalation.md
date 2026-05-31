---
title: Эскалация в Персидском заливе
hide_breadcrumbs: true
---

<script>
  const PAGE_SIZE = 3;
  let shown = PAGE_SIZE;
  let openId = null;
  let openChartId = null;

  $: visible = q_stories_summaries.slice(0, shown);
  $: hasMore = shown < q_stories_summaries.length;

  function newsBarChart(rows) {
    return {
      animation: false,
      grid: { top: 8, bottom: 28, left: 0, right: 0, containLabel: false },
      xAxis: {
        type: 'time', show: true,
        axisLine: { show: true, lineStyle: { color: '#e7e5e4', width: 1 } },
        axisTick: { show: false }, splitLine: { show: false },
        axisLabel: {
          color: '#a8a29e', fontSize: 11, hideOverlap: true,
          formatter: v => {
            const d = new Date(v);
            return `${d.getDate()} ${['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][d.getMonth()]}`;
          }
        }
      },
      yAxis: { type: 'value', show: false },
      series: [{
        type: 'bar',
        data: rows.map(r => [r.day, +r.cnt]),
        itemStyle: { color: '#57534e', borderRadius: [3, 3, 0, 0] },
        barMaxWidth: 18
      }]
    };
  }

  function forecastChart(rows) {
    const vals = rows.map(r => +r.p_posterior_prt);
    const lo = Math.max(0, Math.min(...vals) - 0.05);
    const hi = Math.min(1, Math.max(...vals) + 0.05);
    return {
      animation: false,
      grid: { top: 8, bottom: 28, left: 0, right: 0, containLabel: false },
      xAxis: {
        type: 'time', show: true,
        splitNumber: 4,
        minInterval: 86400000 * 7,
        axisLine: { show: true, lineStyle: { color: '#e7e5e4', width: 1 } }, axisTick: { show: false }, splitLine: { show: false },
        axisLabel: {
          color: '#a8a29e', fontSize: 11, hideOverlap: true,
          formatter: v => {
            const d = new Date(v);
            return `${d.getDate()} ${['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][d.getMonth()]}`;
          }
        }
      },
      yAxis: { type: 'value', show: false, min: lo, max: hi },
      series: [{
        type: 'line',
        data: rows.map(r => [r.published_dttm, +r.p_posterior_prt]),
        symbol: 'none',
        lineStyle: { color: '#57534e', width: 1 },
        areaStyle: {
          color: {
            type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: 'rgba(87,83,78,0.15)' },
              { offset: 1, color: 'rgba(87,83,78,0)' }
            ]
          }
        },
      }]
    };
  }


  function formatDelta(d) {
    const v = +d;
    if (Math.abs(v) < 0.05) return { arrow: '', arrowColor: '#a8a29e', textColor: '#a8a29e', text: 'без изменений' };
    return v > 0
      ? { arrow: '▲', arrowColor: '#86efac', textColor: '#a8a29e', text: `+${v.toFixed(1)}% за 24 ч.` }
      : { arrow: '▼', arrowColor: '#fca5a5', textColor: '#a8a29e', text: `${v.toFixed(1)}% за 24 ч.` };
  }
</script>

```sql q_stories_summaries
SELECT
    dt
    , strftime(dt, '%d') || ' ' ||
      CASE extract(month FROM dt)
        WHEN 1  THEN 'января'   WHEN 2  THEN 'февраля'
        WHEN 3  THEN 'марта'    WHEN 4  THEN 'апреля'
        WHEN 5  THEN 'мая'      WHEN 6  THEN 'июня'
        WHEN 7  THEN 'июля'     WHEN 8  THEN 'августа'
        WHEN 9  THEN 'сентября' WHEN 10 THEN 'октября'
        WHEN 11 THEN 'ноября'   WHEN 12 THEN 'декабря'
      END || ' ' || strftime(dt, '%Y') AS formatted_dt
    , headline_txt
    , summary_txt
FROM dwh_pg_1.stories_summaries_d
WHERE language_code = 'ru'
  AND story_id = 1
ORDER BY dt DESC
```

```sql q_forecasts
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecasts_posteriors
    WHERE language_code = 'ru' AND story_id = 1
    GROUP BY forecast_id
),
prev AS (
    SELECT b.forecast_id, b.p_posterior_prt AS p_prev
    FROM dwh_pg_1.b_forecasts_posteriors b
    JOIN latest l ON l.forecast_id = b.forecast_id
    WHERE b.language_code = 'ru'
      AND b.story_id = 1
      AND b.published_dttm <= l.dttm - INTERVAL '24 hours'
    QUALIFY row_number() OVER (PARTITION BY b.forecast_id ORDER BY b.published_dttm DESC) = 1
)
SELECT
    b.forecast_id,
    b.forecast_nm,
    b.horizon_days,
    CAST(ROUND(b.p_posterior_prt * 100) AS INTEGER) AS pct,
    ROUND((b.p_posterior_prt - COALESCE(p.p_prev, b.p_posterior_prt)) * 100, 1) AS delta_pp,
    b.forecast_txt
FROM dwh_pg_1.b_forecasts_posteriors b
JOIN latest l ON l.forecast_id = b.forecast_id AND l.dttm = b.published_dttm
LEFT JOIN prev p ON p.forecast_id = b.forecast_id
WHERE b.language_code = 'ru' AND b.story_id = 1
ORDER BY b.p_posterior_prt DESC
```

```sql q_forecasts_history
SELECT forecast_id, published_dttm, p_posterior_prt
FROM dwh_pg_1.b_forecasts_posteriors
WHERE language_code = 'ru' AND story_id = 1
ORDER BY forecast_id, published_dttm
```

```sql q_news_by_day
SELECT
    CAST(published_dttm AS DATE) AS day,
    COUNT(*) AS cnt
FROM dwh_pg_1.b_unews_stories_texts
WHERE story_id = 1
  AND published_dttm >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1
```

## Активность за 30 дней

<div class="not-prose mb-10" style="width:100%; height:120px">
  <ECharts config={newsBarChart(q_news_by_day)} height="120px" />
</div>

{#if q_forecasts.length > 0}

## Вероятность развития в следующие {q_forecasts[0].horizon_days} дней

<div class="not-prose mt-2 mb-10">
  <div class="flex flex-col gap-3">
    {#each q_forecasts as f}
      {@const delta = formatDelta(f.delta_pp)}
      <div class="py-2">
        <div class="flex justify-between items-baseline mb-2">
          <p
            class="text-sm font-medium text-gray-900 pr-4 leading-snug cursor-pointer select-none"
            on:click={() => { openId = openId === f.forecast_id ? null : f.forecast_id; if (openId) openChartId = null; }}
          >
            {f.forecast_nm}
            <span style="color:#c4bca9; font-size:1.1rem; margin-left:2px; display:inline-block; transform:rotate({openId === f.forecast_id ? '90deg' : '0deg'}); transition:transform 0.2s">›</span>
          </p>
          <div class="flex items-center gap-2">
            <p class="text-sm font-medium tabular-nums text-gray-900">{f.pct}%</p>
            <button
              type="button"
              style="background:none; border:none; padding:0; cursor:pointer; line-height:1; color:{openChartId === f.forecast_id ? '#57534e' : '#c4bca9'}"
              on:click={() => { openChartId = openChartId === f.forecast_id ? null : f.forecast_id; if (openChartId) openId = null; }}
            >
              <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
                <polyline points="1,12 4,7 7,9 10,4 14,6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
          </div>
        </div>

        {#if openId === f.forecast_id}
          <div class="mb-2 px-3 py-2 rounded-lg text-xs leading-relaxed text-stone-600" style="background-color:#f5f4f2; border:1px solid #e7e5e4">
            {f.forecast_txt}
          </div>
        {/if}

        {#if openChartId === f.forecast_id}
          {@const history = q_forecasts_history.filter(r => r.forecast_id === f.forecast_id)}
          {#if history.length > 1}
            <div style="width:100%; height:100px; margin-bottom:0.5rem">
              <ECharts config={forecastChart(history)} height="100px" />
            </div>
          {/if}
        {:else}
          <div class="h-1.5 w-full rounded-full overflow-hidden mb-1.5" style="background-color:#e7e5e4">
            <div class="h-full rounded-full" style="background-color:#57534e; width:{f.pct}%"></div>
          </div>
          <p class="text-xs">
            {#if delta.arrow}<span style="color:{delta.arrowColor}">{delta.arrow}</span>{/if}
            <span style="color:{delta.textColor}"> {delta.text}</span>
          </p>
        {/if}
      </div>
    {/each}
  </div>
</div>

{/if}

## Хроника событий

{#if q_stories_summaries.length > 0}
<div class="not-prose mt-4 relative" style="padding-left:12px">
  <div class="absolute top-0 bottom-0" style="left:5px; width:1px; background-color:#c4bca9"></div>
  {#each visible as entry, i}
    <div class="relative pl-4 mb-4">
      <div class="absolute rounded-full" style="top:12px; left:-11px; width:8px; height:8px; background-color:#c4bca9; box-shadow:0 0 0 3px white"></div>
      <div class="pl-2 pr-2 py-2">
        <p class="text-xs uppercase tracking-wide text-stone-400 mb-1">{entry.formatted_dt}</p>
        <p class="text-base font-medium text-gray-900 mb-2">{entry.headline_txt}</p>
        <input type="checkbox" id="exp-{i}" class="hidden peer">
        <p class="text-gray-600 leading-relaxed text-sm line-clamp-5 peer-checked:line-clamp-none">{entry.summary_txt}</p>
        <label for="exp-{i}" class="peer-checked:hidden text-xs mt-2 block cursor-pointer hover:text-stone-500" style="color:#a8a29e">читать далее →</label>
        <label for="exp-{i}" class="hidden peer-checked:block text-xs mt-2 cursor-pointer hover:text-stone-500" style="color:#a8a29e">скрыть ↑</label>
      </div>
    </div>
  {/each}

  {#if hasMore}
  <div class="mt-2 text-center">
    <button
      type="button"
      class="text-xs text-[#c4bca9] cursor-pointer hover:text-stone-500"
      on:click={() => shown += PAGE_SIZE}
    >Предыдущие дни</button>
  </div>
  {/if}
</div>
{:else}
<div class="not-prose mt-4 p-6 bg-amber-50 border border-amber-200 rounded-xl">
  <p class="text-amber-800 text-sm">Ежедневные сводки новостей для этого сюжета пока не сформированы.</p>
</div>
{/if}

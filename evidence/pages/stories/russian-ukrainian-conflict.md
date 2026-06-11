---
title: Конфликт России и Украины
hide_breadcrumbs: true
---

<script>
  const PAGE_SIZE = 3;
  let shown = PAGE_SIZE;
  let activityOpen = false;
  let selectedForecast = null;
  let openInfoId = null;
  let openChartId = null;

  $: visible = q_stories_summaries.slice(0, shown);
  $: hasMore = shown < q_stories_summaries.length;

  let hovered = {};

  // Линейная интерполяция между двумя hex-цветами, t от 0 до 1
  function lerpColor(a, b, t) {
    const pa = a.match(/\w\w/g).map(h => parseInt(h, 16));
    const pb = b.match(/\w\w/g).map(h => parseInt(h, 16));
    const rgb = pa.map((c, i) => Math.round(c + (pb[i] - c) * t));
    return `rgb(${rgb.join(',')})`;
  }

  // Цвет верха бара: чем выше столбец (intensity 0..1), тем теплее — от красного к оранжевому и жёлтому
  // (палитра в духе Grafana: red -> orange -> yellow)
  function barTopColor(intensity) {
    if (intensity <= 0.5) return lerpColor('#F2495C', '#FF9830', intensity / 0.5);
    return lerpColor('#FF9830', '#FADE2A', (intensity - 0.5) / 0.5);
  }

  // Добавляет альфа-канал к цвету в формате rgb(...)
  function withAlpha(rgbStr, alpha) {
    const m = rgbStr.match(/\d+/g);
    return `rgba(${m[0]},${m[1]},${m[2]},${alpha})`;
  }

  function newsBarChart(rows) {
    const maxCnt = Math.max(1, ...rows.map(r => +r.cnt));
    return {
      backgroundColor: '#faf9f7',
      animation: true,
      animationDuration: 600,
      animationEasing: 'cubicOut',
      grid: { top: 8, bottom: 28, left: 0, right: 0, containLabel: false },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'none' },
        backgroundColor: '#1c1917',
        borderColor: '#1c1917',
        borderRadius: 8,
        padding: [6, 10],
        textStyle: { color: '#e7e5e4', fontSize: 12 },
        formatter: params => {
          const d = new Date(params[0].value[0]);
          const day = `${d.getDate()} ${['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][d.getMonth()]}`;
          const cnt = params[0].value[1];
          return `<span style="color:#a8a29e;font-size:11px">${day}</span><br/><b>${cnt}</b> материал${cnt === 1 ? '' : cnt < 5 ? 'а' : 'ов'}`;
        }
      },
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
        data: rows.map(r => ({
          value: [r.day, +r.cnt],
          itemStyle: {
            borderRadius: [3, 3, 0, 0],
            color: {
              type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
              colorStops: [
                { offset: 0, color: barTopColor(+r.cnt / maxCnt) },
                { offset: 1, color: '#C4162A' }
              ]
            }
          }
        })),
        emphasis: {
          itemStyle: { opacity: 0.8 }
        },
        barMaxWidth: 18
      }]
    };
  }

  function forecastChart(rows, pct) {
    const vals = rows.map(r => +r.p_posterior_prt);
    const lo = Math.max(0, Math.min(...vals) - 0.05);
    const hi = Math.min(1, Math.max(...vals) + 0.05);
    const lineColor = barTopColor(Math.max(0, Math.min(1, pct / 100)));
    return {
      backgroundColor: '#faf9f7',
      animation: true,
      animationDuration: 600,
      animationEasing: 'cubicOut',
      grid: { top: 8, bottom: 22, left: 0, right: 0, containLabel: false },
      tooltip: {
        trigger: 'axis',
        axisPointer: { type: 'line', lineStyle: { color: '#d6d3d1', type: 'dashed', width: 1 } },
        backgroundColor: '#1c1917',
        borderColor: '#1c1917',
        borderRadius: 8,
        padding: [6, 10],
        textStyle: { color: '#e7e5e4', fontSize: 12 },
        formatter: params => {
          const d = new Date(params[0].value[0]);
          const day = `${d.getDate()} ${['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][d.getMonth()]}`;
          const pct = (params[0].value[1] * 100).toFixed(1);
          return `<span style="color:#a8a29e;font-size:11px">${day}</span><br/><b>${pct}%</b>`;
        }
      },
      xAxis: {
        type: 'time', show: true,
        splitNumber: 3,
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
        symbol: 'circle',
        symbolSize: 0,
        emphasis: { scale: false },
        lineStyle: { color: lineColor, width: 1.5 },
        areaStyle: {
          color: {
            type: 'linear', x: 0, y: 0, x2: 0, y2: 1,
            colorStops: [
              { offset: 0, color: withAlpha(lineColor, 0.25) },
              { offset: 1, color: 'rgba(196,22,42,0)' }
            ]
          }
        },
      }]
    };
  }

  // Перетаскивание мышью/тачпадом + горизонтальная прокрутка колесом для карусели прогнозов
  function dragScroll(node) {
    // На тач-устройствах горизонтальный свайп и snap уже работают нативно
    // (overflow-x:auto), поэтому drag-обработчики только для мыши/пера.
    let dragging = false;
    let moved = false;
    let startX = 0;
    let startScroll = 0;

    // move/up слушаем на window в capture-фазе: так stopPropagation() на
    // карточке/кнопке (см. tappable) не мешает нам сбросить состояние drag.
    function onPointerDown(e) {
      if (e.pointerType !== 'mouse') return;
      dragging = true;
      moved = false;
      startX = e.clientX;
      startScroll = node.scrollLeft;
      window.addEventListener('pointermove', onPointerMove, true);
      window.addEventListener('pointerup', onPointerUp, true);
      window.addEventListener('pointercancel', onPointerUp, true);
    }
    function onPointerMove(e) {
      if (!dragging) return;
      const dx = e.clientX - startX;
      if (!moved && Math.abs(dx) > 5) {
        moved = true;
        node.style.scrollSnapType = 'none';
        node.style.cursor = 'grabbing';
      }
      if (moved) node.scrollLeft = startScroll - dx;
    }
    function onPointerUp() {
      if (!dragging) return;
      dragging = false;
      node.style.cursor = 'grab';
      node.style.scrollSnapType = 'x proximity';
      window.removeEventListener('pointermove', onPointerMove, true);
      window.removeEventListener('pointerup', onPointerUp, true);
      window.removeEventListener('pointercancel', onPointerUp, true);
    }
    function onWheel(e) {
      if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) {
        node.scrollLeft += e.deltaY;
        e.preventDefault();
      }
    }

    node.addEventListener('pointerdown', onPointerDown);
    node.addEventListener('wheel', onWheel, { passive: false });

    return {
      destroy() {
        node.removeEventListener('pointerdown', onPointerDown);
        node.removeEventListener('wheel', onWheel);
        window.removeEventListener('pointermove', onPointerMove, true);
        window.removeEventListener('pointerup', onPointerUp, true);
        window.removeEventListener('pointercancel', onPointerUp, true);
      }
    };
  }

  // Тап без учёта нативного click — на тач-устройствах во время инерционной
  // прокрутки/snap браузер гасит click, но pointerdown/pointerup всё равно
  // приходят, поэтому ловим короткое нажатие без сдвига сами.
  function tappable(node) {
    let startX = 0;
    let startY = 0;
    let startT = 0;
    let moved = false;

    function onDown(e) {
      startX = e.clientX;
      startY = e.clientY;
      startT = Date.now();
      moved = false;
    }
    function onMove(e) {
      // Порог совпадает с порогом старта drag в dragScroll, чтобы сдвиг,
      // который начинает скролл карусели, гарантированно отменял тап.
      if (Math.abs(e.clientX - startX) > 5 || Math.abs(e.clientY - startY) > 5) moved = true;
    }
    function onUp(e) {
      // Гасим всплытие pointerup, чтобы родительский use:tappable
      // (карточка) не обработал то же нажатие повторно как свой тап.
      if (!moved) {
        e.stopPropagation();
        if (Date.now() - startT < 500) {
          node.dispatchEvent(new CustomEvent('tap', { bubbles: true, cancelable: true }));
        }
      }
    }

    node.addEventListener('pointerdown', onDown);
    node.addEventListener('pointermove', onMove);
    node.addEventListener('pointerup', onUp);

    return {
      destroy() {
        node.removeEventListener('pointerdown', onDown);
        node.removeEventListener('pointermove', onMove);
        node.removeEventListener('pointerup', onUp);
      }
    };
  }

  function formatDelta(d) {
    const v = +d;
    if (Math.abs(v) < 0.05) return { arrow: '', arrowColor: '#a8a29e', textColor: '#a8a29e', text: 'без изменений' };
    return v > 0
      ? { arrow: '▲', arrowColor: '#86efac', textColor: '#a8a29e', text: `+${v.toFixed(1)}% за 24 ч.` }
      : { arrow: '▼', arrowColor: '#fca5a5', textColor: '#a8a29e', text: `${v.toFixed(1)}% за 24 ч.` };
  }

  // Миникарта региона (как на странице /stories) — статичный Leaflet-просмотр
  onMount(async () => {
    if (!document.querySelector('link[data-leaflet]')) {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
      link.setAttribute('data-leaflet', '');
      document.head.appendChild(link);
    }

    const L = (await import('leaflet')).default;

    document.querySelectorAll('[data-leaflet-map]').forEach(el => {
      const lat  = parseFloat(el.dataset.lat);
      const lon  = parseFloat(el.dataset.lon);
      const zoom = parseInt(el.dataset.zoom);

      const map = L.map(el, {
        center: [lat, lon],
        zoom,
        zoomControl:      false,
        dragging:         false,
        touchZoom:        false,
        doubleClickZoom:  false,
        scrollWheelZoom:  false,
        boxZoom:          false,
        keyboard:         false,
        attributionControl: false,
      });

      L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
        subdomains: 'abcd',
        maxZoom: 19,
      }).addTo(map);

      L.circleMarker([lat, lon], {
        radius:      7,
        fillColor:   '#57534e',
        color:       '#ffffff',
        weight:      2.5,
        opacity:     1,
        fillOpacity: 1,
      }).addTo(map);
    });
  });
</script>

<style>
  .forecast-carousel {
    cursor: grab;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .forecast-carousel::-webkit-scrollbar {
    display: none;
  }
</style>

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
    , strftime(dt, '%Y-%m-%d') AS iso_dt
    , headline_txt
    , summary_txt
FROM dwh_pg_1.stories_summaries_d
WHERE language_code = 'ru'
  AND story_id = 2
ORDER BY dt DESC
```

```sql q_forecasts
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecasts_posteriors
    WHERE language_code = 'ru' AND story_id = 2
    GROUP BY forecast_id
),
prev AS (
    SELECT b.forecast_id, b.p_posterior_prt AS p_prev
    FROM dwh_pg_1.b_forecasts_posteriors b
    JOIN latest l ON l.forecast_id = b.forecast_id
    WHERE b.language_code = 'ru'
      AND b.story_id = 2
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
WHERE b.language_code = 'ru' AND b.story_id = 2
ORDER BY b.p_posterior_prt DESC
```

```sql q_forecasts_history
SELECT forecast_id, published_dttm, p_posterior_prt
FROM dwh_pg_1.b_forecasts_posteriors
WHERE language_code = 'ru' AND story_id = 2
ORDER BY forecast_id, published_dttm
```

```sql q_news_by_day
SELECT
    CAST(published_dttm AS DATE) AS day,
    COUNT(*) AS cnt
FROM dwh_pg_1.b_unews_stories_texts
WHERE story_id = 2
  AND published_dttm >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1
```

## Хроника событий

{#if q_stories_summaries.length > 0}
<div class="not-prose mt-6 relative" style="padding-left:52px">
  <!-- Вертикальная линия -->
  <div class="absolute" style="top:0; bottom:20px; left:28px; width:1px; background:#e7e5e4"></div>

  {#each visible as entry, i}
    {@const _p = entry.iso_dt.split('-')}
    {@const _day = parseInt(_p[2])}
    {@const _mon = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'][parseInt(_p[1])-1]}

    <div class="relative mb-3"
         on:mouseenter={() => { hovered[i]=true; hovered=hovered; }}
         on:mouseleave={() => { hovered[i]=false; hovered=hovered; }}>

      <!-- Дата (слева от вертикальной линии) -->
      <div class="absolute text-right select-none pointer-events-none" style="top:14px; left:-52px; width:22px">
        <span class="block font-medium" style="font-size:15px; line-height:1.1; color:#57534e">{_day}</span>
        <span class="block" style="font-size:11px; color:#c4bca9; margin-top:1px">{_mon}</span>
      </div>

      <!-- Точка на вертикальной линии -->
      <div class="absolute rounded-full pointer-events-none" style="top:16px; left:-28px; width:8px; height:8px; transition:background 0.2s ease, box-shadow 0.2s ease; background:{hovered[i] ? '#fca5a5' : '#e7e5e4'}; box-shadow:{hovered[i] ? '0 0 0 3px rgba(252,165,165,0.25)' : 'none'}"></div>

      <!-- Соединительная линия (появляется при ховере) -->
      <div class="absolute pointer-events-none" style="top:20px; left:-20px; width:20px; height:1px; background:#c4bca9; opacity:{hovered[i] ? 1 : 0}; transition:opacity 0.2s ease"></div>

      <!-- Карточка -->
      <div class="rounded-xl px-4 py-3 border transition-colors" style="background:#faf9f7; border-color:{hovered[i] ? '#d6d3d1' : 'transparent'}">

        <p class="text-sm font-medium leading-snug mb-2" style="color:#15140F">{entry.headline_txt}</p>

        {#if entry.summary_txt}
          <p class="text-xs leading-relaxed" style="color:#57534e">{entry.summary_txt}</p>
        {/if}

        <a href="/stories/russian-ukrainian-conflict/{entry.iso_dt}"
           on:click|stopPropagation
           class="inline-flex items-center mt-3 text-xs"
           style="color:#c4bca9"
           onmouseover="this.style.color='#78716c'" onmouseout="this.style.color='#c4bca9'">Подробнее →</a>
      </div>
    </div>
  {/each}

  {#if hasMore}
  <div class="mt-2 text-center">
    <button type="button"
      class="text-xs text-[#c4bca9] cursor-pointer hover:text-stone-500"
      on:click={() => shown += PAGE_SIZE}>Предыдущие дни</button>
  </div>
  {/if}
</div>
{:else}
<div class="not-prose mt-4 p-6 bg-amber-50 border border-amber-200 rounded-xl">
  <p class="text-amber-800 text-sm">Ежедневные сводки новостей для этого сюжета пока не сформированы.</p>
</div>
{/if}

{#if q_forecasts.length > 0}

## Прогноз на {q_forecasts[0].horizon_days} дней

<div class="forecast-carousel not-prose mt-2 mb-10" use:dragScroll
     style="display:flex; gap:12px; overflow-x:auto; scroll-snap-type:x proximity; padding-bottom:4px; user-select:none; -webkit-user-select:none;">
  {#each q_forecasts as f}
    {@const delta = formatDelta(f.delta_pp)}
    <div class="rounded-xl px-4 py-3 border transition-colors cursor-pointer"
         style="flex:0 0 78%; max-width:280px; scroll-snap-align:start; background:#faf9f7; border-color:{selectedForecast === f.forecast_id ? '#d6d3d1' : 'transparent'};"
         use:tappable
         on:tap={() => {
           if (selectedForecast === f.forecast_id) {
             selectedForecast = null; openInfoId = null; openChartId = null;
           } else {
             selectedForecast = f.forecast_id; openInfoId = null; openChartId = null;
           }
         }}>
      <div class="flex items-start justify-between gap-2 mb-3">
        <p class="text-sm font-medium leading-snug" style="color:#15140F; min-height:2.6em">{f.forecast_nm}</p>
        {#if selectedForecast === f.forecast_id}
          <button type="button"
            style="background:none; border:none; padding:0; cursor:pointer; line-height:1; flex-shrink:0; color:{openInfoId === f.forecast_id ? '#57534e' : '#c4bca9'}"
            use:tappable
            on:tap|stopPropagation={() => { openInfoId = openInfoId === f.forecast_id ? null : f.forecast_id; if (openInfoId) openChartId = null; }}>
            <svg width="15" height="15" viewBox="0 0 16 16" fill="none">
              <circle cx="8" cy="8" r="6.5" stroke="currentColor" stroke-width="1.4"/>
              <line x1="8" y1="7.2" x2="8" y2="11" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
              <circle cx="8" cy="4.7" r="0.9" fill="currentColor"/>
            </svg>
          </button>
        {/if}
      </div>

      <div class="flex items-center justify-between mb-3">
        <p class="text-3xl font-semibold tabular-nums" style="color:#15140F">{f.pct}%</p>
        {#if selectedForecast === f.forecast_id}
          <button type="button"
            style="background:none; border:none; padding:0; cursor:pointer; line-height:1; color:{openChartId === f.forecast_id ? '#57534e' : '#c4bca9'}"
            use:tappable
            on:tap|stopPropagation={() => { openChartId = openChartId === f.forecast_id ? null : f.forecast_id; if (openChartId) openInfoId = null; }}>
            <svg width="15" height="15" viewBox="0 0 15 15" fill="none">
              <polyline points="1,12 4,7 7,9 10,4 14,6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </button>
        {/if}
      </div>

      {#if openInfoId === f.forecast_id}
        <div class="mb-2 px-3 py-2 rounded-lg text-xs leading-relaxed text-stone-600" style="background-color:#f5f4f2; border:1px solid #e7e5e4">
          {f.forecast_txt}
        </div>
      {/if}

      {#if openChartId === f.forecast_id}
        {@const history = q_forecasts_history.filter(r => r.forecast_id === f.forecast_id)}
        {#if history.length > 1}
          <div style="width:100%; height:90px; margin-bottom:0.5rem">
            <ECharts config={forecastChart(history, f.pct)} height="90px" />
          </div>
        {/if}
      {/if}

      <div class="h-1.5 w-full rounded-full overflow-hidden mb-1.5" style="background-color:#e7e5e4">
        <div class="h-full rounded-full" style="background:linear-gradient(to right, #C4162A, {barTopColor(f.pct / 100)}); width:{f.pct}%"></div>
      </div>
      <p class="text-xs">
        {#if delta.arrow}<span style="color:{delta.arrowColor}">{delta.arrow}</span>{/if}
        <span style="color:{delta.textColor}"> {delta.text}</span>
      </p>
    </div>
  {/each}
</div>

{/if}

## Карта событий

<div class="not-prose mt-2 mb-10 rounded-xl overflow-hidden" style="background:#ffffff; height:200px">
  <div data-leaflet-map="" data-lat="49" data-lon="32" data-zoom="5" style="height:100%; width:100%"></div>
</div>

<div class="not-prose mt-2 mb-10 rounded-xl border transition-colors overflow-hidden" style="background:#faf9f7; border-color:{activityOpen ? '#d6d3d1' : 'transparent'}">
  <button type="button"
    class="w-full flex items-center justify-between px-4 py-3 cursor-pointer select-none"
    style="background:none; border:none"
    on:click={() => activityOpen = !activityOpen}>
    <span class="text-sm font-medium" style="color:#15140F">Активность за 30 дней</span>
    <span style="color:#c4bca9; display:inline-flex; transform:rotate({activityOpen ? '180deg' : '0deg'}); transition:transform 0.2s">
      <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
        <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
    </span>
  </button>
  {#if activityOpen}
    <div class="px-4 pb-4" style="width:100%; height:120px">
      <ECharts config={newsBarChart(q_news_by_day)} height="120px" />
    </div>
  {/if}
</div>
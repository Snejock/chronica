---
full_width: false
hide_breadcrumbs: true
---

<script>
  import { getContext as _getCtx } from 'svelte';
  import { goto } from '$app/navigation';
  import { slide } from 'svelte/transition';
  const breadcrumb = _getCtx('breadcrumb');
  $: if (q_story?.[0]?.story_nm) breadcrumb?.set({ storyName: q_story[0].story_nm });

  let pageEl;

  onMount(() => {
    requestAnimationFrame(updateGrayscale);

    function rubberBand(x, max = 80) {
      return max * (1 - 1 / (x * 0.55 / max + 1));
    }

    let hitY = null, applied = 0, edge = null;
    let startX = null, startY = null, axis = null; // 'h' | 'v' | null
    const isTop    = () => window.scrollY <= 1;
    const isBottom = () => window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4;

    function reset(animate) {
      if (applied > 0 && pageEl) {
        if (animate) {
          pageEl.style.transition = 'transform 0.5s cubic-bezier(0.22, 1, 0.36, 1)';
          pageEl.style.transform  = '';
          setTimeout(() => { if (pageEl) pageEl.style.transition = ''; }, 500);
        } else {
          pageEl.style.transform = '';
        }
      }
      hitY = null; applied = 0; edge = null;
      startX = null; startY = null; axis = null;
    }

    function onTouchStart(e) {
      reset(false);
      if (e.touches.length === 1) {
        startX = e.touches[0].clientX;
        startY = e.touches[0].clientY;
      }
    }

    function onTouchMove(e) {
      if (!pageEl || e.touches.length !== 1) return;
      const tx = e.touches[0].clientX;
      const ty = e.touches[0].clientY;

      // Определяем ось жеста по первым 6px движения и фиксируем до touchend
      if (axis === null && startX !== null) {
        const dx = Math.abs(tx - startX);
        const dy = Math.abs(ty - startY);
        if (dx > 6 || dy > 6) axis = dx > dy ? 'h' : 'v';
      }
      // Горизонтальный свайп (карусель) — не трогаем страницу
      if (axis === 'h') return;

      if (isBottom()) {
        if (edge !== 'bottom') { edge = 'bottom'; hitY = ty; }
        const over = hitY - ty;
        if (over > 0) {
          applied = rubberBand(over);
          pageEl.style.transform = `translateY(${-applied}px)`;
          e.preventDefault();
        } else if (applied > 0) { applied = 0; pageEl.style.transform = ''; }

      } else if (isTop()) {
        if (edge !== 'top') { edge = 'top'; hitY = ty; }
        const over = ty - hitY;
        if (over > 0) {
          applied = rubberBand(over);
          pageEl.style.transform = `translateY(${applied}px)`;
          e.preventDefault();
        } else if (applied > 0) { applied = 0; pageEl.style.transform = ''; }

      } else {
        if (applied > 0) { applied = 0; pageEl.style.transform = ''; }
        hitY = null; edge = null;
      }
    }

    function onTouchEnd() { reset(true); }

    document.addEventListener('touchstart',  onTouchStart,  { passive: true });
    document.addEventListener('touchmove',   onTouchMove,   { passive: false });
    document.addEventListener('touchend',    onTouchEnd);
    document.addEventListener('touchcancel', onTouchEnd);

    return () => {
      document.removeEventListener('touchstart',  onTouchStart);
      document.removeEventListener('touchmove',   onTouchMove);
      document.removeEventListener('touchend',    onTouchEnd);
      document.removeEventListener('touchcancel', onTouchEnd);
    };
  });

  const PAGE_SIZE = 3;
  let shown = PAGE_SIZE;
  let activityOpen = false;
  let slidForecastId = null;
  let openInfoId = null;
  let openChartId = null;

  $: visible = q_stories_summaries.slice(0, shown);
  $: hasMore = shown < q_stories_summaries.length;

  let hovered = {};

  let truncated  = {};
  let expanded   = {};
  let fullHeight = {};

  let imgError = {};
  function absUrl(url) {
    if (!url) return url;
    return /^https?:\/\//i.test(url) ? url : 'https://' + url;
  }

  $: dayImages = Object.fromEntries((q_day_images || []).map(r => [r.day, r.image_url]));

  function clampDetect(node, uid) {
    const measure = () => {
      const lh = parseFloat(getComputedStyle(node).lineHeight) || 20;
      fullHeight[uid] = node.scrollHeight;
      const isTrunc = node.scrollHeight > lh * 4 + 4;
      if (truncated[uid] !== isTrunc) {
        truncated[uid] = isTrunc;
        truncated = truncated;
      }
    };
    requestAnimationFrame(measure);
    const ro = new ResizeObserver(measure);
    ro.observe(node);
    return { destroy() { ro.disconnect(); } };
  }

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
      node.style.scrollSnapType = '';
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

  let chronicleEl;
  let slideGrayscale = { 0: 0 };

  function updateGrayscale() {
    if (!chronicleEl) return;
    const slideW = chronicleEl.clientWidth - 44;
    const viewCenter = chronicleEl.scrollLeft + chronicleEl.clientWidth / 2;
    const next = {};
    visible.forEach((_, i) => {
      const dist = Math.abs(i * slideW + slideW / 2 - viewCenter);
      next[i] = Math.min(1, dist / (slideW * 0.6));
    });
    slideGrayscale = next;
  }

  let expandedScrollLeft = null;

  function onChronicleScroll(e) {
    const el = e.currentTarget;
    updateGrayscale();
    const hasExpanded = Object.values(expanded).some(Boolean);

    if (hasExpanded) {
      if (expandedScrollLeft === null) expandedScrollLeft = el.scrollLeft;
      if (Math.abs(el.scrollLeft - expandedScrollLeft) > 48) {
        expanded = {};
        expandedScrollLeft = null;
      }
    } else {
      expandedScrollLeft = null;
    }

    if (!hasMore) return;
    if (el.scrollLeft + el.clientWidth >= el.scrollWidth - el.clientWidth) {
      shown += PAGE_SIZE;
    }
  }

  function formatDelta(d) {
    const v = +d;
    if (Math.abs(v) < 0.05) return { arrow: '', arrowColor: '#a8a29e', textColor: '#a8a29e', text: 'без изменений' };
    return v > 0
      ? { arrow: '▲', arrowColor: '#86efac', textColor: '#a8a29e', text: `+${v.toFixed(1)}% за 24 ч.` }
      : { arrow: '▼', arrowColor: '#fca5a5', textColor: '#a8a29e', text: `${v.toFixed(1)}% за 24 ч.` };
  }

  // Миникарта региона (как на странице /stories) — статичный Leaflet-просмотр.
  // Координаты приходят асинхронно из q_story, поэтому карта появляется в DOM
  // не сразу — инициализируем её через use:-action на момент монтирования
  // самого элемента, а не через onMount всей страницы.
  function leafletMap(node, params) {
    let map;
    let destroyed = false;
    let initializing = false;

    // Координаты могут прийти не сразу: при первом монтировании реактивные
    // данные ещё не загрузились (lat/lon = NaN). use:-action без update()
    // вызывается лишь раз, поэтому ждём через update() валидных значений.
    async function tryInit({ lat, lon, zoom }) {
      if (map || initializing || destroyed) return;
      if (!Number.isFinite(lat) || !Number.isFinite(lon)) return;
      initializing = true;

      let cssReady;
      let link = document.querySelector('link[data-leaflet]');
      if (link) {
        cssReady = Promise.resolve();
      } else {
        link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        link.setAttribute('data-leaflet', '');
        cssReady = new Promise(resolve => { link.onload = resolve; });
        document.head.appendChild(link);
      }

      const [L] = await Promise.all([
        import('leaflet').then(m => m.default),
        cssReady,
      ]);
      if (destroyed) return;

      map = L.map(node, {
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

      requestAnimationFrame(() => map.invalidateSize());
    }

    tryInit(params);

    return {
      update: tryInit,
      destroy() {
        destroyed = true;
        if (map) map.remove();
      }
    };
  }
</script>

<style>
  .forecast-carousel, .chronicle-carousel {
    cursor: grab;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .forecast-carousel::-webkit-scrollbar,
  .chronicle-carousel::-webkit-scrollbar {
    display: none;
  }
  .chronicle-carousel {
    display: flex;
    overflow-x: auto;
    scroll-snap-type: x mandatory;
    overscroll-behavior-x: contain;
  }
  .chronicle-slide {
    flex: 0 0 calc(100% - 44px);
    flex-shrink: 0;
    scroll-snap-align: start;
  }
  .card-text {
    transition: max-height 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }

</style>

```sql q_story
SELECT story_nm, CAST(geo_lat AS DOUBLE) AS geo_lat, CAST(geo_lon AS DOUBLE) AS geo_lon
FROM dwh_pg_1.b_stories
WHERE story_id = ${params.story}
  AND language_code = 'ru'
```

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
  AND story_id = ${params.story}
ORDER BY dt DESC
```

```sql q_forecasts
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecasts_posteriors
    WHERE language_code = 'ru' AND story_id = ${params.story}
    GROUP BY forecast_id
),
prev AS (
    SELECT b.forecast_id, b.p_posterior_prt AS p_prev
    FROM dwh_pg_1.b_forecasts_posteriors b
    JOIN latest l ON l.forecast_id = b.forecast_id
    WHERE b.language_code = 'ru'
      AND b.story_id = ${params.story}
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
WHERE b.language_code = 'ru' AND b.story_id = ${params.story}
ORDER BY b.p_posterior_prt DESC
```

```sql q_forecasts_history
SELECT forecast_id, published_dttm, p_posterior_prt
FROM dwh_pg_1.b_forecasts_posteriors
WHERE language_code = 'ru' AND story_id = ${params.story}
ORDER BY forecast_id, published_dttm
```

```sql q_news_by_day
SELECT
    CAST(published_dttm AS DATE) AS day,
    COUNT(*) AS cnt
FROM dwh_pg_1.b_unews_stories_texts
WHERE story_id = ${params.story}
  AND published_dttm >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1
ORDER BY 1
```

```sql q_day_images
SELECT day, image_url
FROM (
    SELECT
        strftime(published_dttm, '%Y-%m-%d') AS day,
        image_url,
        ROW_NUMBER() OVER (PARTITION BY strftime(published_dttm, '%Y-%m-%d') ORDER BY published_dttm DESC) AS rn
    FROM dwh_pg_1.b_news_stories_feeds
    WHERE story_id = ${params.story}
      AND image_url IS NOT NULL
      AND image_url != ''
) ranked
WHERE rn = 1
ORDER BY day
```

<div bind:this={pageEl}>

{#if q_story[0]}
# {q_story[0].story_nm}
{/if}

## Хроника событий

{#if q_stories_summaries.length > 0}
<div class="not-prose mt-4" style="margin:0 -12px">
  <div class="chronicle-carousel" use:dragScroll on:scroll={onChronicleScroll}
       bind:this={chronicleEl}>
    {#each visible as entry, i}
      {@const _p = entry.iso_dt.split('-')}
      {@const _day = parseInt(_p[2])}
      {@const _year = parseInt(_p[0])}
      {@const _mon = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][parseInt(_p[1])-1]}

      <div class="chronicle-slide"
           use:tappable
           on:tap={() => goto(`/stories/${params.story}/${entry.iso_dt}`)}>

        <!-- Дата -->
        <div style="padding:10px 0 6px 12px">
          <span style="font-size:12px; font-weight:500; color:#a8a29e">{_day} {_mon}{_year !== new Date().getFullYear() ? ' ' + _year : ''}</span>
        </div>

        <!-- Карточка -->
        <div class="rounded-xl border overflow-hidden"
             style="background:#faf9f7; border-color:#e7e5e4; margin:0 12px 12px 12px">
          <div class="px-4 py-3">

            {#if dayImages[entry.iso_dt] && !imgError[i]}
              <div class="-mx-4 -mt-3 mb-3">
                <div style="aspect-ratio:16/9; background:#f5f4f2">
                  <img src={absUrl(dayImages[entry.iso_dt])} alt="" loading="lazy"
                       on:error={() => { imgError[i] = true; imgError = imgError; }}
                       on:load={(e) => { if (e.target.naturalWidth < 300) { imgError[i] = true; imgError = imgError; } }}
                       class="w-full h-full object-cover"
                       style="filter:grayscale({slideGrayscale[i] ?? 1}); transition:filter 0.3s ease" />
                </div>
              </div>
            {:else if q_story[0] && Number.isFinite(+q_story[0].geo_lat)}
              <div class="-mx-4 -mt-3 mb-3 overflow-hidden" style="aspect-ratio:16/9; background:#f5f4f2; isolation:isolate">
                <div use:leafletMap={{ lat: +q_story[0].geo_lat, lon: +q_story[0].geo_lon, zoom: 5 }}
                     style="height:100%; width:100%; filter:grayscale({slideGrayscale[i] ?? 1}); transition:filter 0.3s ease"></div>
              </div>
            {/if}

            <p class="text-sm font-semibold leading-snug mb-2"
               style="color:#15140F; min-height:5.5em; {expanded[i] ? '' : 'display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:4; overflow:hidden'}"
               >{entry.headline_txt}</p>

            {#if entry.summary_txt}
              {#if expanded[i]}
                <div in:slide={{ duration: 320 }} out:slide={{ duration: 200 }}>
                  <p class="text-sm leading-relaxed mb-2" style="color:#57534e">{entry.summary_txt}</p>
                </div>
              {/if}
              <button type="button"
                class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none"
                style="color:#a8a29e; background:none; border:none; padding:0"
                on:pointerup|stopPropagation
                on:click|preventDefault|stopPropagation={() => { expanded[i] = !expanded[i]; expanded = expanded; }}>
                {expanded[i] ? 'Скрыть' : 'Показать полностью'}
                <span style="display:inline-flex; transform:rotate({expanded[i] ? '180deg' : '0deg'}); transition:transform 0.2s">
                  <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
                    <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                  </svg>
                </span>
              </button>
            {/if}

          </div>
        </div>

      </div>
    {/each}
  </div>

</div>
{:else}
<div class="not-prose mt-4 p-6 bg-amber-50 border border-amber-200 rounded-xl">
  <p class="text-amber-800 text-sm">Ежедневные сводки новостей для этого сюжета пока не сформированы.</p>
</div>
{/if}

{#if q_forecasts.length > 0}

## Прогноз на {q_forecasts[0].horizon_days} дней

<div class="forecast-carousel not-prose mt-2 mb-10" use:dragScroll
     style="display:flex; gap:12px; overflow-x:auto; scroll-snap-type:x proximity; padding-bottom:4px; user-select:none; -webkit-user-select:none; isolation:isolate">
  {#each q_forecasts as f}
    {@const delta = formatDelta(f.delta_pp)}
    <div class="rounded-xl border relative cursor-pointer"
         style="flex:0 0 78%; max-width:280px; scroll-snap-align:start; background:#faf9f7; border-color:#e7e5e4; overflow:clip;"
         use:tappable
         on:tap={() => {
           if (slidForecastId === f.forecast_id) {
             slidForecastId = null;
           } else {
             slidForecastId = f.forecast_id; openInfoId = null; openChartId = null;
           }
         }}>

      <!-- Скользящее содержимое -->
      <div class="px-4 py-3"
           style="transform:translateX({slidForecastId === f.forecast_id ? '-56px' : '0'}); transition:transform 0.25s cubic-bezier(0.4,0,0.2,1)">

        <p class="text-sm font-medium leading-snug mb-3" style="color:#15140F; min-height:2.6em">{f.forecast_nm}</p>

        <div class="flex items-center mb-3">
          <p class="text-3xl font-semibold tabular-nums" style="color:#15140F">{f.pct}%</p>
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

      <!-- Зона иконок — скользит из правого края -->
      <div class="absolute top-0 bottom-0 right-0 flex flex-col items-center justify-center gap-2"
           style="width:56px; transform:translateX({slidForecastId === f.forecast_id ? '0' : '100%'}); transition:transform 0.25s cubic-bezier(0.4,0,0.2,1)">

        <button type="button"
          use:tappable
          on:tap|stopPropagation={() => { openInfoId = openInfoId === f.forecast_id ? null : f.forecast_id; if (openInfoId) openChartId = null; slidForecastId = null; }}
          class="flex items-center justify-center rounded-full"
          style="width:36px; height:36px; border:1px solid #e7e5e4; background:#fafaf9; cursor:pointer; flex-shrink:0; color:{openInfoId === f.forecast_id ? '#57534e' : '#78716c'}">
          <svg width="18" height="18" viewBox="0 0 18 18" fill="currentColor">
            <circle cx="9" cy="4" r="1"/>
            <rect x="8" y="7" width="2" height="8.5" rx="1"/>
          </svg>
        </button>

        <button type="button"
          use:tappable
          on:tap|stopPropagation={() => { openChartId = openChartId === f.forecast_id ? null : f.forecast_id; if (openChartId) openInfoId = null; slidForecastId = null; }}
          class="flex items-center justify-center rounded-full"
          style="width:36px; height:36px; border:1px solid #e7e5e4; background:#fafaf9; cursor:pointer; flex-shrink:0; color:{openChartId === f.forecast_id ? '#57534e' : '#78716c'}">
          <svg width="18" height="18" viewBox="0 0 20 20" fill="currentColor">
            <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zm6-4a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zm6-3a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z"/>
          </svg>
        </button>

      </div>
    </div>
  {/each}
</div>

{/if}

## Карта событий

{#if q_story[0]}
<div class="not-prose mt-2 mb-10 rounded-xl border overflow-hidden" style="background:#ffffff; height:200px; border-color:#e7e5e4">
  <div use:leafletMap={{ lat: +q_story[0].geo_lat, lon: +q_story[0].geo_lon, zoom: 5 }} style="height:100%; width:100%"></div>
</div>
{/if}

<div class="not-prose mt-2 mb-10 rounded-xl border overflow-hidden" style="background:#faf9f7; border-color:#e7e5e4">
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

</div>

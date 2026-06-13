---
title: Сюжеты
full_width: false
---

<script>
  function relTime(dttm) {
    if (!dttm) return '';
    const diff = Date.now() - new Date(dttm).getTime();
    const min = Math.floor(diff / 60000);
    if (min < 2) return 'только что';
    if (min < 60) return `${min} мин. назад`;
    const h = Math.floor(min / 60);
    if (h < 24) return `${h} ч. назад`;
    const d = Math.floor(h / 24);
    return `${d} дн. назад`;
  }

  // Карусель: scroll-snap + drag мышью
  let activeSlide = {};
  let scrollers = {};
  let drag = {};

  function onScroll(e, id) {
    const el = e.currentTarget;
    const idx = Math.round(el.scrollLeft / el.clientWidth);
    activeSlide[id] = idx;
    activeSlide = activeSlide;
  }

  function goToSlide(id, idx) {
    const el = scrollers[id];
    if (!el) return;
    el.scrollTo({ left: idx * el.clientWidth, behavior: 'smooth' });
  }

  function onPointerDown(e, id) {
    if (e.pointerType !== 'mouse') return;
    const el = e.currentTarget;
    drag[id] = { down: true, startX: e.clientX, scrollStart: el.scrollLeft, moved: false };
    el.style.scrollSnapType = 'none';
    el.style.cursor = 'grabbing';
    el.setPointerCapture(e.pointerId);
    e.preventDefault();
  }

  function onPointerMove(e, id) {
    const d = drag[id];
    if (!d?.down) return;
    const dx = e.clientX - d.startX;
    if (Math.abs(dx) > 3) drag[id].moved = true;
    e.currentTarget.scrollLeft = d.scrollStart - dx;
  }

  function onPointerUp(e, id) {
    const d = drag[id];
    if (!d?.down) return;
    drag[id] = { ...d, down: false };
    e.currentTarget.style.scrollSnapType = 'x mandatory';
    e.currentTarget.style.cursor = '';
  }

  function onKeyActivate(e, fn) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      e.stopPropagation();
      fn();
    }
  }

  function pluralize(n, one, few, many) {
    const m10 = n % 10, m100 = n % 100;
    if (m10 === 1 && m100 !== 11) return `${n} ${one}`;
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return `${n} ${few}`;
    return `${n} ${many}`;
  }

  // Усечение блока с последними событиями до 2 строк + кнопка "Показать полностью"/"Скрыть"
  let truncated  = {};
  let expanded   = {};
  let fullHeight = {};

  function clampDetect(node, uid) {
    const measure = () => {
      const lh = parseFloat(getComputedStyle(node).lineHeight) || 20;
      fullHeight[uid] = node.scrollHeight;
      const isTrunc = node.scrollHeight > lh * 2 + 4;
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

  // Карточка ленты: первый клик подсвечивает рамкой (как выбор у карточек
  // прогноза на странице сюжета), второй клик переходит на страницу сюжета.
  let selectedCard = null;

  $: enriched = q_stories.map(s => {
    const headline = q_latest_headlines.find(r => +r.story_id === s.story_id) || null;
    const upd      = q_last_update.find(r => +r.story_id === s.story_id) || null;
    const activity = q_activity.filter(r => +r.story_id === s.story_id);
    const forecast = q_top_forecast.find(r => +r.story_id === s.story_id) || null;
    const total30  = activity.reduce((sum, r) => sum + +r.cnt, 0);
    return { ...s, headline, upd, activity, forecast, total30 };
  }).sort((a, b) => {
    const ta = a.upd ? new Date(a.upd.last_dttm).getTime() : 0;
    const tb = b.upd ? new Date(b.upd.last_dttm).getTime() : 0;
    if (tb !== ta) return tb - ta;
    return b.total30 - a.total30;
  });

  // Миникарта региона — карточки рендерятся асинхронно (данные из БД),
  // поэтому карту инициализируем через use:-action на момент появления
  // самого элемента, а не через onMount + querySelectorAll.
  function leafletMap(node, { lat, lon, zoom }) {
    let map;
    let destroyed = false;

    (async () => {
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

      // CartoDB Light — чистые тайлы без яркой цветовой нагрузки
      L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
        subdomains: 'abcd',
        maxZoom: 19,
      }).addTo(map);

      // Маркер точкой в стиле сайта
      L.circleMarker([lat, lon], {
        radius:      7,
        fillColor:   '#57534e',
        color:       '#ffffff',
        weight:      2.5,
        opacity:     1,
        fillOpacity: 1,
      }).addTo(map);

      requestAnimationFrame(() => map.invalidateSize());
    })();

    return {
      destroy() {
        destroyed = true;
        if (map) map.remove();
      }
    };
  }
</script>

<style>
  .story-slide {
    transition: filter 0.35s ease;
  }
  .story-slide:hover {
    filter: brightness(1.04);
  }
  .carousel-scroll {
    cursor: grab;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .carousel-scroll::-webkit-scrollbar {
    display: none;
  }
  .card-text {
    transition: max-height 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .story-card {
    border-color: transparent;
  }
  .story-card:hover,
  .story-card.story-card-selected {
    border-color: #d6d3d1;
  }
</style>

```sql q_stories
SELECT story_id, story_nm, geo_lat, geo_lon
FROM dwh_pg_1.b_stories
WHERE language_code = 'ru'
```

```sql q_latest_headlines
SELECT story_id, dt, headline_txt, summary_txt
FROM dwh_pg_1.stories_summaries_d
WHERE language_code = 'ru'
QUALIFY row_number() OVER (PARTITION BY story_id ORDER BY dt DESC) = 1
```

```sql q_last_update
SELECT story_id, MAX(published_dttm) AS last_dttm
FROM dwh_pg_1.b_unews_stories_texts
GROUP BY 1
```

```sql q_activity
SELECT story_id, CAST(published_dttm AS DATE) AS day, COUNT(*) AS cnt
FROM dwh_pg_1.b_unews_stories_texts
WHERE published_dttm >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1, 2
```

```sql q_top_forecast
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecasts_posteriors
    WHERE language_code = 'ru'
    GROUP BY forecast_id
)
SELECT b.story_id, b.forecast_nm, CAST(ROUND(b.p_posterior_prt * 100) AS INTEGER) AS pct
FROM dwh_pg_1.b_forecasts_posteriors b
JOIN latest l ON l.forecast_id = b.forecast_id AND l.dttm = b.published_dttm
WHERE b.language_code = 'ru'
QUALIFY row_number() OVER (PARTITION BY b.story_id ORDER BY b.p_posterior_prt DESC) = 1
```

{#each enriched as story}
{@const total = 1}
{@const slide = activeSlide[story.story_id] || 0}
<a href="/stories/{story.story_id}"
   class="story-card not-prose block rounded-xl mb-4 border transition-colors overflow-hidden"
   class:story-card-selected={selectedCard === story.story_id}
   style="background:#faf9f7"
   on:click={(e) => {
     if (drag[story.story_id]?.moved) { e.preventDefault(); drag[story.story_id] = {...drag[story.story_id], moved: false}; return; }
     if (selectedCard !== story.story_id) { e.preventDefault(); selectedCard = story.story_id; }
   }}>

  <!-- Заголовок -->
  <div class="px-5 pt-4 pb-3">
    <p class="text-base font-semibold leading-snug" style="color:#15140F">{story.story_nm}</p>
  </div>

  <!-- Карусель: карта региона + фотографии -->
  <div class="relative" style="height:140px; background:#f0ede8; overflow:hidden">

    <!-- Скролл-контейнер (scroll-snap + drag мышью) -->
    <div class="carousel-scroll flex h-full"
         style="overflow-x:auto; scroll-snap-type:x mandatory"
         bind:this={scrollers[story.story_id]}
         on:scroll={(e) => onScroll(e, story.story_id)}
         on:pointerdown={(e) => onPointerDown(e, story.story_id)}
         on:pointermove={(e) => onPointerMove(e, story.story_id)}
         on:pointerup={(e) => onPointerUp(e, story.story_id)}
         on:pointerleave={(e) => onPointerUp(e, story.story_id)}>

      <!-- Слайд 0: миникарта (Leaflet) -->
      <div class="flex-shrink-0 h-full" style="width:100%; scroll-snap-align:start">
        <div
          use:leafletMap={{ lat: +story.geo_lat, lon: +story.geo_lon, zoom: 5 }}
          style="height:100%; width:100%">
        </div>
      </div>
    </div>

    {#if total > 1}
      <!-- Стрелка влево -->
      <div class="absolute left-0 top-0 bottom-0 flex items-center justify-center select-none cursor-pointer"
           style="width:36px; z-index:500"
           role="button" tabindex="0"
           on:click|preventDefault|stopPropagation={() => goToSlide(story.story_id, (slide - 1 + total) % total)}
           on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.story_id, (slide - 1 + total) % total))}
           aria-label="Предыдущий слайд">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#57534e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 2L4 7L9 12"/>
        </svg>
      </div>

      <!-- Стрелка вправо -->
      <div class="absolute right-0 top-0 bottom-0 flex items-center justify-center select-none cursor-pointer"
           style="width:36px; z-index:500"
           role="button" tabindex="0"
           on:click|preventDefault|stopPropagation={() => goToSlide(story.story_id, (slide + 1) % total)}
           on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.story_id, (slide + 1) % total))}
           aria-label="Следующий слайд">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#57534e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M5 2L10 7L5 12"/>
        </svg>
      </div>

      <!-- Точки-индикаторы -->
      <div class="absolute bottom-2.5 inset-x-0 flex items-center justify-center gap-1.5" style="z-index:1000">
        {#each Array(total) as _, i}
          <div role="button" tabindex="0"
               class="rounded-full select-none cursor-pointer"
               style="width:5px; height:5px; background:{slide === i ? '#ffffff' : 'rgba(255,255,255,0.55)'}; transition:background 0.2s ease"
               on:click|preventDefault|stopPropagation={() => goToSlide(story.story_id, i)}
               on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.story_id, i))}
               aria-label="Слайд {i + 1}"></div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Контент карточки -->
  <div class="px-5 py-4">
    {#if story.headline}
      <p class="text-sm font-medium leading-snug mb-2" style="color:#15140F">{story.headline.headline_txt}</p>
      {#if story.headline.summary_txt}
        <p use:clampDetect={story.story_id}
           class="card-text text-sm leading-relaxed overflow-hidden mb-1"
           style="color:#57534e; max-height:{expanded[story.story_id] ? (fullHeight[story.story_id] ? fullHeight[story.story_id] + 'px' : '600px') : truncated[story.story_id] === false ? 'none' : '3.3em'}; display:-webkit-box; -webkit-box-orient:vertical; line-clamp:{expanded[story.story_id] ? 'none' : 2}; -webkit-line-clamp:{expanded[story.story_id] ? 'none' : 2};"
           >{story.headline.summary_txt}</p>
        {#if truncated[story.story_id]}
          <button type="button"
            class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none transition-colors"
            style="color:#a8a29e; background:none; border:none; padding:0"
            onmouseover="this.style.color='#57534e'" onmouseout="this.style.color='#a8a29e'"
            on:click|preventDefault|stopPropagation={() => { expanded[story.story_id] = !expanded[story.story_id]; expanded = expanded; }}>
            {expanded[story.story_id] ? 'Скрыть' : 'Показать полностью'}
            <span style="display:inline-flex; transform:rotate({expanded[story.story_id] ? '180deg' : '0deg'}); transition:transform 0.2s">
              <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
                <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </span>
          </button>
        {/if}
      {/if}
    {/if}

    <div class="flex items-center gap-3 mt-3 pt-3 flex-wrap" style="border-top:1px solid #f0ede9">
      {#if story.forecast}
        <span class="text-xs" style="color:#57534e">{story.forecast.forecast_nm} · {story.forecast.pct}%</span>
      {/if}
      {#if story.total30 > 0}
        <span class="text-xs" style="color:#a8a29e">{pluralize(story.total30, 'материал', 'материала', 'материалов')} за 30 дней</span>
      {/if}
      {#if story.upd}
        <span class="text-xs" style="color:#c4bca9">обновлено {relTime(story.upd.last_dttm)}</span>
      {/if}
    </div>
  </div>

</a>
{/each}
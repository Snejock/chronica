---
title: Сюжеты
full_width: false
---

<script>
  const stories = [
    {
      id: 1, slug: 'persian-gulf-escalation',
      category: 'Ближний Восток',
      title: 'Эскалация в Персидском заливе',
      lat: 26, lon: 56, zoom: 5, photoCount: 2,
    },
    {
      id: 2, slug: 'russian-ukrainian-conflict',
      category: 'Восточная Европа',
      title: 'Конфликт России и Украины',
      lat: 49, lon: 32, zoom: 5, photoCount: 2,
    },
  ];

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

  $: enriched = stories.map(s => {
    const headline = q_latest_headlines.find(r => +r.story_id === s.id) || null;
    const upd      = q_last_update.find(r => +r.story_id === s.id) || null;
    const activity = q_activity.filter(r => +r.story_id === s.id);
    const forecast = q_top_forecast.find(r => +r.story_id === s.id) || null;
    const total30  = activity.reduce((sum, r) => sum + +r.cnt, 0);
    return { ...s, headline, upd, activity, forecast, total30 };
  }).sort((a, b) => {
    const ta = a.upd ? new Date(a.upd.last_dttm).getTime() : 0;
    const tb = b.upd ? new Date(b.upd.last_dttm).getTime() : 0;
    if (tb !== ta) return tb - ta;
    return b.total30 - a.total30;
  });

  onMount(async () => {
    // Загружаем Leaflet CSS
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
    });
  });
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
</style>

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
{@const total = (story.photoCount || 0) + 1}
{@const slide = activeSlide[story.id] || 0}
<a href="/stories/{story.slug}"
   class="not-prose block rounded-xl mb-4 border transition-colors overflow-hidden"
   style="background:#faf9f7; border-color:transparent"
   onmouseover="this.style.borderColor='#d6d3d1'" onmouseout="this.style.borderColor='transparent'"
   on:click={(e) => { if (drag[story.id]?.moved) { e.preventDefault(); drag[story.id] = {...drag[story.id], moved: false}; } }}>

  <!-- Заголовок -->
  <div class="px-5 pt-4 pb-3">
    <p class="text-base font-semibold leading-snug" style="color:#15140F">{story.title}</p>
  </div>

  <!-- Карусель: карта региона + фотографии -->
  <div class="relative" style="height:140px; background:#f0ede8; overflow:hidden">

    <!-- Скролл-контейнер (scroll-snap + drag мышью) -->
    <div class="carousel-scroll flex h-full"
         style="overflow-x:auto; scroll-snap-type:x mandatory"
         bind:this={scrollers[story.id]}
         on:scroll={(e) => onScroll(e, story.id)}
         on:pointerdown={(e) => onPointerDown(e, story.id)}
         on:pointermove={(e) => onPointerMove(e, story.id)}
         on:pointerup={(e) => onPointerUp(e, story.id)}
         on:pointerleave={(e) => onPointerUp(e, story.id)}>

      <!-- Слайд 0: миникарта (Leaflet) -->
      <div class="flex-shrink-0 h-full" style="width:100%; scroll-snap-align:start">
        <div
          data-leaflet-map=""
          data-lat="{story.lat}"
          data-lon="{story.lon}"
          data-zoom="{story.zoom}"
          style="height:100%; width:100%">
        </div>
      </div>

      <!-- Слайды-заглушки под фотографии: яркий фон, чтобы было видно глассморфизм -->
      {#each Array(story.photoCount || 0) as _, i}
        <div class="story-slide flex-shrink-0 h-full flex items-center justify-center"
             style="width:100%; scroll-snap-align:start; background:{i % 2 === 0 ? 'linear-gradient(135deg, #e3b07a 0%, #a9683f 100%)' : 'linear-gradient(135deg, #93b6c7 0%, #4f7689 100%)'}">
          <!-- Стеклянная карточка поверх фона -->
          <div class="flex flex-col items-center gap-1.5 px-5 py-3 rounded-xl"
               style="background:rgba(255,255,255,0.16); backdrop-filter:blur(12px); -webkit-backdrop-filter:blur(12px); border:1px solid rgba(255,255,255,0.35); box-shadow:0 6px 20px rgba(0,0,0,0.12)">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="opacity:0.9">
              <rect x="3" y="3" width="18" height="18" rx="2"/>
              <circle cx="8.5" cy="8.5" r="1.5"/>
              <path d="M21 15l-5-5L5 21"/>
            </svg>
            <span class="text-xs font-medium" style="color:#ffffff">Фотография {i + 1}</span>
          </div>
        </div>
      {/each}
    </div>

    <!-- Бейдж категории поверх карусели -->
    <div class="absolute top-3 left-4 pointer-events-none" style="z-index:1000">
      <span class="text-xs font-medium uppercase tracking-wide px-2 py-0.5 rounded-full"
            style="background:rgba(250,249,247,0.55); backdrop-filter:blur(8px); -webkit-backdrop-filter:blur(8px); border:1px solid rgba(255,255,255,0.4); color:#57534e; letter-spacing:0.06em">{story.category}</span>
    </div>

    {#if total > 1}
      <!-- Стрелка влево -->
      <div class="absolute left-0 top-0 bottom-0 flex items-center justify-center select-none cursor-pointer"
           style="width:36px; z-index:500"
           role="button" tabindex="0"
           on:click|preventDefault|stopPropagation={() => goToSlide(story.id, (slide - 1 + total) % total)}
           on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.id, (slide - 1 + total) % total))}
           aria-label="Предыдущий слайд">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#57534e" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 2L4 7L9 12"/>
        </svg>
      </div>

      <!-- Стрелка вправо -->
      <div class="absolute right-0 top-0 bottom-0 flex items-center justify-center select-none cursor-pointer"
           style="width:36px; z-index:500"
           role="button" tabindex="0"
           on:click|preventDefault|stopPropagation={() => goToSlide(story.id, (slide + 1) % total)}
           on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.id, (slide + 1) % total))}
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
               on:click|preventDefault|stopPropagation={() => goToSlide(story.id, i)}
               on:keydown={(e) => onKeyActivate(e, () => goToSlide(story.id, i))}
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
        <p class="text-xs leading-relaxed" style="color:#57534e">{story.headline.summary_txt}</p>
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
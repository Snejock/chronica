---
full_width: false
hide_breadcrumbs: true
---

<script>
  function absUrl(url) {
    if (!url) return url;
    return /^https?:\/\//i.test(url) ? url : 'https://' + url;
  }

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

  // Читаем ?category= напрямую из window.location, а не через $page — страница
  // пререндерится статически (evidence build = SvelteKit prerender), а во время
  // пререндера window недоступен, так что на сервере activeCategory просто останется
  // null и подставится дефолтная категория ниже.
  let activeCategory = typeof window !== 'undefined'
    ? new URLSearchParams(window.location.search).get('category')
    : null;

  let pageEl;

  onMount(() => {
    function rubberBand(x, max = 80) {
      return max * (1 - 1 / (x * 0.55 / max + 1));
    }

    let hitY = null, applied = 0, edge = null;
    let startX = null, startY = null, axis = null;

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

      if (axis === null && startX !== null) {
        const dx = Math.abs(tx - startX);
        const dy = Math.abs(ty - startY);
        if (dx > 6 || dy > 6) axis = dx > dy ? 'h' : 'v';
      }
      if (axis === 'h') return;

      const atTop = isTop(), atBottom = isBottom();

      if (atTop && atBottom) {
        if (edge === null) {
          const dy = ty - startY;
          if (dy > 6) { edge = 'top'; hitY = ty; }
          else if (dy < -6) { edge = 'bottom'; hitY = ty; }
          else return;
        }
      } else if (atTop && !atBottom) {
        if (edge !== 'top') { edge = 'top'; hitY = ty; }
      } else if (atBottom && !atTop) {
        if (edge !== 'bottom') { edge = 'bottom'; hitY = ty; }
      } else {
        if (applied > 0) { applied = 0; pageEl.style.transform = ''; }
        hitY = null; edge = null;
        return;
      }

      if (edge === 'bottom') {
        const over = hitY - ty;
        if (over > 0) {
          applied = rubberBand(over);
          pageEl.style.transform = `translateY(${-applied}px)`;
          e.preventDefault();
        } else if (applied > 0) { applied = 0; pageEl.style.transform = ''; }
      } else if (edge === 'top') {
        const over = ty - hitY;
        if (over > 0) {
          applied = rubberBand(over);
          pageEl.style.transform = `translateY(${applied}px)`;
          e.preventDefault();
        } else if (applied > 0) { applied = 0; pageEl.style.transform = ''; }
      }
    }

    function onTouchEnd() { reset(true); }

    document.addEventListener('touchstart', onTouchStart, { passive: true });
    document.addEventListener('touchmove',  onTouchMove,  { passive: false });
    document.addEventListener('touchend',   onTouchEnd);
    document.addEventListener('touchcancel', onTouchEnd);

    return () => {
      document.removeEventListener('touchstart', onTouchStart);
      document.removeEventListener('touchmove',  onTouchMove);
      document.removeEventListener('touchend',   onTouchEnd);
      document.removeEventListener('touchcancel', onTouchEnd);
    };
  });

  $: enriched = q_stories.map(s => {
    const headline = q_latest_headlines.find(r => +r.story_id === s.story_id) || null;
    const upd      = q_last_update.find(r => +r.story_id === s.story_id) || null;
    const activity = q_activity.filter(r => +r.story_id === s.story_id);
    const forecast = q_top_forecast.find(r => +r.story_id === s.story_id) || null;
    const total30  = activity.reduce((sum, r) => sum + +r.cnt, 0);
    const images   = q_story_images.filter(r => +r.story_id === s.story_id).map(r => r.image_url);
    return { ...s, headline, upd, activity, forecast, total30, images };
  }).sort((a, b) => {
    const ta = a.upd ? new Date(a.upd.last_dttm).getTime() : 0;
    const tb = b.upd ? new Date(b.upd.last_dttm).getTime() : 0;
    if (tb !== ta) return tb - ta;
    return b.total30 - a.total30;
  });

  $: categories = q_categories.filter(c => enriched.some(s => s.category_nm === c.category_nm));
  $: if (categories.length > 0 && !categories.some(c => c.category_nm === activeCategory)) {
    activeCategory = categories[0].category_nm;
  }
  $: visible = enriched.filter(s => s.category_nm === activeCategory);

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
    border-color: #e7e5e4;
  }
</style>

```sql q_stories
SELECT story_id, story_nm, geo_lat, geo_lon, category_nm
FROM dwh_pg_1.b_stories
WHERE language_code = 'ru'
```

```sql q_categories
SELECT category_nm, label_nm, sort_order_idx
FROM dwh_pg_1.b_story_categories
WHERE language_code = 'ru'
ORDER BY sort_order_idx
```

```sql q_latest_headlines
SELECT story_id, dt, headline_txt, summary_txt
FROM dwh_pg_1.story_summaries_d
WHERE language_code = 'ru'
QUALIFY row_number() OVER (PARTITION BY story_id ORDER BY dt DESC) = 1
```

```sql q_last_update
SELECT story_id, MAX(published_dttm) AS last_dttm
FROM dwh_pg_1.b_story_unews_texts
GROUP BY 1
```

```sql q_activity
SELECT story_id, CAST(published_dttm AS DATE) AS day, COUNT(*) AS cnt
FROM dwh_pg_1.b_story_unews_texts
WHERE published_dttm >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY 1, 2
ORDER BY 1, 2
```

```sql q_story_images
SELECT story_id, image_url
FROM (
    SELECT
        story_id,
        image_url,
        ROW_NUMBER() OVER (PARTITION BY story_id ORDER BY published_dttm DESC) AS rn
    FROM dwh_pg_1.b_story_feed_news
    WHERE image_url IS NOT NULL AND image_url != ''
) t
WHERE rn <= 5
ORDER BY story_id, rn
```

```sql q_top_forecast
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecast_posteriors
    WHERE language_code = 'ru'
    GROUP BY forecast_id
)
SELECT b.story_id, b.forecast_nm, CAST(ROUND(b.p_posterior_prt * 100) AS INTEGER) AS pct
FROM dwh_pg_1.b_forecast_posteriors b
JOIN latest l ON l.forecast_id = b.forecast_id AND l.dttm = b.published_dttm
WHERE b.language_code = 'ru'
QUALIFY row_number() OVER (PARTITION BY b.story_id ORDER BY b.p_posterior_prt DESC) = 1
```

<div bind:this={pageEl}>

# Сюжеты

<div class="not-prose flex gap-2 mb-5">
  {#each categories as cat}
    <button
      class="px-3.5 py-1.5 rounded-full text-xs font-medium transition-colors"
      style="background:{activeCategory === cat.category_nm ? '#C0401C' : '#f0ede8'}; color:{activeCategory === cat.category_nm ? '#F1EADB' : '#57534e'}"
      on:click={() => activeCategory = cat.category_nm}>
      {cat.label_nm}
    </button>
  {/each}
</div>

{#each visible as story, storyIdx}
{@const total = story.images.length}
{@const slide = activeSlide[story.story_id] || 0}
<a href="/stories/{story.story_id}"
   class="story-card not-prose block rounded-xl mb-4 border transition-colors overflow-hidden"
   style="background:#ffffff"
   on:click={(e) => {
     if (drag[story.story_id]?.moved) { e.preventDefault(); drag[story.story_id] = {...drag[story.story_id], moved: false}; }
   }}>

  <!-- Карусель: последние фотографии (первая, до верха карточки) -->
  {#if total > 0}
  <div class="relative" style="height:180px; background:#f0ede8; overflow:hidden; isolation:isolate">

    <!-- Скролл-контейнер (scroll-snap + drag мышью) -->
    <div class="carousel-scroll flex h-full"
         style="overflow-x:auto; scroll-snap-type:x mandatory"
         bind:this={scrollers[story.story_id]}
         on:scroll={(e) => onScroll(e, story.story_id)}
         on:pointerdown={(e) => onPointerDown(e, story.story_id)}
         on:pointermove={(e) => onPointerMove(e, story.story_id)}
         on:pointerup={(e) => onPointerUp(e, story.story_id)}
         on:pointerleave={(e) => onPointerUp(e, story.story_id)}>

      {#each story.images as imgUrl}
        <div class="story-slide flex-shrink-0 h-full" style="width:100%; scroll-snap-align:start">
          <img src={absUrl(imgUrl)} alt="" loading="lazy" class="w-full h-full object-cover" />
        </div>
      {/each}
    </div>

    {#if total > 1}
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
  {/if}

  <!-- Контент карточки: название → хедлайн → статистика -->
  <div class="px-4 pt-3 pb-3">
    <p class="text-base font-semibold leading-snug mb-2" style="color:#15140F">{story.story_nm}</p>
    {#if story.headline}
      <p class="text-sm leading-snug mb-0" style="color:#57534e">{story.headline.headline_txt}</p>
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

</div>
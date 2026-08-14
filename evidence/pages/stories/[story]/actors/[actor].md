---
full_width: false
hide_breadcrumbs: true
---

<script>
  import { getContext as _getCtx } from 'svelte';
  import { slide } from 'svelte/transition';
  const breadcrumb = _getCtx('breadcrumb');
  $: if (q_story_name?.[0]?.story_nm) {
    breadcrumb?.set({ storyName: q_story_name[0].story_nm, actorName: q_actor?.[0]?.canonical_nm });
  }

  // Фото лежит в MinIO как путь без хоста (см. dds.s_actor_media.photo_link) -- достраиваем
  // публичным доменом (реверс-прокси -> 192.168.1.15:39200, TLS выпущен на этот хост).
  const MEDIA_BASE = 'https://media.chronica.life';
  function mediaUrl(path) {
    if (!path) return null;
    return MEDIA_BASE + path;
  }
  let heroImgError = false;
  let showPhotoCredit = false;

  function initials(nm) {
    if (!nm) return '';
    const parts = nm.trim().split(/\s+/);
    return parts.slice(0, 2).map(p => p[0]).join('').toUpperCase();
  }

  const MONTHS_SHORT = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
  function fmtDate(dttm) {
    const d = new Date(dttm);
    return `${d.getDate()} ${MONTHS_SHORT[d.getMonth()]}`;
  }

  // Лента актёра, в отличие от ленты одного дня, может растягиваться на недели —
  // поэтому дате нужен собственный, более заметный уровень группировки (см. ниже
  // groupedByDay). Для ближних дат — относительная подпись "Сегодня"/"Вчера",
  // как в мессенджерах; для остальных — компактная "5 авг" (+год, если не текущий).
  function formatDayLabel(d) {
    const now = new Date();
    const startOfDay = (x) => new Date(x.getFullYear(), x.getMonth(), x.getDate());
    const diffDays = Math.round((startOfDay(now) - startOfDay(d)) / 86400000);
    if (diffDays === 0) return 'Сегодня';
    if (diffDays === 1) return 'Вчера';
    const label = `${d.getDate()} ${MONTHS_SHORT[d.getMonth()]}`;
    return d.getFullYear() !== now.getFullYear() ? `${label} ${d.getFullYear()}` : label;
  }

  function getTimeOfDay(dttm) {
    const h = new Date(dttm).getHours();
    if (h < 6)  return 'Ночь';
    if (h < 12) return 'Утро';
    if (h < 18) return 'День';
    return 'Вечер';
  }

  function absUrl(url) {
    if (!url) return url;
    return /^https?:\/\//i.test(url) ? url : 'https://' + url;
  }

  function flag(cc) {
    if (!cc || !/^[A-Za-z]{2}$/.test(cc)) return '';
    const offset = 127397;
    return [...cc.toUpperCase()].map(c => String.fromCodePoint(c.charCodeAt(0) + offset)).join('');
  }

  function domain(url) {
    try { return new URL(absUrl(url)).hostname.replace(/^www\./, ''); } catch(e) { return ''; }
  }

  function pluralize(n, one, few, many) {
    const m10 = n % 10, m100 = n % 100;
    if (m10 === 1 && m100 !== 11) return `${n} ${one}`;
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return `${n} ${few}`;
    return `${n} ${many}`;
  }

  let activeCountry = null;
  let activeFeed = null;
  let openFilter = null;

  let truncated  = {};
  let expanded   = {};
  let hovered    = {};
  let fullHeight = {};
  let imgError   = {};
  let slidUid    = null;

  function clampDetect(node, uid) {
    const measure = () => {
      const lh = parseFloat(getComputedStyle(node).lineHeight) || 20;
      fullHeight[uid] = node.scrollHeight;
      const isTrunc = node.scrollHeight > lh * 3 + 4;
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

  $: actorRow = q_actor?.[0];

  // отдельная витрина цитат, вне фильтров ленты публикаций (страна/источник) --
  // это самостоятельный раздел, а не производная от отфильтрованной ленты
  $: quotes = q_news_feed
    .filter(i => i.quote_txt)
    .map((item, idx) => ({ ...item, uid: idx }));

  $: countries = [...new Set(q_news_feed.filter(i => i.country_code).map(i => i.country_code))].sort();
  $: feeds = [...new Set(q_news_feed.map(i => i.feed_nm))].sort();

  $: filtered = q_news_feed
    .map((item, idx) => ({ ...item, uid: idx }))
    .filter(item => {
      if (activeCountry && item.country_code !== activeCountry) return false;
      if (activeFeed && item.feed_nm !== activeFeed) return false;
      return true;
    });

  // Двухуровневая группировка: сначала по календарному дню (публикации актёра
  // могут растягиваться на недели), внутри дня — как раньше, по времени суток.
  // `filtered` уже отсортирован по published_dttm DESC (SQL), порядок первого
  // появления дня при обходе даёт корректный порядок дней по убыванию.
  $: groupedByDay = (() => {
    const todOrder = ['Вечер', 'День', 'Утро', 'Ночь'];
    const dayKeys = [];
    const days = {};
    for (const item of filtered) {
      const d = new Date(item.published_dttm);
      const dayKey = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
      if (!days[dayKey]) { days[dayKey] = { date: d, items: [] }; dayKeys.push(dayKey); }
      days[dayKey].items.push(item);
    }
    return dayKeys.map(dayKey => {
      const day = days[dayKey];
      const todGroups = {};
      for (const item of day.items) {
        const tod = getTimeOfDay(item.published_dttm);
        if (!todGroups[tod]) todGroups[tod] = [];
        todGroups[tod].push(item);
      }
      return {
        dayKey,
        dayLabel: formatDayLabel(day.date),
        groups: todOrder.filter(k => todGroups[k]).map(k => ({ label: k, items: todGroups[k] })),
      };
    });
  })();

  $: stats = {
    total: filtered.length,
    feedCount: new Set(filtered.map(i => i.feed_nm)).size,
  };

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

</script>

<style>
  .card-text {
    transition: max-height 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .expand-btn { -webkit-tap-highlight-color: transparent; }
  .expand-btn:active { color: #a8a29e !important; }
</style>

```sql q_story_name
SELECT story_nm FROM dwh_pg_1.b_stories
WHERE story_id = ${params.story} AND language_code = 'ru'
```

```sql q_actor
SELECT actor_id, canonical_nm, description_txt, source_link,
       photo_link, author_nm, license_nm,
       mentions_cnt, first_dttm, last_dttm
FROM dwh_pg_1.b_story_actors
WHERE story_id = ${params.story}
  AND language_code = 'ru'
  AND actor_id = '${params.actor}'
```

```sql q_news_feed
SELECT
    published_dttm
    , news_link
    , feed_nm
    , feed_type
    , country_code
    , city_nm
    , title_txt
    , summary_txt
    , image_url
    , quote_txt
FROM dwh_pg_1.b_story_news_actors
WHERE story_id = ${params.story}
  AND actor_id = '${params.actor}'
ORDER BY published_dttm DESC
```

<div bind:this={pageEl} on:click={() => { if (showPhotoCredit) showPhotoCredit = false; }}>

{#if actorRow}

# {actorRow.canonical_nm}

<div class="not-prose mb-6" style="display:flex; gap:16px; align-items:flex-start">
  <div style="position:relative; flex-shrink:0; isolation:isolate">
    {#if mediaUrl(actorRow.photo_link) && !heroImgError}
      <img src={mediaUrl(actorRow.photo_link)} alt="" loading="lazy"
           on:error={() => heroImgError = true}
           on:load={(e) => { if (e.target.naturalWidth < 80) heroImgError = true; }}
           style="width:88px; height:88px; border-radius:50%; object-fit:cover; object-position:var(--actor-avatar-focus); display:block; background:#f0ede8" />
    {:else}
      <div style="width:88px; height:88px; border-radius:50%; display:flex; align-items:center; justify-content:center; background:#f0ede8; color:#a8a29e; font-size:26px; font-weight:600">{initials(actorRow.canonical_nm)}</div>
    {/if}
    <!-- Атрибуция фото (автор/лицензия) для CC BY / CC BY-SA не обязана висеть
         прямо рядом с изображением текстом -- достаточно, чтобы она была явно
         привязана к конкретному фото и легко находилась; значок-поповер на самом
         фото (как на Wikipedia) это обеспечивает, не занимая место в шапке. -->
    {#if actorRow.photo_link && actorRow.author_nm}
      <button type="button"
        on:click|stopPropagation={() => showPhotoCredit = !showPhotoCredit}
        aria-label="Атрибуция фото"
        class="flex items-center justify-center"
        style="position:absolute; bottom:-2px; right:-2px; width:22px; height:22px; border-radius:50%;
               background:#57534e; color:#faf9f7; border:2px solid #faf9f7; font-size:12px; font-weight:600;
               line-height:1; cursor:pointer; z-index:1">
        ⓘ
      </button>
      {#if showPhotoCredit}
        <div transition:slide|local={{ duration: 160 }}
             on:click|stopPropagation
             class="rounded-xl border overflow-hidden"
             style="position:absolute; top:100%; left:0; margin-top:6px; min-width:160px; max-width:220px;
                    background:#faf9f7; border-color:#e7e5e4; box-shadow:0 8px 20px rgba(0,0,0,0.14);
                    z-index:var(--z-popover)">
          <p class="text-xs" style="color:#57534e; padding:8px 10px">
            фото: {actorRow.author_nm}{#if actorRow.license_nm} · {actorRow.license_nm}{/if}
          </p>
        </div>
      {/if}
    {/if}
  </div>
  <div style="flex:1; min-width:0; padding-top:2px">
    {#if actorRow.description_txt}
      <p class="text-sm leading-relaxed mb-2" style="color:#57534e">{actorRow.description_txt}</p>
    {/if}
    {#if actorRow.source_link}
      <a href={absUrl(actorRow.source_link)} target="_blank" rel="noopener" class="text-xs font-medium" style="color:#C0401C">Wikipedia →</a>
    {/if}
  </div>
</div>

{#if quotes.length > 0}
## Цитаты

<div class="not-prose flex flex-col gap-3 mb-6">
  {#each quotes as q (q.uid)}
    <div class="rounded-xl border px-4 py-3" style="background:#faf9f7; border-color:#e7e5e4">
      <p class="text-sm leading-relaxed" style="color:#15140F">«{q.quote_txt}»</p>
      <p class="text-xs mt-2 flex items-center gap-1 flex-wrap" style="color:#a8a29e">
        {fmtDate(q.published_dttm)}&nbsp;·&nbsp;{q.feed_nm}
        {#if q.news_link}
          &nbsp;·&nbsp;<a href={absUrl(q.news_link)} target="_blank" rel="noopener" class="font-medium" style="color:#C0401C">Источник →</a>
        {/if}
      </p>
    </div>
  {/each}
</div>
{/if}

## Публикации

{#if q_news_feed.length > 0}

<!-- Шапка со статистикой -->
<p class="text-sm mb-4" style="color:#a8a29e">
  {pluralize(stats.total, 'материал', 'материала', 'материалов')}
  &nbsp;·&nbsp;{pluralize(stats.feedCount, 'источник', 'источника', 'источников')}
</p>

<!-- Фильтры -->
{#if countries.length >= 2 || feeds.length >= 2}

{#if openFilter}
  <div class="not-prose fixed inset-0" style="z-index:var(--z-scrim)" on:click={() => openFilter = null} aria-hidden="true"></div>
{/if}

<div class="not-prose flex gap-2 mb-5" style="position:relative; z-index:{openFilter ? 'var(--z-popover)' : 'var(--z-content-raised)'}">

  {#if countries.length >= 2}
  <div style="position:relative">
    <button type="button"
      on:click|stopPropagation={() => openFilter = openFilter === 'country' ? null : 'country'}
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border cursor-pointer transition-colors"
      style={activeCountry ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#57534e; border-color:#e7e5e4; background:#fafaf9;'}>
      {activeCountry ? `${flag(activeCountry) || activeCountry} ${activeCountry}` : 'Страна'}
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"
           style="transition:transform 0.2s; transform:rotate({openFilter === 'country' ? '180deg' : '0deg'})">
        <path d="M2 4l4 4 4-4"/>
      </svg>
    </button>
    {#if openFilter === 'country'}
      <div class="absolute left-0 rounded-xl border py-1"
           style="top:calc(100% + 6px); background:#fff; border-color:#e7e5e4; box-shadow:0 4px 20px rgba(0,0,0,0.1); min-width:160px; max-height:260px; overflow-y:auto; z-index:var(--z-popover)">
        <button type="button" on:click|stopPropagation={() => { activeCountry = null; openFilter = null; }}
          class="w-full text-left px-4 py-2.5 text-sm cursor-pointer transition-colors"
          style="background:none; border:none; color:{activeCountry === null ? '#15140F' : '#78716c'}; font-weight:{activeCountry === null ? '500' : '400'}">
          Все страны
        </button>
        {#each countries as cc}
          <button type="button" on:click|stopPropagation={() => { activeCountry = cc; openFilter = null; }}
            class="w-full text-left px-4 py-2.5 text-sm cursor-pointer transition-colors"
            style="background:none; border:none; color:{activeCountry === cc ? '#15140F' : '#78716c'}; font-weight:{activeCountry === cc ? '500' : '400'}">
            {flag(cc) || ''} {cc}
          </button>
        {/each}
      </div>
    {/if}
  </div>
  {/if}

  {#if feeds.length >= 2}
  <div style="position:relative">
    <button type="button"
      on:click|stopPropagation={() => openFilter = openFilter === 'feed' ? null : 'feed'}
      class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border cursor-pointer transition-colors"
      style={activeFeed ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#57534e; border-color:#e7e5e4; background:#fafaf9;'}>
      {activeFeed || 'Источник'}
      <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"
           style="transition:transform 0.2s; transform:rotate({openFilter === 'feed' ? '180deg' : '0deg'})">
        <path d="M2 4l4 4 4-4"/>
      </svg>
    </button>
    {#if openFilter === 'feed'}
      <div class="absolute left-0 rounded-xl border py-1"
           style="top:calc(100% + 6px); background:#fff; border-color:#e7e5e4; box-shadow:0 4px 20px rgba(0,0,0,0.1); min-width:180px; max-height:260px; overflow-y:auto; z-index:var(--z-popover)">
        <button type="button" on:click|stopPropagation={() => { activeFeed = null; openFilter = null; }}
          class="w-full text-left px-4 py-2.5 text-sm cursor-pointer transition-colors"
          style="background:none; border:none; color:{activeFeed === null ? '#15140F' : '#78716c'}; font-weight:{activeFeed === null ? '500' : '400'}">
          Все источники
        </button>
        {#each feeds as feed}
          <button type="button" on:click|stopPropagation={() => { activeFeed = feed; openFilter = null; }}
            class="w-full text-left px-4 py-2.5 text-sm cursor-pointer transition-colors"
            style="background:none; border:none; color:{activeFeed === feed ? '#15140F' : '#78716c'}; font-weight:{activeFeed === feed ? '500' : '400'}">
            {feed}
          </button>
        {/each}
      </div>
    {/if}
  </div>
  {/if}

</div>
{/if}

<!-- Список карточек -->
{#if filtered.length === 0}
  <div class="not-prose mt-2 p-5 rounded-xl flex items-center justify-between" style="background:#f5f4f2; border:1px solid #e7e5e4">
    <p class="text-sm" style="color:#a8a29e">По фильтру ничего не найдено.</p>
    <button type="button"
      class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer ml-4"
      style="color:#78716c; border-color:#d6d3d1; background:#fafaf9;"
      on:click={() => { activeCountry = null; activeFeed = null; }}>Сбросить</button>
  </div>
{:else}
<div class="not-prose mt-2 relative" style="padding-left:44px">
  <!-- Вертикальная линия -->
  <div class="absolute" style="top:0; bottom:20px; left:32px; width:1px; background:#e7e5e4"></div>

  {#each groupedByDay as day (day.dayKey)}
    <div class="mb-2">
      <!-- Разделитель дня: uppercase, приглушённый цвет, маскирует вертикальную линию
           таймлайна фоном страницы поверх линии. Подписи времени суток внутри дня
           (Вечер/День/Утро/Ночь) на этой странице не показываем — сгруппированы,
           но без собственного заголовка, чтобы не дублировать структуру. -->
      <p class="text-xs font-medium uppercase tracking-widest mb-2" style="color:#c4bca9; margin-left:-44px; position:relative; z-index:2; background:#faf9f7">{day.dayLabel}</p>

      {#each day.groups as group}
      <div class="mb-4">
        <div class="flex flex-col">
        {#each group.items as item}
          {@const _t = new Date(item.published_dttm).toLocaleTimeString('ru-RU', {hour:'2-digit', minute:'2-digit'})}
          <div class="relative mb-2">

            <!-- Время (слева от вертикальной линии) -->
            <div class="absolute text-right select-none pointer-events-none" style="top:12px; left:-44px; width:24px">
              <span class="block font-medium" style="font-size:15px; line-height:1.1; color:#57534e">{_t.slice(0, 3)}</span>
              <span class="block" style="font-size:10px; color:#c4bca9; margin-top:1px">{_t.slice(3)}</span>
            </div>

            <!-- Точка на вертикальной линии -->
            <div class="absolute rounded-full pointer-events-none" style="top:16px; left:-16px; width:8px; height:8px; background:#e7e5e4"></div>

            <!-- Соединительная линия -->
            <div class="absolute pointer-events-none" style="top:20px; left:-8px; width:8px; height:1px; background:#e7e5e4"></div>

            <!-- Карточка -->
            <div class="rounded-xl border overflow-hidden relative"
                 style="background:#faf9f7; border-color:#e7e5e4">

              <!-- Содержимое — уезжает на -100% при открытии -->
              <div class="px-4 py-3"
                   on:click={() => { if (item.news_link) slidUid = item.uid; }}
                   style="transform:translateX({slidUid === item.uid ? '-100%' : '0'}); transition:transform 0.28s cubic-bezier(0.4,0,0.2,1); {item.news_link ? 'cursor:pointer' : ''}">

                {#if item.image_url && !imgError[item.uid]}
                  <!-- Картинка без отступов + мета + заголовок поверх -->
                  <div class="-mx-4 -mt-3 mb-3 relative">
                    <div style="aspect-ratio:16/9; background:#f5f4f2">
                      <img src={absUrl(item.image_url)} alt="" loading="lazy"
                           on:error={() => { imgError[item.uid] = true; imgError = imgError; }}
                           on:load={(e) => { if (e.target.naturalWidth < 300) { imgError[item.uid] = true; imgError = imgError; } }}
                           class="w-full h-full object-cover" />
                    </div>
                    <!-- Мета сверху -->
                    <div class="absolute top-0 left-0 right-0 px-4 py-2"
                         style="background:linear-gradient(to bottom, rgba(0,0,0,0.5), transparent)">
                      <p class="text-xs flex items-center gap-1 flex-wrap" style="color:rgba(255,255,255,0.88)">
                        {#if item.country_code}{flag(item.country_code) || item.country_code}&nbsp;{/if}{item.feed_nm}
                        {#if item.city_nm}&nbsp;·&nbsp;{item.city_nm}{/if}
                        {#if item.news_link}&nbsp;·&nbsp;<span>{domain(item.news_link)}</span>{/if}
                      </p>
                    </div>
                    <!-- Заголовок снизу картинки -->
                    {#if item.title_txt}
                      <div class="absolute bottom-0 left-0 right-0 px-4 pt-6 pb-3"
                           style="background:linear-gradient(to top, rgba(0,0,0,0.65), transparent)">
                        <p class="text-sm font-semibold leading-snug" style="color:#ffffff">{item.title_txt}</p>
                      </div>
                    {/if}
                  </div>
                {:else}
                  <!-- Мета-строка для карточек без картинки -->
                  <p class="text-xs mb-1 flex items-center gap-1 flex-wrap" style="color:#a8a29e">
                    {#if item.country_code}{flag(item.country_code) || item.country_code}&nbsp;{/if}{item.feed_nm}
                    {#if item.city_nm}&nbsp;·&nbsp;{item.city_nm}{/if}
                    {#if item.news_link}&nbsp;·&nbsp;<span>{domain(item.news_link)}</span>{/if}
                  </p>

                  <!-- Заголовок для карточек без картинки -->
                  {#if item.title_txt}
                    <p class="text-sm font-medium leading-snug mb-1" style="color:#15140F">{item.title_txt}</p>
                  {/if}
                {/if}

                <!-- Раскрытие текста по кнопке -->
                {#if item.summary_txt}
                  <p use:clampDetect={item.uid}
                     class="card-text text-sm leading-relaxed overflow-hidden mb-1"
                     style="color:#57534e; max-height:{expanded[item.uid] ? (fullHeight[item.uid] ? fullHeight[item.uid] + 'px' : '600px') : truncated[item.uid] === false ? 'none' : '4.9em'}; display:-webkit-box; -webkit-box-orient:vertical; line-clamp:{expanded[item.uid] ? 'none' : 3}; -webkit-line-clamp:{expanded[item.uid] ? 'none' : 3};"
                     >{item.summary_txt}</p>
                  {#if truncated[item.uid]}
                    <button type="button"
                      class="expand-btn inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none transition-colors"
                      style="color:#a8a29e; background:none; border:none; padding:0"
                      on:click|preventDefault|stopPropagation={() => { expanded[item.uid] = !expanded[item.uid]; expanded = expanded; }}>
                      {expanded[item.uid] ? 'Скрыть' : 'Показать полностью'}
                      <span style="display:inline-flex; transform:rotate({expanded[item.uid] ? '180deg' : '0deg'}); transition:transform 0.2s">
                        <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
                          <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
                        </svg>
                      </span>
                    </button>
                  {/if}
                {/if}

              </div>

              <!-- Оверлей — полностью перекрывает карточку -->
              {#if item.news_link}
                <div class="absolute inset-0 flex items-center justify-center"
                     on:click={() => slidUid = null}
                     style="transform:translateX({slidUid === item.uid ? '0' : '100%'}); transition:transform 0.28s cubic-bezier(0.4,0,0.2,1); background:#faf9f7; cursor:pointer">
                  <span on:click|stopPropagation={() => slidUid = null}
                        class="inline-flex items-center gap-1"
                        style="position:absolute; top:12px; left:12px; cursor:pointer; color:#a8a29e; font-size:12px; font-weight:500">
                    <svg width="12" height="12" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M12 4L6 10L12 16"/>
                    </svg>
                    Назад
                  </span>
                  <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                     on:click|stopPropagation
                     class="flex items-center gap-2 px-5 py-2.5 rounded-xl"
                     style="border:1px solid #e7e5e4; background:#f5f4f2; text-decoration:none; color:#15140F">
                    <svg width="17" height="17" viewBox="0 0 20 20" fill="#57534e">
                      <path fill-rule="evenodd" d="M4.25 5.5a.75.75 0 00-.75.75v8.5c0 .414.336.75.75.75h8.5a.75.75 0 00.75-.75v-4a.75.75 0 011.5 0v4A2.25 2.25 0 0112.75 17h-8.5A2.25 2.25 0 012 14.75v-8.5A2.25 2.25 0 014.25 4h5a.75.75 0 010 1.5h-5z" clip-rule="evenodd"/>
                      <path fill-rule="evenodd" d="M6.194 12.753a.75.75 0 001.06.053L16.5 4.44v2.81a.75.75 0 001.5 0v-4.5a.75.75 0 00-.75-.75h-4.5a.75.75 0 000 1.5h2.553l-9.056 8.194a.75.75 0 00-.053 1.06z" clip-rule="evenodd"/>
                    </svg>
                    <span>
                      <span style="display:block; font-size:14px; font-weight:500; color:#15140F">Читать оригинал</span>
                      <span style="display:block; font-size:11px; color:#a8a29e; margin-top:1px">{domain(item.news_link)}</span>
                    </span>
                  </a>
                </div>
              {/if}

            </div>
          </div>
        {/each}
        </div>
      </div>
      {/each}
    </div>
  {/each}
</div>
{/if}

{:else}

<div class="not-prose mt-4 p-6 rounded-xl" style="background:#f5f4f2; border:1px solid #e7e5e4">
  <p class="text-sm" style="color:#a8a29e">Публикаций с упоминанием этого актёра в сюжете пока не найдено.</p>
</div>

{/if}

{:else}

<div class="not-prose mt-4 p-6 rounded-xl" style="background:#f5f4f2; border:1px solid #e7e5e4">
  <p class="text-sm" style="color:#a8a29e">Актёр не найден в этом сюжете.</p>
</div>

{/if}

<div style="height:32px"></div>
</div>

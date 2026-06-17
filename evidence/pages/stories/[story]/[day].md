---
hide_breadcrumbs: true
---

<script>
  const MONTHS_GEN = [
    'января','февраля','марта','апреля','мая','июня',
    'июля','августа','сентября','октября','ноября','декабря'
  ];

  function formatRuDate(isoDay) {
    const [y, m, d] = isoDay.split('-').map(Number);
    return `${d} ${MONTHS_GEN[m - 1]} ${y}`;
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

  $: ruDate = formatRuDate(params.day);

  let activeCountry = null;
  let activeFeed = null;

  let truncated  = {};
  let expanded   = {};
  let hovered    = {};
  let fullHeight = {};
  let imgError   = {};

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

  $: countries = [...new Set(q_news_feed.filter(i => i.country_code).map(i => i.country_code))].sort();
  $: feeds = [...new Set(q_news_feed.map(i => i.feed_nm))].sort();

  $: filtered = q_news_feed
    .map((item, idx) => ({ ...item, uid: idx }))
    .filter(item => {
      if (activeCountry && item.country_code !== activeCountry) return false;
      if (activeFeed && item.feed_nm !== activeFeed) return false;
      return true;
    });

  $: grouped = (() => {
    const order = ['Вечер', 'День', 'Утро', 'Ночь'];
    const groups = {};
    for (const item of filtered) {
      const tod = getTimeOfDay(item.published_dttm);
      if (!groups[tod]) groups[tod] = [];
      groups[tod].push(item);
    }
    return order.filter(k => groups[k]).map(k => ({ label: k, items: groups[k] }));
  })();

  $: stats = {
    total: filtered.length,
    feedCount: new Set(filtered.map(i => i.feed_nm)).size,
  };

</script>

<style>
  .card-text {
    transition: max-height 0.6s cubic-bezier(0.4, 0, 0.2, 1);
  }
</style>

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
FROM dwh_pg_1.b_news_stories_feeds
WHERE story_id = ${params.story}
  AND CAST(published_dttm AS DATE) = '${params.day}'::date
ORDER BY published_dttm DESC
```

<div class="not-prose mt-6 mb-5 flex items-center gap-3">
<a href="/stories/{params.story}"
     class="inline-flex items-center px-2 py-1 rounded-full text-sm flex-shrink-0 transition-colors"
     style="color:#78716c; border:1px solid transparent; background:#fafaf9;"
     onmouseover="this.style.borderColor='#d6d3d1'" onmouseout="this.style.borderColor='transparent'">←</a>
<h2 class="text-xl font-semibold m-0" style="color:#15140F">Источники за {ruDate}</h2>
</div>

{#if q_news_feed.length > 0}

<!-- Шапка со статистикой -->
<p class="text-sm mb-4" style="color:#a8a29e">
  {pluralize(stats.total, 'материал', 'материала', 'материалов')}
  &nbsp;·&nbsp;{pluralize(stats.feedCount, 'источник', 'источника', 'источников')}
</p>

<!-- Фильтры по странам -->
{#if countries.length >= 2}
<div class="not-prose flex flex-wrap gap-2 mb-3">
  <button type="button"
    class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer"
    data-act={activeCountry === null}
    style={activeCountry === null ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:transparent; background:#fafaf9;'}
    onmouseover="if(this.dataset.act!=='true') this.style.borderColor='#d6d3d1'"
    onmouseout="if(this.dataset.act!=='true') this.style.borderColor='transparent'"
    on:click={() => activeCountry = null}>Все страны</button>
  {#each countries as cc}
    <button type="button"
      class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer"
      data-act={activeCountry === cc}
      style={activeCountry === cc ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:transparent; background:#fafaf9;'}
      onmouseover="if(this.dataset.act!=='true') this.style.borderColor='#d6d3d1'"
      onmouseout="if(this.dataset.act!=='true') this.style.borderColor='transparent'"
      on:click={() => activeCountry = activeCountry === cc ? null : cc}>{flag(cc) || cc}&nbsp;{cc}</button>
  {/each}
</div>
{/if}

<!-- Фильтры по лентам -->
{#if feeds.length >= 2}
<div class="not-prose flex flex-wrap gap-2 mb-5">
  <button type="button"
    class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer"
    data-act={activeFeed === null}
    style={activeFeed === null ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:transparent; background:#fafaf9;'}
    onmouseover="if(this.dataset.act!=='true') this.style.borderColor='#d6d3d1'"
    onmouseout="if(this.dataset.act!=='true') this.style.borderColor='transparent'"
    on:click={() => activeFeed = null}>Все ленты</button>
  {#each feeds as feed}
    <button type="button"
      class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border transition-colors cursor-pointer"
      data-act={activeFeed === feed}
      style={activeFeed === feed ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:transparent; background:#fafaf9;'}
      onmouseover="if(this.dataset.act!=='true') this.style.borderColor='#d6d3d1'"
      onmouseout="if(this.dataset.act!=='true') this.style.borderColor='transparent'"
      on:click={() => activeFeed = activeFeed === feed ? null : feed}>{feed}</button>
  {/each}
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
<div class="not-prose mt-2 relative" style="padding-left:60px">
  <!-- Вертикальная линия -->
  <div class="absolute" style="top:0; bottom:20px; left:36px; width:1px; background:#e7e5e4"></div>

  {#each grouped as group}
    <div class="mb-6">
      <p class="text-xs font-medium uppercase tracking-widest mb-3" style="color:#c4bca9">{group.label}</p>
      <div class="flex flex-col">
        {#each group.items as item}
          {@const _t = new Date(item.published_dttm).toLocaleTimeString('ru-RU', {hour:'2-digit', minute:'2-digit'})}
          <div class="group relative mb-3"
               on:mouseenter={() => { hovered[item.uid] = true; hovered = hovered; }}
               on:mouseleave={() => { hovered[item.uid] = false; hovered = hovered; }}>

            <!-- Время (слева от вертикальной линии) -->
            <div class="absolute text-right select-none pointer-events-none" style="top:14px; left:-60px; width:30px">
              <span class="block font-medium" style="font-size:15px; line-height:1.1; color:#57534e">{_t.slice(0, 3)}</span>
              <span class="block" style="font-size:11px; color:#c4bca9; margin-top:1px">{_t.slice(3)}</span>
            </div>

            <!-- Точка на вертикальной линии -->
            <div class="absolute rounded-full pointer-events-none" style="top:16px; left:-28px; width:8px; height:8px; transition:background 0.2s ease, box-shadow 0.2s ease; background:{hovered[item.uid] ? '#c4bca9' : '#e7e5e4'}; box-shadow:{hovered[item.uid] ? '0 0 0 3px rgba(196,188,169,0.2)' : 'none'}"></div>

            <!-- Соединительная линия -->
            <div class="absolute pointer-events-none" style="top:20px; left:-20px; width:20px; height:1px; background:#c4bca9; opacity:{hovered[item.uid] ? 1 : 0}; transition:opacity 0.2s ease"></div>

            <!-- Карточка -->
            <div class="rounded-xl px-4 py-3 border overflow-hidden transition-colors" style="background:#faf9f7; border-color:{hovered[item.uid] || expanded[item.uid] ? '#d6d3d1' : 'transparent'}">

              {#if item.image_url && !imgError[item.uid]}
                <!-- Картинка без отступов + мета + заголовок поверх -->
                <div class="-mx-4 -mt-3 mb-3 relative">
                  <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                     on:click|stopPropagation class="block" style="aspect-ratio:16/9; background:#f5f4f2">
                    <img src={absUrl(item.image_url)} alt="" loading="lazy"
                         on:error={() => { imgError[item.uid] = true; imgError = imgError; }}
                         on:load={(e) => { if (e.target.naturalWidth < 300) { imgError[item.uid] = true; imgError = imgError; } }}
                         class="w-full h-full object-cover" />
                  </a>
                  <!-- Мета сверху -->
                  <div class="absolute top-0 left-0 right-0 px-4 py-2"
                       style="background:linear-gradient(to bottom, rgba(0,0,0,0.5), transparent)">
                    <p class="text-xs flex items-center gap-1 flex-wrap" style="color:rgba(255,255,255,0.88)">
                      {#if item.country_code}{flag(item.country_code) || item.country_code}&nbsp;{/if}{item.feed_nm}
                      {#if item.city_nm}&nbsp;·&nbsp;{item.city_nm}{/if}
                      {#if item.news_link}&nbsp;·&nbsp;<span>{domain(item.news_link)}</span>
                        <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                           on:click|stopPropagation
                           class="inline-flex items-center opacity-0 group-hover:opacity-100 transition-opacity"
                           style="color:rgba(255,255,255,0.88)"><svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 2H2a1 1 0 0 0-1 1v7a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1V7"/><polyline points="8 1 11 1 11 4"/><line x1="5" y1="7" x2="11" y2="1"/></svg></a>
                      {/if}
                    </p>
                  </div>
                  <!-- Заголовок снизу картинки -->
                  <div class="absolute bottom-0 left-0 right-0 px-4 pt-6 pb-3"
                       style="background:linear-gradient(to top, rgba(0,0,0,0.65), transparent)">
                    {#if item.title_txt}
                      <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                         on:click|stopPropagation
                         class="text-sm font-semibold leading-snug block"
                         style="color:#ffffff">{item.title_txt}</a>
                    {:else}
                      <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                         on:click|stopPropagation
                         class="text-xs block"
                         style="color:rgba(255,255,255,0.7)">Открыть источник →</a>
                    {/if}
                  </div>
                </div>
              {:else}
                <!-- Мета-строка для карточек без картинки -->
                <p class="text-xs mb-1 flex items-center gap-1 flex-wrap" style="color:#a8a29e">
                  {#if item.country_code}{flag(item.country_code) || item.country_code}&nbsp;{/if}{item.feed_nm}
                  {#if item.city_nm}&nbsp;·&nbsp;{item.city_nm}{/if}
                  {#if item.news_link}&nbsp;·&nbsp;<span>{domain(item.news_link)}</span>
                    <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                       on:click|stopPropagation
                       class="inline-flex items-center opacity-0 group-hover:opacity-100 transition-opacity hover:text-stone-500"
                       style="color:#a8a29e"><svg width="11" height="11" viewBox="0 0 12 12" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 2H2a1 1 0 0 0-1 1v7a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1V7"/><polyline points="8 1 11 1 11 4"/><line x1="5" y1="7" x2="11" y2="1"/></svg></a>
                  {/if}
                </p>

                <!-- Заголовок-ссылка для карточек без картинки -->
                {#if item.title_txt}
                  <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                     on:click|stopPropagation
                     class="text-sm font-medium leading-snug hover:text-stone-500 block mb-1"
                     style="color:#15140F">{item.title_txt}</a>
                {:else}
                  <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                     on:click|stopPropagation
                     class="text-xs hover:text-stone-500 block mb-1"
                     style="color:#a8a29e">Открыть источник →</a>
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
                    class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none transition-colors"
                    style="color:#a8a29e; background:none; border:none; padding:0"
                    onmouseover="this.style.color='#78716c'" onmouseout="this.style.color='#a8a29e'"
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
          </div>
        {/each}
      </div>
    </div>
  {/each}
</div>
{/if}

{:else}

<div class="not-prose mt-4 p-6 rounded-xl" style="background:#f5f4f2; border:1px solid #e7e5e4">
  <p class="text-sm" style="color:#a8a29e">За этот день источников не найдено.</p>
</div>

{/if}

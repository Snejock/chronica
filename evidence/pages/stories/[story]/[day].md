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
  .expand-btn { -webkit-tap-highlight-color: transparent; }
  .expand-btn:active { color: #a8a29e !important; }
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
     class="inline-flex items-center px-2 py-1 rounded-full text-sm flex-shrink-0"
     style="color:#78716c; border:1px solid #e7e5e4; background:#fafaf9;">←</a>
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
    style={activeCountry === null ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:#e7e5e4; background:#fafaf9;'}
    on:click={() => activeCountry = null}>Все страны</button>
  {#each countries as cc}
    <button type="button"
      class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border cursor-pointer"
      style={activeCountry === cc ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:#e7e5e4; background:#fafaf9;'}
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
    style={activeFeed === null ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:#e7e5e4; background:#fafaf9;'}
    on:click={() => activeFeed = null}>Все ленты</button>
  {#each feeds as feed}
    <button type="button"
      class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium border cursor-pointer"
      style={activeFeed === feed ? 'color:#fff; border-color:#57534e; background:#57534e;' : 'color:#78716c; border-color:#e7e5e4; background:#fafaf9;'}
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
          <div class="relative mb-3"
               on:click={() => { slidUid = slidUid === item.uid ? null : item.uid; }}>

            <!-- Время (слева от вертикальной линии) -->
            <div class="absolute text-right select-none pointer-events-none" style="top:14px; left:-60px; width:30px">
              <span class="block font-medium" style="font-size:15px; line-height:1.1; color:#57534e">{_t.slice(0, 3)}</span>
              <span class="block" style="font-size:11px; color:#c4bca9; margin-top:1px">{_t.slice(3)}</span>
            </div>

            <!-- Точка на вертикальной линии -->
            <div class="absolute rounded-full pointer-events-none" style="top:16px; left:-28px; width:8px; height:8px; background:#e7e5e4"></div>

            <!-- Соединительная линия -->
            <div class="absolute pointer-events-none" style="top:20px; left:-20px; width:20px; height:1px; background:#e7e5e4"></div>

            <!-- Карточка (бордер фиксирован, содержимое скользит внутри) -->
            <div class="rounded-xl border overflow-hidden relative transition-colors"
                 style="background:#faf9f7; border-color:#e7e5e4">

              <!-- Скользящее содержимое -->
              <div class="px-4 py-3"
                   style="transform:translateX({slidUid === item.uid ? '-56px' : '0'}); transition:transform 0.25s cubic-bezier(0.4,0,0.2,1)">

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

              <!-- Иконка — скользит из-за правого края внутри карточки -->
              {#if item.news_link}
                <a href={absUrl(item.news_link)} target="_blank" rel="noopener"
                   on:click|stopPropagation
                   class="absolute top-0 bottom-0 right-0 flex items-center justify-center"
                   style="width:56px; transform:translateX({slidUid === item.uid ? '0' : '100%'}); transition:transform 0.25s cubic-bezier(0.4,0,0.2,1)">
                  <div class="rounded-full flex items-center justify-center"
                       style="width:36px; height:36px; border:1px solid #e7e5e4; background:#fafaf9">
                    <svg width="18" height="18" viewBox="0 0 20 20" fill="#78716c">
                      <path fill-rule="evenodd" d="M4.25 5.5a.75.75 0 00-.75.75v8.5c0 .414.336.75.75.75h8.5a.75.75 0 00.75-.75v-4a.75.75 0 011.5 0v4A2.25 2.25 0 0112.75 17h-8.5A2.25 2.25 0 012 14.75v-8.5A2.25 2.25 0 014.25 4h5a.75.75 0 010 1.5h-5z" clip-rule="evenodd"/>
                      <path fill-rule="evenodd" d="M6.194 12.753a.75.75 0 001.06.053L16.5 4.44v2.81a.75.75 0 001.5 0v-4.5a.75.75 0 00-.75-.75h-4.5a.75.75 0 000 1.5h2.553l-9.056 8.194a.75.75 0 00-.053 1.06z" clip-rule="evenodd"/>
                    </svg>
                  </div>
                </a>
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

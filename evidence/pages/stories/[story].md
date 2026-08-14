---
full_width: false
hide_breadcrumbs: true
---

<script>
  import { getContext as _getCtx, tick } from 'svelte';
  import { goto } from '$app/navigation';
  import { slide, draw } from 'svelte/transition';
  const breadcrumb = _getCtx('breadcrumb');
  $: if (q_story?.[0]?.story_nm) breadcrumb?.set({ storyName: q_story[0].story_nm });

  let pageEl;

  onMount(() => {
    requestAnimationFrame(updateGrayscale);

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
  let openInfoId = null;
  let openEventId = null;

  // q_stories_summaries отсортирован ASC (старые слева, новые справа, см. q_key_events
  // выше) — видимое окно берём с конца массива, т.е. от самых свежих дней.
  $: visible = q_stories_summaries.slice(Math.max(0, q_stories_summaries.length - shown));
  $: hasMore = shown < q_stories_summaries.length;

  // Горизонтальный таймлайн ключевых событий: слева старые даты, справа новые
  // (q_key_events отсортирован ASC по dt, так что последний элемент — самый свежий).
  // Без зигзага: все подписи события — в один ряд НАД осью (растут вверх от
  // фиксированного отступа над точкой), дата — под точкой, как и раньше
  // (см. ревью блока «Ключевые события»).
  // Трек: height=200px, rail=150px от верха, dot=11px.
  const KE_SIDE_PAD    = 100;
  const KE_GAP         = 165;
  $: keyEventLayout = (() => {
    if (!q_key_events || q_key_events.length === 0) return { trackW: 0, items: [] };
    const trackW = Math.max(400, (q_key_events.length - 1) * KE_GAP + KE_SIDE_PAD * 2);
    const lastIdx = q_key_events.length - 1;
    const items  = q_key_events.map((ev, i) => ({
      ...ev, id: i, x: KE_SIDE_PAD + i * KE_GAP, fresh: i === lastIdx,
    }));
    return { trackW, items };
  })();

  // Рябь на тапе по станции
  let rippleEventId = null;
  let rippleSeq = 0;
  function pingRipple(id) {
    rippleEventId = id;
    rippleSeq += 1;
  }

  let hovered = {};

  let truncated  = {};
  let expanded   = {};
  let fullHeight = {};

  // Цитаты: по умолчанию видна только 1 последняя (q_story_quotes уже ORDER BY
  // published_dttm DESC), кнопка «Показать ещё N» дальше подгружает по 3, а не
  // раскрывает сразу все.
  const QUOTES_INITIAL_CNT = 1;
  const QUOTES_PAGE_CNT    = 3;
  let quotesVisibleCnt = QUOTES_INITIAL_CNT;

  let imgError = {};
  function absUrl(url) {
    if (!url) return url;
    return /^https?:\/\//i.test(url) ? url : 'https://' + url;
  }

  $: dayImages = Object.fromEntries((q_day_images || []).map(r => [r.day, r.image_url]));

  // Действующие лица: фото лежат в MinIO как путь без хоста (см. dds.s_actor_media.photo_link) --
  // достраиваем публичным доменом (реверс-прокси -> 192.168.1.15:39200, TLS выпущен на этот хост).
  const MEDIA_BASE = 'https://media.chronica.life';
  function mediaUrl(path) {
    if (!path) return null;
    return MEDIA_BASE + path;
  }

  let selectedActor = null;
  let actorImgError = {};

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

  function forecastChart(rows) {
    const vals = rows.map(r => +r.p_posterior_prt);
    const lo = Math.max(0, Math.min(...vals) - 0.05);
    const hi = Math.min(1, Math.max(...vals) + 0.05);
    // Стандартный оранжевый, не зависит от текущей вероятности. rgba-версия задана
    // напрямую (не через withAlpha) -- та ждёт строку вида rgb(r,g,b), как отдаёт
    // barTopColor/lerpColor, а не hex.
    const lineColor = '#FF9830';
    const lineColorSoft = 'rgba(255, 152, 48, 0.25)';
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
              { offset: 0, color: lineColorSoft },
              { offset: 1, color: 'rgba(255,152,48,0)' }
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

  // Прокрутка к правому краю (последние события/дни) при монтировании
  function autoScrollRight(node) {
    const t = setTimeout(() => { node.scrollLeft = node.scrollWidth; }, 60);
    return { destroy() { clearTimeout(t); } };
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

  async function onChronicleScroll(e) {
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
    // Слева теперь прошлое: догружаем более старые дни при приближении к
    // левому краю. Новые карточки при этом встают ПЕРЕД уже отрендеренными
    // (см. keyed each ниже), поэтому компенсируем scrollLeft на их ширину —
    // иначе текущий вид дёрнется вправо на ширину подгруженных карточек.
    if (el.scrollLeft <= el.clientWidth) {
      const prevScrollWidth = el.scrollWidth;
      shown += PAGE_SIZE;
      await tick();
      el.scrollLeft += el.scrollWidth - prevScrollWidth;
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
  .chronicle-carousel, .key-events-track {
    cursor: grab;
    scrollbar-width: none;
    -ms-overflow-style: none;
  }
  .chronicle-carousel::-webkit-scrollbar,
  .key-events-track::-webkit-scrollbar {
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

  /* --- Key events: metro-карта --- */
  .ke-rail {
    height: 3px;
    border-radius: 2px;
    background: linear-gradient(to right, #FADE2A 0%, #FF9830 50%, #C4162A 100%);
  }
  .ke-tag {
    transition: color 0.2s, transform 0.2s;
  }
  @media (hover: hover) {
    .ke-tag:hover {
      color: #15140F !important;
      transform: translateY(-2px);
    }
  }
  .ke-fade-l, .ke-fade-r {
    position: absolute;
    top: 0; bottom: 0;
    width: 44px;
    pointer-events: none;
    z-index: 4;
  }
  .ke-fade-l { left:  0; background: linear-gradient(to right,  #faf9f7, transparent); }
  .ke-fade-r { right: 0; background: linear-gradient(to left, #faf9f7, transparent); }

  @keyframes ke-ripple {
    from { transform: scale(0.6); opacity: 0.65; }
    to   { transform: scale(3.4); opacity: 0; }
  }
  .ke-ripple {
    position: absolute;
    inset: 0;
    border-radius: 50%;
    border: 2px solid #C4162A;
    animation: ke-ripple 0.55s ease-out forwards;
    pointer-events: none;
  }

  /* --- Действующие лица: ряд аватаров --- */
  .actors-rail {
    display: flex;
    gap: 14px;
    overflow-x: auto;
    scrollbar-width: none;
    -ms-overflow-style: none;
    padding: 4px 12px 6px;
  }
  .actors-rail::-webkit-scrollbar {
    display: none;
  }
  .actor-item {
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    width: 64px;
    background: none;
    border: none;
    cursor: pointer;
  }
  .actor-avatar {
    width: 64px;
    height: 64px;
    border-radius: 50%;
    object-fit: cover;
    object-position: var(--actor-avatar-focus);
    display: block;
    border: 2px solid transparent;
    -webkit-user-drag: none;
    transition: opacity 0.25s ease, filter 0.25s ease, border-color 0.25s ease;
  }
  .actor-item.is-active .actor-avatar {
    border-color: #C0401C;
  }
  .actors-rail.has-selection .actor-item:not(.is-active) .actor-avatar {
    opacity: 0.68;
    filter: grayscale(0.35);
  }
  .actor-placeholder {
    width: 64px;
    height: 64px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    background: #f0ede8;
    color: #a8a29e;
    font-size: 18px;
    font-weight: 600;
    border: 2px solid transparent;
    transition: opacity 0.25s ease, border-color 0.25s ease;
  }
  .actor-item.is-active .actor-placeholder {
    border-color: #C0401C;
  }
  .actors-rail.has-selection .actor-item:not(.is-active) .actor-placeholder {
    opacity: 0.68;
  }

</style>

```sql q_story
SELECT story_nm, CAST(geo_lat AS DOUBLE) AS geo_lat, CAST(geo_lon AS DOUBLE) AS geo_lon
FROM dwh_pg_1.b_stories
WHERE story_id = ${params.story}
  AND language_code = 'ru'
```

```sql q_story_brief
SELECT brief_txt
FROM dwh_pg_1.story_briefs
WHERE story_id = ${params.story}
  AND language_code = 'ru'
  AND is_active = true
LIMIT 1
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
FROM dwh_pg_1.story_summaries_d
WHERE language_code = 'ru'
  AND story_id = ${params.story}
ORDER BY dt ASC
```

```sql q_key_events
SELECT
    dt
    , event_nm
    , strftime(dt, '%Y-%m-%d') AS iso_dt
    , strftime(dt, '%d') || ' ' ||
      CASE extract(month FROM dt)
        WHEN 1  THEN 'января'   WHEN 2  THEN 'февраля'
        WHEN 3  THEN 'марта'    WHEN 4  THEN 'апреля'
        WHEN 5  THEN 'мая'      WHEN 6  THEN 'июня'
        WHEN 7  THEN 'июля'     WHEN 8  THEN 'августа'
        WHEN 9  THEN 'сентября' WHEN 10 THEN 'октября'
        WHEN 11 THEN 'ноября'   WHEN 12 THEN 'декабря'
      END AS formatted_dt
    , strftime(dt, '%d') || ' ' ||
      CASE extract(month FROM dt)
        WHEN 1  THEN 'янв'  WHEN 2  THEN 'фев'  WHEN 3  THEN 'мар'
        WHEN 4  THEN 'апр'  WHEN 5  THEN 'май'  WHEN 6  THEN 'июн'
        WHEN 7  THEN 'июл'  WHEN 8  THEN 'авг'  WHEN 9  THEN 'сен'
        WHEN 10 THEN 'окт'  WHEN 11 THEN 'ноя'  WHEN 12 THEN 'дек'
      END AS short_dt
FROM dwh_pg_1.story_key_events
WHERE story_id = ${params.story}
  AND language_code = 'ru'
ORDER BY dt ASC
```

```sql q_forecasts
WITH latest AS (
    SELECT forecast_id, MAX(published_dttm) AS dttm
    FROM dwh_pg_1.b_forecast_posteriors
    WHERE language_code = 'ru' AND story_id = ${params.story}
    GROUP BY forecast_id
),
prev AS (
    SELECT b.forecast_id, b.p_posterior_prt AS p_prev
    FROM dwh_pg_1.b_forecast_posteriors b
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
FROM dwh_pg_1.b_forecast_posteriors b
JOIN latest l ON l.forecast_id = b.forecast_id AND l.dttm = b.published_dttm
LEFT JOIN prev p ON p.forecast_id = b.forecast_id
WHERE b.language_code = 'ru' AND b.story_id = ${params.story}
ORDER BY b.p_posterior_prt DESC
```

```sql q_forecasts_history
SELECT forecast_id, published_dttm, p_posterior_prt
FROM dwh_pg_1.b_forecast_posteriors
WHERE language_code = 'ru' AND story_id = ${params.story}
  AND published_dttm >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY forecast_id, published_dttm
```

```sql q_news_by_day
SELECT
    CAST(published_dttm AS DATE) AS day,
    COUNT(*) AS cnt
FROM dwh_pg_1.b_story_unews_texts
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
    FROM dwh_pg_1.b_story_feed_news
    WHERE story_id = ${params.story}
      AND image_url IS NOT NULL
      AND image_url != ''
) ranked
WHERE rn = 1
ORDER BY day
```

```sql q_actors
SELECT actor_id, canonical_nm, description_txt, source_link,
       photo_link, author_nm, license_nm,
       mentions_cnt, last_dttm, rank_idx
FROM dwh_pg_1.b_story_actors
WHERE story_id = ${params.story}
  AND language_code = 'ru'
ORDER BY rank_idx
```

<!-- В отличие от q_news_feed на странице актёра (там фильтр по одному actor_id),
     здесь цитаты сразу нескольких действующих лиц, поэтому подтягиваем canonical_nm/
     photo_link/description_txt, чтобы подписать, кто говорит и кем является. -->
```sql q_story_quotes
SELECT
    n.actor_id
    , a.canonical_nm
    , a.photo_link
    , a.description_txt
    , n.published_dttm
    , n.news_link
    , n.feed_nm
    , n.quote_txt
FROM dwh_pg_1.b_story_news_actors n
JOIN dwh_pg_1.b_story_actors a
  ON a.story_id = n.story_id
  AND a.actor_id = n.actor_id
  AND a.language_code = 'ru'
WHERE n.story_id = ${params.story}
  AND n.quote_txt IS NOT NULL
  AND n.quote_txt != ''
ORDER BY n.published_dttm DESC
```

<div bind:this={pageEl} on:click={() => { if (selectedActor !== null) selectedActor = null; }}>

{#if q_story[0]}
# {q_story[0].story_nm}
{/if}

{#if q_story_brief.length > 0}
<p class="text-sm leading-relaxed" style="color:#57534e; margin-bottom:32px">{q_story_brief[0].brief_txt}</p>
{/if}

## Ключевые события

{#if keyEventLayout.items.length > 0}
<div class="not-prose mt-2 mb-8" style="position:relative; margin-left:-12px; margin-right:-12px; isolation:isolate"
     on:click={() => { openEventId = null; }}>
  <!-- Fade-маски по краям — намёк на прокрутку -->
  <div class="ke-fade-l"></div>
  <div class="ke-fade-r"></div>

  <!-- Подсказка «левее — прошлое»: закреплена у края обёртки, а не трека,
       поэтому не уезжает при скролле. Только если правда есть куда скроллить. -->
  {#if keyEventLayout.items.length > 1}
  <div style="position:absolute; bottom:56px; left:14px; z-index:5; pointer-events:none">
    <span style="font-size:11px; font-weight:400; letter-spacing:0.04em; color:#C0401C; white-space:nowrap">‹ ранее</span>
  </div>
  {/if}

  <!-- {#key params.story}: use:-экшены (dragScroll/autoScrollRight) срабатывают
       только при создании DOM-узла. При переходе между сюжетами по клиенту
       SvelteKit этот компонент переиспользуется (меняются только params), сам
       div без key не пересоздаётся — автоскролл к свежим событиям на новом
       сюжете просто не срабатывал бы повторно. -->
  {#key params.story}
  <div class="key-events-track" use:dragScroll use:autoScrollRight
       style="overflow-x:auto; overscroll-behavior-x:contain; padding-bottom:4px">
    <div style="position:relative; width:{keyEventLayout.trackW}px; height:200px; min-width:100%">


      <!-- Градиентная дорога (ось) -->
      <div class="ke-rail" style="position:absolute; top:150px; left:0; right:0; transform:translateY(-50%); z-index:1"></div>

      <!-- SVG: короткий leader-стежок от точки к тегу — все теги теперь в один
           ряд над осью (без зигзага верх/низ). -->
      <svg style="position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;overflow:visible;z-index:2">
        {#each keyEventLayout.items as ev}
          <line x1={ev.x} y1={145} x2={ev.x} y2={100} stroke="#e7e5e4" stroke-width="1"/>
        {/each}
      </svg>

      {#each keyEventLayout.items as ev}
        {@const _isOpen = openEventId === ev.id}
        {@const _isFresh = ev.fresh}

        <!-- Дата под точкой -->
        <div style="position:absolute; top:159px; left:{ev.x}px; transform:translateX(-50%); text-align:center; pointer-events:none; z-index:3">
          <span style="font-size:11px; font-weight:500; color:{_isOpen ? '#15140F' : '#78716c'}; letter-spacing:0.03em; transition:color 0.2s; white-space:nowrap">{ev.short_dt}</span>
        </div>

        <!-- Станция-точка: метро-стиль (белая с кольцом, тенью, гало при выборе) -->
        <div style="position:absolute; top:150px; left:{ev.x}px; width:11px; height:11px; transform:translate(-50%,-50%); z-index:3; cursor:pointer"
             use:tappable on:tap={() => { openEventId = _isOpen ? null : ev.id; pingRipple(ev.id); }} on:click|stopPropagation>
          {#if rippleEventId === ev.id}
            {#key rippleSeq}
              <div class="ke-ripple" on:animationend={() => { if (rippleEventId === ev.id) rippleEventId = null; }}></div>
            {/key}
          {/if}
          <div style="position:absolute; inset:0; border-radius:50%;
                      background:{_isOpen ? '#C4162A' : '#ffffff'};
                      border:2.5px solid {_isOpen ? 'rgba(196,22,42,0.3)' : _isFresh ? '#C4162A' : '#c4bca9'};
                      box-shadow:{_isOpen
                        ? '0 0 0 4px rgba(196,22,42,0.12), 0 2px 6px rgba(0,0,0,0.18)'
                        : '0 1px 4px rgba(0,0,0,0.14)'};
                      transition:transform 0.4s cubic-bezier(0.34,1.56,0.64,1), background 0.2s ease, border-color 0.2s ease, box-shadow 0.2s ease;
                      transform:scale({_isOpen ? 1.45 : 1})"></div>
        </div>

        <!-- Тег: всегда над осью, рамка появляется при выборе. bottom-якорь,
             а не top, — чтобы блок рос вверх от фиксированного отступа над
             точкой независимо от числа строк текста. -->
        <div style="position:absolute; left:{ev.x}px; bottom:100px; width:150px; transform:translateX(-50%); cursor:pointer; z-index:{_isOpen ? 4 : 1}; text-align:center"
             use:tappable on:tap={() => { _isOpen ? goto(`/stories/${params.story}/${ev.iso_dt}`) : (openEventId = ev.id); }} on:click|stopPropagation>
          <div style="border-radius:12px; border:1px solid {_isOpen ? '#e7e5e4' : 'transparent'}; padding:5px 8px; background:{_isOpen ? '#faf9f7' : 'transparent'}; transition:border-color 0.2s, background 0.2s">
            <p class="ke-tag" style="font-size:14px; font-weight:400; color:#57534e; margin:0; line-height:1.35; transition:transform 0.2s">{ev.event_nm}</p>
          </div>
        </div>

      {/each}
    </div>
  </div>
  {/key}

</div>
{:else}
<div class="not-prose mt-4 mb-8 p-5 rounded-xl border" style="background:#faf9f7; border-color:#e7e5e4">
  <p class="text-sm" style="color:#a8a29e">Ключевые события ещё не определены.</p>
</div>
{/if}

{#if q_actors.length >= 3}
<!-- Заголовок не markdown-«##» — он должен быть внутри full-bleed плашки (бренд-цвет
     потом, пока нейтральный фон страницы). Инлайн-стили повторяют вычисленный стиль
     настоящего h2 сайта (20px/600/28px). margin:-12px гасит гутер .antialiased > div;
     до истинного края доезжает благодаря min-width:0 на <main> (+layout.svelte).
     padding-top не задаём: отступ сверху даёт только margin-коллапс с mb-8 предыдущего
     блока (те же 32px, что перед «Ключевыми событиями» и «Хроникой событий») — раньше
     здесь ещё был padding-top:14px поверх коллапса, и блок начинался заметно ниже. -->
<div class="not-prose mt-2 mb-8"
     style="position:relative; isolation:isolate; z-index:var(--z-content-raised);
            margin-left:-12px; margin-right:-12px;
            background:#faf9f7; padding:0 0 10px">
  <h2 style="margin:0 0 8px; padding:0 12px; font-size:20px; font-weight:600; line-height:28px; color:#15140F">Действующие лица</h2>
  <div class="actors-rail {selectedActor !== null ? 'has-selection' : ''}" use:dragScroll>
    {#each q_actors as a, i}
      <button type="button" class="actor-item {selectedActor === i ? 'is-active' : ''}"
        use:tappable on:tap={() => { selectedActor === i ? goto(`/stories/${params.story}/actors/${a.actor_id}`) : (selectedActor = i); }}
        on:click|stopPropagation>
        {#if mediaUrl(a.photo_link) && !actorImgError[a.actor_id]}
          <img class="actor-avatar" src={mediaUrl(a.photo_link)} alt="" loading="lazy" draggable="false"
               on:error={() => { actorImgError[a.actor_id] = true; actorImgError = actorImgError; }}
               on:load={(e) => { if (e.target.naturalWidth < 80) { actorImgError[a.actor_id] = true; actorImgError = actorImgError; } }} />
        {:else}
          <div class="actor-placeholder">{initials(a.canonical_nm)}</div>
        {/if}
        <span class="text-center" style="font-size:11px; line-height:1.25; color:#57534e; display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:2; overflow:hidden">{a.canonical_nm}</span>
      </button>
    {/each}
  </div>

  {#key selectedActor}
    {#if q_actors[selectedActor]}
      {@const a = q_actors[selectedActor]}
      <!-- Поповер поверх контента, не раздвигает вёрстку; закрывается кликом в любое место
           страницы (см. on:click на <div bind:this={pageEl}>) -->
      <div class="rounded-xl border overflow-hidden"
           transition:slide|local={{ duration: 180 }}
           style="position:absolute; left:12px; right:12px; top:100%; margin-top:6px;
                  background:#faf9f7; border-color:#e7e5e4; box-shadow:0 10px 28px rgba(0,0,0,0.14);
                  z-index:var(--z-popover)"
           on:click|stopPropagation>
        <div class="px-4 py-3">
          <p class="text-sm font-semibold leading-snug mb-1" style="color:#15140F">{a.canonical_nm}</p>
          {#if a.description_txt}
            <p class="text-sm leading-relaxed mb-2" style="color:#57534e">{a.description_txt}</p>
          {/if}
          <p class="text-xs mb-2" style="color:#a8a29e">{a.mentions_cnt} упоминани{a.mentions_cnt === 1 ? 'е' : a.mentions_cnt < 5 ? 'я' : 'й'} · последнее {fmtDate(a.last_dttm)}</p>
          <div class="flex items-center gap-3">
            <a href="/stories/{params.story}/actors/{a.actor_id}" class="text-xs font-medium" style="color:#C0401C">Публикации →</a>
          </div>
          {#if a.source_link || (a.photo_link && a.author_nm)}
            <p class="text-xs mt-2" style="color:#c4bca9">
              {#if a.photo_link && a.author_nm}фото: {a.author_nm}{#if a.license_nm} · {a.license_nm}{/if}{#if a.source_link} · {/if}{/if}{#if a.source_link}<a href={absUrl(a.source_link)} target="_blank" rel="noopener" style="color:#c4bca9; text-decoration:underline">источник</a>{/if}
            </p>
          {/if}
        </div>
      </div>
    {/if}
  {/key}
</div>
{/if}

{#if q_story_quotes.length > 0}
<!-- Вариант A из ревью «крупное фото»: портрет 52px + имя/должность — шапка карточки,
     сама цитата НЕ зажата в колонку рядом с фото (иначе под невысоким портретом
     остаётся пустое место) -- идёт отдельной строкой на всю ширину карточки.
     Без рамки-бокса, full-bleed (margin -12px гасит padding контейнера, как у
     «Действующих лиц»/«Хроники событий» выше) -- цитаты разделены волосяной линией,
     а не обёрнуты каждая в свою карточку.
     Заголовок — свой <h2> внутри этого же div (а не markdown ##), но того же размера
     20px/28px и с тем же отступом mt-2, что и у остальных заголовков блоков —
     единообразно со страницей. -->
<div class="not-prose mt-2 mb-8" style="margin-left:-12px; margin-right:-12px">
  <h2 style="margin:0 0 8px; padding:0 12px; font-size:20px; font-weight:600; line-height:28px; color:#15140F">Цитаты</h2>
  {#each q_story_quotes.slice(0, quotesVisibleCnt) as q, i (i)}
    <div class="px-3 py-3" style="border-top:{i === 0 ? 'none' : '1px solid #e7e5e4'}">
      <a href="/stories/{params.story}/actors/{q.actor_id}" class="flex items-center gap-3 mb-2.5 w-fit">
        {#if mediaUrl(q.photo_link) && !actorImgError[q.actor_id]}
          <!-- flex-shrink:0 обязателен: без него длинное двухстрочное description_txt (как у
               Зарифа) распирает строку шире доступной ширины, и flexbox сжимает фото по
               горизонтали (высота у него фиксирована инлайн-стилем и не сжимается вместе с
               шириной) — аватар выходит овалом вместо круга. -->
          <img src={mediaUrl(q.photo_link)} alt="" loading="lazy" draggable="false"
               style="width:52px; height:52px; flex-shrink:0; border-radius:50%; object-fit:cover; object-position:var(--actor-avatar-focus); display:block; border:1px solid #e7e5e4"
               on:error={() => { actorImgError[q.actor_id] = true; actorImgError = actorImgError; }} />
        {:else}
          <div style="width:52px; height:52px; flex-shrink:0; border-radius:50%; display:flex; align-items:center;
                       justify-content:center; background:#f0ede8; color:#a8a29e; font-size:16px; font-weight:600;
                       border:1px solid #e7e5e4">
            {initials(q.canonical_nm)}
          </div>
        {/if}
        <div class="min-w-0">
          <p class="text-sm font-bold leading-tight" style="color:#15140F">{q.canonical_nm}</p>
          {#if q.description_txt}
            <!-- Обрезаем длинное description_txt по 2 строкам с многоточием (как имя актёра
                 в аватар-ленте выше), а не даём ему распирать шапку карточки. -->
            <p class="text-xs mt-0.5" style="color:#a8a29e; display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:2; overflow:hidden">{q.description_txt}</p>
          {/if}
        </div>
      </a>
      <!-- Стандартное веб-выделение цитаты: курсив + акцентная полоса слева (blockquote),
           вместо ручных «кавычек» — полоса и так читается как маркер цитаты. -->
      <p class="text-sm leading-relaxed" style="color:#15140F; font-style:italic; border-left:3px solid #C0401C; padding-left:12px">{q.quote_txt}</p>
      <!-- Ссылку на источник пока убрали по просьбе — вернём в другом виде отдельно. -->
      <p class="text-xs mt-2" style="color:#a8a29e">{fmtDate(q.published_dttm)}&nbsp;·&nbsp;{q.feed_nm}</p>
    </div>
  {/each}
  {#if quotesVisibleCnt < q_story_quotes.length || quotesVisibleCnt > QUOTES_INITIAL_CNT}
    <!-- Подгрузка по QUOTES_PAGE_CNT (3), а не раскрытие всех сразу: каждый клик
         увеличивает quotesVisibleCnt, кнопка сама исчезает, когда показаны все.
         «Скрыть» — сворачивает обратно к QUOTES_INITIAL_CNT (1); появляется, только
         когда сейчас видно больше одной цитаты, независимо от того, есть ли ещё что
         подгружать. Без border-top: линии-разделители — только между самими цитатами
         (см. i === 0 выше), у последней цитаты перед этой строкой линии быть не должно. -->
    <div class="px-3 py-3 flex items-center gap-4">
      {#if quotesVisibleCnt < q_story_quotes.length}
        <button type="button"
          class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none"
          style="color:#a8a29e; background:none; border:none; padding:0"
          on:click={() => quotesVisibleCnt = Math.min(quotesVisibleCnt + QUOTES_PAGE_CNT, q_story_quotes.length)}>
          Показать ещё {Math.min(QUOTES_PAGE_CNT, q_story_quotes.length - quotesVisibleCnt)}
          <span style="display:inline-flex">
            <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
              <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </span>
        </button>
      {/if}
      {#if quotesVisibleCnt > QUOTES_INITIAL_CNT}
        <button type="button"
          class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none"
          style="color:#a8a29e; background:none; border:none; padding:0"
          on:click={() => quotesVisibleCnt = QUOTES_INITIAL_CNT}>
          Скрыть
          <span style="display:inline-flex; transform:rotate(180deg)">
            <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
              <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </span>
        </button>
      {/if}
    </div>
  {/if}
</div>
{/if}

## Хроника событий

{#if q_stories_summaries.length > 0}
<!-- margin-left/right отдельно, а не шорткатом "margin: 0 -12px" — тот заодно
     обнулял margin-bottom и гасил mb-8, из-за чего отступ перед «Прогнозом» ниже
     не коллапсировал до тех же 32px, что у остальных блоков (см. правку выше).
     mt-2, а не mt-4: отступ от заголовка до контента у всех остальных блоков (Ключевые
     события, Действующие лица, Прогноз, Карта событий) — 8px через mt-2; mt-4 здесь был
     единственным исключением и давал заметно больший зазор до карусели. -->
<div class="not-prose mt-2 mb-8" style="margin-left:-12px; margin-right:-12px">
  <!-- {#key params.story}: те же use:-экшены (dragScroll/autoScrollRight), что и
       в «Ключевых событиях» выше — без key при переходе между сюжетами по
       клиенту карусель не пересоздаётся и не спрыгивает к свежим карточкам. -->
  {#key params.story}
  <div class="chronicle-carousel" use:dragScroll use:autoScrollRight on:scroll={onChronicleScroll}
       bind:this={chronicleEl}>
    {#each visible as entry, i (entry.iso_dt)}
      {@const _p = entry.iso_dt.split('-')}
      {@const _day = parseInt(_p[2])}
      {@const _year = parseInt(_p[0])}
      {@const _mon = ['января','февраля','марта','апреля','мая','июня','июля','августа','сентября','октября','ноября','декабря'][parseInt(_p[1])-1]}

      <div class="chronicle-slide"
           use:tappable
           on:tap={() => goto(`/stories/${params.story}/${entry.iso_dt}`)}>

        <!-- Дата. padding-top не задаём: раньше 10px здесь давали в сумме с
             mt-2-коллапсом заметно больший отступ до заголовка, чем у остальных
             блоков (8px) — см. правку выше про Хронику событий. -->
        <div style="padding:0 0 6px 12px">
          <span style="display:inline-block; font-size:11px; font-weight:600; color:#faf9f7; background:#57534e; padding:3px 8px; border-radius:6px; letter-spacing:0.01em; white-space:nowrap">{_day} {_mon}{_year !== new Date().getFullYear() ? ' ' + _year : ''}</span>
        </div>

        <!-- Карточка -->
        <div class="rounded-xl border overflow-hidden"
             style="background:#faf9f7; border-color:#e7e5e4; margin:0 12px 12px 12px">
          <div class="px-4 py-3">

            {#if dayImages[entry.iso_dt] && !imgError[entry.iso_dt]}
              <div class="-mx-4 -mt-3 mb-3">
                <div style="aspect-ratio:16/9; background:#f5f4f2">
                  <img src={absUrl(dayImages[entry.iso_dt])} alt="" loading="lazy" draggable="false"
                       on:error={() => { imgError[entry.iso_dt] = true; imgError = imgError; }}
                       on:load={(e) => { if (e.target.naturalWidth < 300) { imgError[entry.iso_dt] = true; imgError = imgError; } }}
                       class="w-full h-full object-cover"
                       style="filter:grayscale({slideGrayscale[i] ?? 1}); transition:filter 0.3s ease; -webkit-user-drag:none" />
                </div>
              </div>
            {:else if q_story[0] && Number.isFinite(+q_story[0].geo_lat)}
              <div class="-mx-4 -mt-3 mb-3 overflow-hidden" style="aspect-ratio:16/9; background:#f5f4f2; isolation:isolate">
                <div use:leafletMap={{ lat: +q_story[0].geo_lat, lon: +q_story[0].geo_lon, zoom: 5 }}
                     style="height:100%; width:100%; filter:grayscale({slideGrayscale[i] ?? 1}); transition:filter 0.3s ease"></div>
              </div>
            {/if}

            <p class="text-sm font-semibold leading-snug mb-2"
               style="color:#15140F; min-height:5.5em; {expanded[entry.iso_dt] ? '' : 'display:-webkit-box; -webkit-box-orient:vertical; -webkit-line-clamp:4; overflow:hidden'}"
               >{entry.headline_txt}</p>

            {#if entry.summary_txt}
              {#if expanded[entry.iso_dt]}
                <div in:slide={{ duration: 320 }} out:slide={{ duration: 200 }}>
                  <p class="text-sm leading-relaxed mb-2" style="color:#57534e">{entry.summary_txt}</p>
                </div>
              {/if}
              <button type="button"
                class="inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none"
                style="color:#a8a29e; background:none; border:none; padding:0"
                on:pointerup|stopPropagation
                on:click|preventDefault|stopPropagation={() => { expanded[entry.iso_dt] = !expanded[entry.iso_dt]; expanded = expanded; }}>
                {expanded[entry.iso_dt] ? 'Скрыть' : 'Показать полностью'}
                <span style="display:inline-flex; transform:rotate({expanded[entry.iso_dt] ? '180deg' : '0deg'}); transition:transform 0.2s">
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
  {/key}

</div>
{:else}
<div class="not-prose mt-4 mb-8 p-6 bg-amber-50 border border-amber-200 rounded-xl">
  <p class="text-amber-800 text-sm">Ежедневные сводки новостей для этого сюжета пока не сформированы.</p>
</div>
{/if}

{#if q_forecasts.length > 0}

## Прогноз на {q_forecasts[0].horizon_days} дней

<!-- Ранжированные полосы (вариант C из брейншторма про блок «Прогноз»): одна плашка на
     все сценарии сразу, отсортированные по вероятности (q_forecasts уже ORDER BY
     p_posterior_prt DESC) — сравнение мгновенное, без свайпа карточек. Причина и график
     истории (как раньше под двумя иконками) теперь под одним тапом "Подробнее". -->
<div class="not-prose mt-2 mb-8">
  {#each q_forecasts as f, i}
    {@const delta = formatDelta(f.delta_pp)}
    {@const isOpen = openInfoId === f.forecast_id}
    {@const labelOutside = f.pct < 22}
    {@const history = q_forecasts_history.filter(r => r.forecast_id === f.forecast_id)}
    <div style="{i > 0 ? 'margin-top:18px' : ''}">
      <div class="flex items-baseline justify-between gap-2 mb-1.5">
        <p class="text-xs font-medium leading-snug" style="color:#57534e">{f.forecast_nm}</p>
        <p class="text-xs flex-shrink-0">
          {#if delta.arrow}<span style="color:{delta.arrowColor}">{delta.arrow}</span>{/if}
          <span style="color:{delta.textColor}"> {delta.text}</span>
        </p>
      </div>

      <div class="relative rounded-lg overflow-hidden" style="height:32px; background:#f5f4f2">
        <div class="absolute inset-y-0 left-0 rounded-lg" style="width:{f.pct}%; background:linear-gradient(to right, #C4162A, {barTopColor(f.pct / 100)})"></div>
        <!-- Подпись всегда якорится на край закрашенной части (pct%), а не трека —
             иначе на среднем заполнении (напр. 57%) "внутри" на деле попадало бы на
             незакрашенный серый хвост. Внутри — вплотную к правому краю заливки,
             белым; если заливка слишком узкая для текста — сразу за её краем, чёрным. -->
        <span class="absolute top-1/2 text-sm font-semibold tabular-nums"
              style="left:{f.pct}%; transform:translate({labelOutside ? '10px' : 'calc(-100% - 10px)'}, -50%); color:{labelOutside ? '#15140F' : '#faf9f7'}">{f.pct}%</span>
      </div>

      {#if f.forecast_txt || history.length > 1}
        <button type="button"
          class="mt-1.5 inline-flex items-center gap-1 text-xs font-medium cursor-pointer select-none"
          style="color:#a8a29e; background:none; border:none; padding:0"
          use:tappable on:tap={() => { openInfoId = isOpen ? null : f.forecast_id; }}>
          {isOpen ? 'Скрыть' : 'Подробнее'}
          <span style="display:inline-flex; transform:rotate({isOpen ? '180deg' : '0deg'}); transition:transform 0.2s">
            <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
              <polyline points="2,5 7,10 12,5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
            </svg>
          </span>
        </button>

        {#if isOpen}
          <div in:slide={{ duration: 220 }} out:slide={{ duration: 160 }}>
            {#if f.forecast_txt}
              <p class="text-xs leading-relaxed mt-2" style="color:#57534e">{f.forecast_txt}</p>
            {/if}
            {#if history.length > 1}
              <div style="width:100%; height:90px; margin-top:0.5rem">
                <ECharts config={forecastChart(history)} height="90px" />
              </div>
            {/if}
          </div>
        {/if}
      {/if}
    </div>
  {/each}
</div>

{/if}

## Карта событий

{#if q_story[0]}
<div class="not-prose mt-2 mb-10 rounded-xl border overflow-hidden" style="background:#ffffff; height:200px; border-color:#e7e5e4; isolation:isolate">
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

{#each q_stories_summaries as entry}
  <a href="/stories/{params.story}/{entry.iso_dt}" aria-hidden="true" tabindex="-1" style="display:none"></a>
{/each}

<!-- Ссылка на страницу актёра в разметке есть только внутри поповера (открывается
     по тапу), а он в статике при пререндере не раскрыт -- краулер SvelteKit её не
     находит. Без этого блока `/stories/[story]/actors/[actor]` не пререндерится и
     билд падает ("marked as prerenderable, but were not prerendered"). -->
{#each q_actors as a}
  <a href="/stories/{params.story}/actors/{a.actor_id}" aria-hidden="true" tabindex="-1" style="display:none"></a>
{/each}

</div>

<script>
  import { EvidenceDefaultLayout } from '@evidence-dev/core-components';
  import { onMount, setContext } from 'svelte';
  import { writable } from 'svelte/store';
  import { page } from '$app/stores';
  import { beforeNavigate, onNavigate, goto } from '$app/navigation';
  import { showQueries } from '@evidence-dev/component-utilities/stores';
  import '@evidence-dev/tailwind/fonts.css';
  import '../app.css';
  export let data;

  showQueries.set(false);

  // Та же "печатающаяся" анимация домена, что и на / (pages/index.md), но со своим
  // data-атрибутом — document.querySelectorAll там ищет [data-chronica-flag] по всему
  // документу, и без разных имён оба onMount запустили бы два таймера на одном узле.
  onMount(() => {
    const WORDS = ["AI", "MONEY", "TECH", "WAR", "LIFE", "WORLD", "ART", "DATA"];
    const TYPE_MS   = 95;
    const DELETE_MS = 55;
    const HOLD_MS   = 1300;
    const BLANK_MS  = 320;

    document.querySelectorAll('[data-cg-flag]').forEach((el) => {
      const flag     = el.closest('.c-desktop-gate-flag');
      const caret    = flag && flag.querySelector('.c-desktop-gate-caret');
      const setSolid = () => caret && caret.classList.add('is-typing');
      const setBlinking = () => {
        if (!caret) return;
        caret.classList.remove('is-typing');
        caret.style.animation = 'none';
        void caret.offsetWidth;
        caret.style.animation = '';
      };

      let idx = 0, text = el.textContent || WORDS[0], phase = "hold";
      const tick = () => {
        const word = WORDS[idx];
        if (phase === "typing") {
          setSolid();
          if (text.length < word.length) {
            text = word.slice(0, text.length + 1);
            el.textContent = text;
            setTimeout(tick, TYPE_MS);
          } else { phase = "hold"; setBlinking(); setTimeout(tick, HOLD_MS); }
        } else if (phase === "hold") {
          phase = "deleting"; setTimeout(tick, DELETE_MS);
        } else if (phase === "deleting") {
          setSolid();
          if (text.length > 0) {
            text = text.slice(0, -1);
            el.textContent = text;
            setTimeout(tick, DELETE_MS);
          } else { phase = "blank"; setBlinking(); setTimeout(tick, BLANK_MS); }
        } else if (phase === "blank") {
          idx = (idx + 1) % WORDS.length;
          phase = "typing"; tick();
        }
      };
      setTimeout(tick, HOLD_MS);
    });
  });

  // Ссылается на window.Telegram.WebApp после загрузки скрипта — используется в реактивном
  // блоке ниже (после объявления parentUrl), чтобы показывать/прятать нативную кнопку "назад".
  let tgWebApp = null;

  // Мобильный встроенный браузер Telegram рисует свою панель (Закрыть/⋯) поверх страницы,
  // её высоту не отдаёт ни один safe-area API для обычных (не мини-апп) ссылок — добавляем
  // фиксированный отступ вручную, только когда точно определили, что мы внутри Telegram.
  onMount(() => {
    const ua = navigator.userAgent || '';
    const isMobile = /Android|iPhone|iPad/i.test(ua);
    const isTelegram = /Telegram/i.test(ua) || typeof window.TelegramWebviewProxy !== 'undefined';
    if (isMobile && isTelegram) {
      document.documentElement.classList.add('tg-inapp');

      // Пробуем официальный способ отключить нативный жест "смахнуть вниз = свернуть
      // приложение" — обычно доступен только зарегистрированным мини-приложениям, но
      // мост в WebView Telegram общий, так что стоит попробовать и для обычной ссылки.
      const script = document.createElement('script');
      script.src = 'https://telegram.org/js/telegram-web-app.js';
      script.async = true;
      script.onload = () => {
        try {
          const tg = window.Telegram?.WebApp;
          if (!tg) return;
          tg.ready?.();
          tg.disableVerticalSwipes?.();
          // Свайп от левого края в Telegram зарезервирован системой (см. документацию
          // Telegram Mini Apps — "go back" жест на вебвью официально не поддерживается),
          // поэтому вместо своего edge-свайпа используем нативную кнопку "назад".
          tg.BackButton?.onClick(() => { if (parentUrl) goto(parentUrl); });
          tgWebApp = tg;
        } catch (e) {}
      };
      document.head.appendChild(script);
    }
  });

  const breadcrumbStore = writable(null);
  setContext('breadcrumb', breadcrumbStore);

  $: { $page.route?.id; breadcrumbStore.set(null); }

  $: storyId = $page.params?.story;
  $: day = $page.params?.day;
  $: parentUrl = day ? `/stories/${storyId}` : storyId ? '/stories' : '/';
  $: isHome = $page.url.pathname === '/';
  $: if (tgWebApp) {
    if (isHome) tgWebApp.BackButton.hide();
    else tgWebApp.BackButton.show();
  }

  let _goingUp = false;
  beforeNavigate((nav) => {
    if (_goingUp || !nav.from || !nav.to) return;
    if (nav.type === 'link' || nav.type === 'goto') {
      const fromDepth = nav.from.url.pathname.split('/').filter(Boolean).length;
      const toDepth = nav.to.url.pathname.split('/').filter(Boolean).length;
      if (toDepth < fromDepth) {
        nav.cancel();
        _goingUp = true;
        goto(nav.to.url.pathname, { replaceState: true }).finally(() => { _goingUp = false; });
      }
    }
  });

  onNavigate((nav) => {
    if (!document.startViewTransition) return;
    const fromDepth = nav.from?.url.pathname.split('/').filter(Boolean).length ?? 0;
    const toDepth = nav.to?.url.pathname.split('/').filter(Boolean).length ?? 0;
    document.documentElement.dataset.navDir = toDepth < fromDepth ? 'back' : 'forward';
    return new Promise((resolve) => {
      document.startViewTransition(() => resolve());
    });
  });

  let menuOpen = false;
  function closeMenu() { menuOpen = false; }

  // Список дублирует сид dds.s_story_categories — в боковом меню он зашит статично,
  // т.к. +layout.svelte не страница и не может выполнить sql-запрос к БД.
  const SIDEBAR_CATEGORIES = [
    { nm: 'geopolitics', label: 'Геополитика' },
    { nm: 'companies',   label: 'Компании' },
  ];

  // Реальные заголовки для бегущей строки на десктопной заглушке — снимок из БД на
  // 2026-08-02 (см. dm.story_summaries_d), а не выдуманные примеры. Не живые: +layout.svelte
  // не страница и не может выполнить sql-запрос к БД (см. выше), поэтому не обновляются
  // автоматически — освежать руками по мере того, как список сюжетов меняется.
  const TICKER_ITEMS = [
    'Конфликт в Персидском заливе — Эр-Рияд просит США не наносить новые удары по Ирану',
    'Россия и Украина — ракетный удар по Киеву, США анонсировали новый раунд переговоров',
    'Лукойл (LKOH) — Болгария признала активы Лукойла объектами нацбезопасности',
    'Газпром (GAZP) — построено более 8 тыс. км газопроводов на востоке России',
    'Московская биржа (MOEX) — индекс вырос на 2% на фоне цен на нефть',
    'Яндекс (YDEX) — аналитики оценивают риски и перспективы акций',
    'Сбербанк (SBER) — отчёт за II квартал: качество портфеля ухудшилось',
    'Т-Технологии (T) — переводы в ближнее зарубежье выросли на 15%',
    'Алроса (ALRS) — чистый убыток 10,7 млрд руб. по РСБУ за полугодие',
    'Норникель (GMKN) — рекордная выручка за первое полугодие',
    'Магнит (MGNT) — маркетплейс «Магнит Маркет» закрывается с 6 сентября',
  ];
  const tickerLoop = [...TICKER_ITEMS, ...TICKER_ITEMS];

  function swipeBack(node, url) {
    let currentUrl = url;
    let active = false, startX = 0, startY = 0;
    const EDGE = 24, MIN = 60;
    function down(e) {
      if (e.pointerType === 'mouse') return;
      if (e.clientX > EDGE) return;
      active = true; startX = e.clientX; startY = e.clientY;
    }
    function up(e) {
      if (!active) return;
      active = false;
      const dx = e.clientX - startX, dy = e.clientY - startY;
      if (dx > MIN && Math.abs(dx) > Math.abs(dy) * 1.5 && currentUrl) {
        goto(currentUrl);
      }
    }
    window.addEventListener('pointerdown', down);
    window.addEventListener('pointerup', up);
    return {
      update(newUrl) { currentUrl = newUrl; },
      destroy() {
        window.removeEventListener('pointerdown', down);
        window.removeEventListener('pointerup', up);
      }
    };
  }

  function formatDay(d) {
    if (!d) return '';
    const parts = d.split('-').map(Number);
    const m = parts[1], d2 = parts[2];
    const M = ['янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
    return `${d2} ${M[m - 1]}`;
  }
</script>

<svelte:head>
  <link rel="manifest" href="/manifest.json" />
  <meta name="apple-mobile-web-app-title" content="Chronica" />
  <link rel="apple-touch-icon" href="/logo.svg" />
  <meta name="theme-color" content="#faf9f7" />
  <!-- viewport-fit=cover: без этого env(safe-area-inset-top) всегда 0, и фикс ниже для Telegram WebView не сработает -->
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
  <!-- Для c-desktop-gate ниже — те же шрифты, что и на / -->
  <link href="https://fonts.googleapis.com/css2?family=Archivo:wght@800&family=IBM+Plex+Mono:wght@500&display=swap" rel="stylesheet">
</svelte:head>

<!-- Десктопная заглушка: сайт делается под мобильные устройства, на широких экранах
     с мышью вместо мобильного UI показываем визитку с переходом в Telegram-бота.
     Чистый CSS (media query по ширине + pointer:fine) — без редиректа и JS,
     работает даже на пререндеренном статическом сайте. -->
<div class="c-desktop-gate">
  <div class="c-desktop-gate-inner">
    <span class="c-desktop-gate-flag">
      <span class="c-desktop-gate-word">CHRONICA</span>
      <span class="c-desktop-gate-badge">
        <span class="c-desktop-gate-dot">.</span><span class="c-desktop-gate-suffix" data-cg-flag>AI</span><span class="c-desktop-gate-caret" aria-hidden="true"></span>
      </span>
    </span>
    <p class="c-desktop-gate-tagline">
      Собираем материалы из открытых источников, группируем по темам и формируем
      ежедневные сводки — чтобы следить за событиями без лишнего шума.
    </p>
    <div class="c-desktop-gate-ticker">
      <div class="c-desktop-gate-ticker-track">
        {#each tickerLoop as item}
          <span class="c-desktop-gate-ticker-item">{item}</span>
          <span class="c-desktop-gate-ticker-sep">·</span>
        {/each}
      </div>
    </div>
    <a href="https://t.me/signalfire_aibot" target="_blank" rel="noopener" class="c-desktop-gate-cta">
      Открыть в Telegram →
    </a>
  </div>
</div>

<!-- Затемнение -->
<div class="c-backdrop" class:c-backdrop-open={menuOpen} on:click={closeMenu} aria-hidden="true"></div>

<!-- Боковое меню -->
<aside class="c-sidebar" class:c-sidebar-open={menuOpen}>
  <div class="c-sidebar-top">
    <img src="/logo.svg" alt="Chronica" class="c-sidebar-logo" />
  </div>
  <nav class="c-sidebar-nav">
    <a href="/" on:click={closeMenu}>
      <svg width="18" height="18" viewBox="0 0 20 20" fill="none">
        <path d="M3 9.5L10 3L17 9.5V17H13V13H7V17H3V9.5Z" stroke="#78716c" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round"/>
      </svg>
      Главная
    </a>
    <a href="/stories" on:click={closeMenu}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#78716c" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5l6.74-6.76z"/>
        <line x1="16" y1="8" x2="2" y2="22"/>
        <line x1="17.5" y1="15" x2="9" y2="15"/>
      </svg>
      Сюжеты
    </a>
    {#each SIDEBAR_CATEGORIES as cat}
      <a href="/stories?category={cat.nm}" class="c-sidebar-sub" on:click={closeMenu}>
        {cat.label}
      </a>
    {/each}

    <div class="c-sidebar-divider"></div>

    <div class="c-sidebar-disabled" aria-disabled="true" tabindex="-1">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#a8a29e" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <circle cx="12" cy="12" r="10"/>
        <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
        <line x1="12" y1="17" x2="12.01" y2="17"/>
      </svg>
      Поддержка
    </div>
    <div class="c-sidebar-disabled" aria-disabled="true" tabindex="-1">
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#a8a29e" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
        <circle cx="12" cy="7" r="4"/>
      </svg>
      Профиль
    </div>
  </nav>
</aside>

<!-- Хедер -->
<div class="c-header" use:swipeBack={parentUrl}>
  <button class="c-hamburger" on:click={() => menuOpen = true} aria-label="Открыть меню">
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
      <rect x="2" y="4" width="16" height="2" rx="1" fill="#57534e"/>
      <rect x="2" y="9" width="16" height="2" rx="1" fill="#57534e"/>
      <rect x="2" y="14" width="16" height="2" rx="1" fill="#57534e"/>
    </svg>
  </button>
  {#if storyId || $page.url.pathname === '/stories'}
    <nav class="c-breadcrumb">
      {#if !storyId}
        <span class="c-current">Сюжеты</span>
      {:else if !day}
        <a href="/stories">Сюжеты</a>
        {#if $breadcrumbStore?.storyName}
          <span class="c-sep">›</span>
          <span class="c-current">{$breadcrumbStore.storyName}</span>
        {/if}
      {:else}
        <a href="/stories">Сюжеты</a>
        <span class="c-sep">›</span>
        <a href="/stories/{storyId}" class="c-trunc">{$breadcrumbStore?.storyName || '…'}</a>
        <span class="c-sep">›</span>
        <span class="c-day">{formatDay(day)}</span>
      {/if}
    </nav>
  {/if}
</div>

<!-- Выталкивает контент ровно на ту дельту, на которую .c-header вырос сверх базовых 48px
     (safe-area-inset-top / панель Telegram) — сам .c-header зафиксирован и из потока выпадает,
     а Evidence резервирует под него статичные 48px. В обычном браузере высота спейсера 0. -->
<div class="c-header-spacer" aria-hidden="true"></div>

<EvidenceDefaultLayout {data} logo="/logo.svg">
  <slot slot="content" />
</EvidenceDefaultLayout>

<!-- Нижний "остров" — быстрая навигация -->
<nav class="c-island" aria-label="Основная навигация">
  <a href="/" class="c-island-item" class:c-island-active={$page.url.pathname === '/'}>
    <svg width="22" height="22" viewBox="0 0 20 20" fill="none">
      <path d="M3 9.5L10 3L17 9.5V17H13V13H7V17H3V9.5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/>
    </svg>
    <span>Главная</span>
  </a>
  <a href="/stories" class="c-island-item" class:c-island-active={$page.url.pathname.startsWith('/stories')}>
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
      <path d="M20.24 12.24a6 6 0 0 0-8.49-8.49L5 10.5V19h8.5l6.74-6.76z"/>
      <line x1="16" y1="8" x2="2" y2="22"/>
      <line x1="17.5" y1="15" x2="9" y2="15"/>
    </svg>
    <span>Сюжеты</span>
  </a>
  <div class="c-island-item c-island-disabled" aria-disabled="true" tabindex="-1">
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"/>
      <path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/>
      <line x1="12" y1="17" x2="12.01" y2="17"/>
    </svg>
    <span>Поддержка</span>
  </div>
  <div class="c-island-item c-island-disabled" aria-disabled="true" tabindex="-1">
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
      <circle cx="12" cy="7" r="4"/>
    </svg>
    <span>Профиль</span>
  </div>
</nav>

<style>
  /* Единая шкала z-index на весь сайт — используйте переменные вместо чисел на любой
     странице (доступны глобально через :root). Виджеты со своими внутренними z-index
     (карты, карусели, таймлайны) обязаны иметь isolation:isolate на обёртке — тогда их
     локальные цифры замкнуты внутри и не могут конкурировать с этой шкалой в принципе. */
  :global(:root) {
    --z-content-raised: 10; /* элемент обычного контента, которому временно нужно быть
                                выше окружения (напр. открытая обёртка поповера) */
    --z-scrim: 40;          /* полноэкранный перехватчик кликов "вне попап-меню" */
    --z-header: 50;         /* верхний хедер */
    --z-island: 60;         /* нижний плавающий остров-навигация */
    --z-popover: 70;        /* открытые дропдауны/поповеры — должны быть выше хедера и острова */
    --z-backdrop: 98;       /* затемнение под боковым меню */
    --z-sidebar: 99;        /* само боковое меню */
    --z-desktop-gate: 999;  /* десктопная заглушка — выше вообще всего на сайте */
  }
  :global(header) { display: none !important; }
  :global(html), :global(body) {
    background-color: #faf9f7;
    overscroll-behavior-y: none;
    min-height: 100dvh;
  }
  :global(.antialiased > div) {
    padding-left: 12px !important;
    padding-right: 12px !important;
    /* Место под плавающий остров-навигацию снизу (64px высота + отступ от края + запас) */
    padding-bottom: calc(100px + env(safe-area-inset-bottom, 0px)) !important;
  }

  /* Затемнение */
  .c-backdrop {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0);
    z-index: var(--z-backdrop);
    pointer-events: none;
    transition: background 0.3s ease;
  }
  .c-backdrop-open {
    background: rgba(0, 0, 0, 0.35);
    pointer-events: auto;
  }

  /* Боковое меню */
  .c-sidebar {
    position: fixed;
    top: 0; left: 0; bottom: 0;
    width: max-content;
    min-width: 180px;
    background: #faf9f7;
    z-index: var(--z-sidebar);
    transform: translateX(-100%);
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: 4px 0 32px rgba(0, 0, 0, 0.08);
    display: flex;
    flex-direction: column;
    padding-top: env(safe-area-inset-top, 0px);
  }
  :global(html.tg-inapp) .c-sidebar {
    padding-top: calc(env(safe-area-inset-top, 0px) + 44px);
  }
  .c-sidebar-open {
    transform: translateX(0);
  }
  .c-sidebar-top {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 48px;
    padding: 0 16px;
    border-bottom: 1px solid #f0ede9;
    flex-shrink: 0;
  }
  .c-sidebar-logo {
    height: 128px;
    width: 128px;
  }
  .c-sidebar-nav {
    padding: 12px 8px;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .c-sidebar-nav a {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    border-radius: 8px;
    text-decoration: none;
    font-size: 15px;
    color: #15140F;
    transition: background 0.15s ease;
  }
  .c-sidebar-nav a:active {
    background: #f0ede9;
  }
  .c-sidebar-nav svg {
    flex-shrink: 0;
  }
  .c-sidebar-sub {
    padding-left: 40px !important;
    font-size: 14px !important;
    color: #57534e !important;
  }
  .c-sidebar-divider {
    height: 1px;
    background: #f0ede9;
    margin: 8px 4px;
    flex-shrink: 0;
  }
  .c-sidebar-disabled {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    border-radius: 8px;
    font-size: 15px;
    color: #a8a29e;
    cursor: default;
  }
  .c-sidebar-disabled svg {
    flex-shrink: 0;
  }

  /* Хедер */
  .c-header {
    position: fixed;
    top: 0; left: 0; right: 0;
    box-sizing: border-box;
    /* высота растёт на safe-area-inset-top (статус-бар в Telegram WebView и т.п.),
       содержимое хедера при этом остаётся тех же ~48px за счёт padding-top */
    height: calc(48px + env(safe-area-inset-top, 0px));
    padding: 0 12px;
    padding-top: env(safe-area-inset-top, 0px);
    background: #ffffff;
    border-bottom: 1px solid #f0ede9;
    z-index: var(--z-header);
    display: flex;
    align-items: center;
    gap: 8px;
    view-transition-name: c-header;
  }
  :global(html.tg-inapp) .c-header {
    height: calc(48px + env(safe-area-inset-top, 0px) + 44px);
    padding-top: calc(env(safe-area-inset-top, 0px) + 44px);
  }
  .c-header-spacer {
    height: env(safe-area-inset-top, 0px);
    flex-shrink: 0;
  }
  :global(html.tg-inapp) .c-header-spacer {
    height: calc(env(safe-area-inset-top, 0px) + 44px);
  }
  :global(::view-transition-old(c-header)),
  :global(::view-transition-new(c-header)) {
    animation: none;
  }
  .c-hamburger {
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    padding: 4px;
    cursor: pointer;
    flex-shrink: 0;
    border-radius: 6px;
  }
  .c-hamburger:active {
    background: #f0ede9;
  }
  .c-breadcrumb {
    display: flex;
    align-items: center;
    gap: 4px;
    min-width: 0;
    overflow: hidden;
    font-size: 12px;
    flex: 1;
  }
  .c-breadcrumb a {
    color: #78716c;
    white-space: nowrap;
    text-decoration: none;
    flex-shrink: 0;
  }
  .c-trunc {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-shrink: 1;
    min-width: 0;
  }
  .c-sep { color: #a8a29e; flex-shrink: 0; }
  .c-current {
    color: #15140F;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    flex-shrink: 1;
  }
  .c-day { color: #15140F; white-space: nowrap; flex-shrink: 0; }

  /* Нижний остров-навигация */
  .c-island {
    position: fixed;
    left: 50%;
    bottom: calc(14px + env(safe-area-inset-bottom, 0px));
    transform: translateX(-50%);
    z-index: var(--z-island);
    display: flex;
    align-items: stretch;
    width: calc(100% - 24px);
    max-width: 360px;
    height: 64px;
    padding: 6px;
    border-radius: 28px;
    background: rgba(250, 249, 247, 0.72);
    backdrop-filter: blur(20px) saturate(180%);
    -webkit-backdrop-filter: blur(20px) saturate(180%);
    border: 1px solid rgba(255, 255, 255, 0.6);
    box-shadow: 0 8px 32px rgba(21, 20, 15, 0.14), 0 1px 2px rgba(21, 20, 15, 0.06);
  }
  .c-island-item {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 3px;
    border-radius: 22px;
    text-decoration: none;
    color: #57534e;
    transition: color 0.15s ease, background 0.15s ease;
  }
  .c-island-item span {
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.01em;
    line-height: 1;
  }
  a.c-island-item:active {
    background: rgba(21, 20, 15, 0.06);
  }
  .c-island-active {
    color: #C0401C;
  }
  .c-island-disabled {
    color: #a8a29e;
    opacity: 0.55;
    cursor: default;
  }

  @keyframes slide-in-right { from { transform: translateX(100%); } }
  @keyframes slide-out-left  { to   { transform: translateX(-28%); opacity: 0.6; } }
  @keyframes slide-in-left   { from { transform: translateX(-28%); opacity: 0.6; } }
  @keyframes slide-out-right { to   { transform: translateX(100%); } }

  :global(html[data-nav-dir="forward"]::view-transition-old(root)) {
    animation: slide-out-left 0.32s cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(html[data-nav-dir="forward"]::view-transition-new(root)) {
    animation: slide-in-right 0.32s cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(html[data-nav-dir="back"]::view-transition-old(root)) {
    animation: slide-out-right 0.32s cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(html[data-nav-dir="back"]::view-transition-new(root)) {
    animation: slide-in-left 0.32s cubic-bezier(0.4, 0, 0.2, 1);
  }

  /* Десктопная заглушка — скрыта по умолчанию (мобильный UI — основной сценарий),
     показывается только на широких экранах с мышью/трекпадом. */
  .c-desktop-gate {
    display: none;
  }
  @media (min-width: 900px) and (pointer: fine) {
    .c-desktop-gate {
      display: flex;
      position: fixed;
      inset: 0;
      z-index: var(--z-desktop-gate);
      align-items: center;
      justify-content: center;
      padding: 40px;
      background:
        radial-gradient(ellipse at top, rgba(192, 64, 28, 0.08), transparent 60%),
        #faf9f7;
    }
  }
  .c-desktop-gate-inner {
    max-width: 560px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 20px;
    text-align: center;
  }
  .c-desktop-gate-flag {
    display: inline-flex;
    align-items: flex-end;
    gap: 14px;
  }
  .c-desktop-gate-word {
    font-family: 'Archivo', sans-serif;
    font-weight: 800;
    font-size: 56px;
    letter-spacing: 0.01em;
    line-height: 1;
    color: #16140F;
  }
  .c-desktop-gate-badge {
    display: inline-flex;
    align-items: center;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    font-size: 15px;
    letter-spacing: 0.1em;
    line-height: 1;
    color: #F1EADB;
    background: #C0401C;
    padding: 7px 10px;
    min-width: 6em;
  }
  .c-desktop-gate-dot { opacity: 0.72; }
  .c-desktop-gate-suffix { white-space: pre; }
  .c-desktop-gate-caret {
    display: inline-block;
    width: 0.09em;
    height: 1.05em;
    background: #F1EADB;
    margin-left: 0.16em;
    animation: cg-blink 1.06s ease infinite;
  }
  :global(.c-desktop-gate-caret.is-typing) { animation: none; opacity: 1; }
  @keyframes cg-blink {
    0%,  45% { opacity: 1; }
    55%, 95% { opacity: 0; }
    100%     { opacity: 1; }
  }
  .c-desktop-gate-tagline {
    margin: 0;
    font-size: 16px;
    line-height: 1.6;
    color: #44403c;
  }
  .c-desktop-gate-ticker {
    width: 100%;
    max-width: 640px;
    overflow: hidden;
    -webkit-mask-image: linear-gradient(to right, transparent, black 8%, black 92%, transparent);
    mask-image: linear-gradient(to right, transparent, black 8%, black 92%, transparent);
  }
  .c-desktop-gate-ticker-track {
    display: flex;
    align-items: center;
    width: max-content;
    gap: 14px;
    animation: cg-marquee 34s linear infinite;
  }
  .c-desktop-gate-ticker-item {
    font-family: 'IBM Plex Mono', monospace;
    font-size: 12px;
    letter-spacing: 0.02em;
    color: #78716c;
    white-space: nowrap;
  }
  .c-desktop-gate-ticker-sep {
    font-size: 12px;
    color: #d6d3d1;
  }
  @keyframes cg-marquee {
    from { transform: translateX(0); }
    to   { transform: translateX(-50%); }
  }
  .c-desktop-gate-cta {
    display: inline-block;
    margin-top: 8px;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    font-size: 14px;
    letter-spacing: 0.06em;
    color: #F1EADB;
    background: #C0401C;
    padding: 14px 36px;
    text-decoration: none;
    transition: background 0.2s ease, transform 0.15s ease;
  }
  .c-desktop-gate-cta:hover {
    background: #a33618;
    transform: translateY(-1px);
  }

  /* Появление блоков по очереди при открытии заглушки */
  @keyframes cg-fade-up {
    from { opacity: 0; transform: translateY(10px); }
    to   { opacity: 1; transform: translateY(0); }
  }
  .c-desktop-gate-flag,
  .c-desktop-gate-tagline,
  .c-desktop-gate-ticker,
  .c-desktop-gate-cta {
    animation: cg-fade-up 0.6s cubic-bezier(0.22, 1, 0.36, 1) both;
  }
  .c-desktop-gate-flag    { animation-delay: 0s; }
  .c-desktop-gate-tagline { animation-delay: 0.1s; }
  .c-desktop-gate-ticker  { animation-delay: 0.2s; }
  .c-desktop-gate-cta     { animation-delay: 0.3s; }

  @media (prefers-reduced-motion: reduce) {
    .c-desktop-gate-ticker-track {
      animation: none;
    }
    .c-desktop-gate-flag,
    .c-desktop-gate-tagline,
    .c-desktop-gate-ticker,
    .c-desktop-gate-cta {
      animation: none;
    }
  }
</style>

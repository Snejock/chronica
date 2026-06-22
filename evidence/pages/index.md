---
full_width: false
hide_breadcrumbs: true
---

<script>
  let pageEl;

  onMount(() => {
    const WORDS = ["AI", "MONEY", "TECH", "WAR", "LIFE", "WORLD", "ART", "DATA"];
    const TYPE_MS   = 95;
    const DELETE_MS = 55;
    const HOLD_MS   = 1300;
    const BLANK_MS  = 320;
    const cleanups  = [];

    document.querySelectorAll('[data-chronica-flag]').forEach((el) => {
      const flag     = el.closest('.cf-flag');
      const caret    = flag && flag.querySelector('.cf-caret');
      const setSolid = () => caret && caret.classList.add('is-typing');
      const setBlinking = () => {
        if (!caret) return;
        caret.classList.remove('is-typing');
        caret.style.animation = 'none';
        void caret.offsetWidth;
        caret.style.animation = '';
      };

      let idx = 0, text = el.textContent || WORDS[0], phase = "hold";
      let timerId;
      const tick = () => {
        const word = WORDS[idx];
        if (phase === "typing") {
          setSolid();
          if (text.length < word.length) {
            text = word.slice(0, text.length + 1);
            el.textContent = text;
            timerId = setTimeout(tick, TYPE_MS);
          } else { phase = "hold"; setBlinking(); timerId = setTimeout(tick, HOLD_MS); }
        } else if (phase === "hold") {
          phase = "deleting"; timerId = setTimeout(tick, DELETE_MS);
        } else if (phase === "deleting") {
          setSolid();
          if (text.length > 0) {
            text = text.slice(0, -1);
            el.textContent = text;
            timerId = setTimeout(tick, DELETE_MS);
          } else { phase = "blank"; setBlinking(); timerId = setTimeout(tick, BLANK_MS); }
        } else if (phase === "blank") {
          idx = (idx + 1) % WORDS.length;
          phase = "typing"; tick();
        }
      };
      timerId = setTimeout(tick, HOLD_MS);
      cleanups.push(() => clearTimeout(timerId));
    });

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
      cleanups.forEach(fn => fn());
      document.removeEventListener('touchstart', onTouchStart);
      document.removeEventListener('touchmove',  onTouchMove);
      document.removeEventListener('touchend',   onTouchEnd);
      document.removeEventListener('touchcancel', onTouchEnd);
    };
  });
</script>

<link href="https://fonts.googleapis.com/css2?family=Archivo:wght@800&family=IBM+Plex+Mono:wght@500&display=swap" rel="stylesheet">

<style>
  .chronica-flag {
    display: inline-flex;
    align-items: flex-end;
    gap: 12px;
    font-size: 40px;
    color: #16140F;
  }
  .chronica-flag .cf-word {
    font-family: 'Archivo', sans-serif;
    font-weight: 800;
    font-size: 1em;
    letter-spacing: 0.01em;
    line-height: 1;
    white-space: nowrap;
  }
  .chronica-flag .cf-flag {
    display: inline-flex;
    align-items: center;
    background: #C0401C;
    color: #F1EADB;
    font-family: 'IBM Plex Mono', monospace;
    font-weight: 500;
    font-size: 0.343em;
    letter-spacing: 0.1em;
    line-height: 1;
    padding: 0.27em 0.45em;
    min-width: 6em;
  }
  .chronica-flag .cf-dot { opacity: 0.72; }
  .chronica-flag .cf-suffix { white-space: pre; }
  .chronica-flag .cf-caret {
    display: inline-block;
    width: 0.09em;
    height: 1.05em;
    background: #F1EADB;
    margin-left: 0.16em;
    animation: cf-blink 1.06s ease infinite;
  }
  :global(.cf-caret.is-typing) { animation: none; opacity: 1; }
  @keyframes cf-blink {
    0%,  45% { opacity: 1; }
    55%, 95% { opacity: 0; }
    100%     { opacity: 1; }
  }
  @media (min-width: 640px) {
    .chronica-flag { font-size: 64px; gap: 16px; }
  }
  @media (prefers-reduced-motion: reduce) {
    .chronica-flag .cf-caret { animation: none; opacity: 1; }
  }
</style>

<div bind:this={pageEl}>
<div class="not-prose flex flex-col items-center mt-16 mb-12">

  <span class="chronica-flag" aria-label="CHRONICA">
    <span class="cf-word">CHRONICA</span>
    <span class="cf-flag">
      <span class="cf-dot">.</span><span class="cf-suffix" data-chronica-flag>AI</span><span class="cf-caret" aria-hidden="true"></span>
    </span>
  </span>

  <p class="text-gray-400 text-xs leading-relaxed mt-16 max-w-lg text-center">
    Собираем материалы из открытых источников, группируем по темам и формируем ежедневные сводки — чтобы следить за событиями без лишнего шума.
  </p>

</div>
</div>

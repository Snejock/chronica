---
title: Эскалация в Персидском заливе
---

<script>
  onMount(() => {
    function updateDotColors() {
      const vh = window.innerHeight;
      document.querySelectorAll('.timeline-dot').forEach(dot => {
        const rect = dot.getBoundingClientRect();
        const ratio = Math.max(0, Math.min(1, (rect.top + rect.height / 2) / vh));
        // ratio=0 (top) → red #b44a38, ratio=1 (bottom) → beige #c4bca9
        const r = Math.round(180 + (196 - 180) * ratio);
        const g = Math.round(74  + (188 - 74)  * ratio);
        const b = Math.round(56  + (169 - 56)  * ratio);
        dot.style.backgroundColor = `rgb(${r},${g},${b})`;
      });
    }

    updateDotColors();
    window.addEventListener('scroll', updateDotColors, { passive: true });
    return () => window.removeEventListener('scroll', updateDotColors);
  });
</script>

```sql chronicle
SELECT
    dt
    , strftime(dt, '%d') || ' ' ||
      CASE EXTRACT(month FROM dt)
        WHEN 1  THEN 'января'
        WHEN 2  THEN 'февраля'
        WHEN 3  THEN 'марта'
        WHEN 4  THEN 'апреля'
        WHEN 5  THEN 'мая'
        WHEN 6  THEN 'июня'
        WHEN 7  THEN 'июля'
        WHEN 8  THEN 'августа'
        WHEN 9  THEN 'сентября'
        WHEN 10 THEN 'октября'
        WHEN 11 THEN 'ноября'
        WHEN 12 THEN 'декабря'
      END || ' ' || strftime(dt, '%Y') AS formatted_dt
    , headline_txt
    , summary_txt
FROM dwh_pg_1.s_story_daily_summaries
WHERE language_code = 'ru'
  AND story_id = 1
ORDER BY dt DESC
```

## Хроника событий

{#if chronicle.length > 0}
<div class="not-prose mt-4 relative">
  <div class="absolute left-0 top-0 bottom-0 w-px bg-[#c4bca9]"></div>
  {#each chronicle as entry, i}
    <div class="relative pl-4 mb-4">
      <div class="timeline-dot absolute left-0 top-5 w-2 h-2 rounded-full -translate-x-1/2 ring-2 ring-white" style="background-color:#c4bca9"></div>
      <div class="bg-white rounded-r-xl shadow-sm pl-5 pr-5 py-4">
        <p class="text-xs uppercase tracking-wide text-stone-400 mb-1">{entry.formatted_dt}</p>
        <p class="text-base font-medium text-gray-900 mb-2">{entry.headline_txt}</p>
        <input type="checkbox" id="exp-{i}" class="hidden peer">
        <p class="text-gray-600 leading-relaxed text-sm line-clamp-5 peer-checked:line-clamp-none">{entry.summary_txt}</p>
        <label for="exp-{i}" class="peer-checked:hidden text-xs text-[#c4bca9] mt-2 block cursor-pointer hover:text-stone-500">читать далее →</label>
        <label for="exp-{i}" class="hidden peer-checked:block text-xs text-[#c4bca9] mt-2 cursor-pointer hover:text-stone-500">скрыть ↑</label>
      </div>
    </div>
  {/each}
</div>
{:else}
<div class="not-prose mt-4 p-6 bg-amber-50 border border-amber-200 rounded-xl">
  <p class="text-amber-800 text-sm">Ежедневные сводки новостей для этого сюжета пока не сформированы.</p>
</div>
{/if}
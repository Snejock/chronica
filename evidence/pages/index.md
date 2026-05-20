---
---

<script>
  onMount(() => {
    const WORDS = [
      "life", "war", "art", "tech", "ai",
      "now", "love", "money", "power", "truth",
      "time", "code", "news", "mind", "world"
    ];
    const TYPE_MS   = 95;
    const DELETE_MS = 55;
    const HOLD_MS   = 1500;
    const BLANK_MS  = 320;

    document.querySelectorAll('[data-chronica-suffix]').forEach((el) => {
      let idx = 0, text = el.textContent || WORDS[0], phase = "hold";
      const tick = () => {
        const word = WORDS[idx];
        if (phase === "typing") {
          if (text.length < word.length) {
            text = word.slice(0, text.length + 1);
            el.textContent = text;
            setTimeout(tick, TYPE_MS);
          } else { phase = "hold"; setTimeout(tick, HOLD_MS); }
        } else if (phase === "hold") {
          phase = "deleting"; setTimeout(tick, DELETE_MS);
        } else if (phase === "deleting") {
          if (text.length > 0) {
            text = text.slice(0, -1);
            el.textContent = text;
            setTimeout(tick, DELETE_MS);
          } else { phase = "blank"; setTimeout(tick, BLANK_MS); }
        } else if (phase === "blank") {
          idx = (idx + 1) % WORDS.length;
          phase = "typing"; tick();
        }
      };
      setTimeout(tick, HOLD_MS);
    });
  });
</script>

<link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display&display=swap" rel="stylesheet">

<style>
  .chronica-logo {
    display: inline-flex;
    align-items: center;
    gap: 12px;
    font-family: 'DM Serif Display', 'Times New Roman', serif;
    font-size: 36px;
    color: #15140F;
    letter-spacing: -0.02em;
    line-height: 1;
    user-select: none;
  }
  .chronica-logo .cl-disk {
    width: 42px; height: 42px; border-radius: 50%;
    background: #15140F; color: #F5F1EA;
    display: inline-flex; align-items: center; justify-content: center;
    flex-shrink: 0;
  }
  .chronica-logo .cl-disk-c {
    font-size: 28px; line-height: 1; transform: translateY(-2px);
  }
  @media (min-width: 640px) {
    .chronica-logo { font-size: 56px; gap: 18px; }
    .chronica-logo .cl-disk { width: 62px; height: 62px; }
    .chronica-logo .cl-disk-c { font-size: 42px; }
  }
  .chronica-logo .cl-word {
    display: inline-flex; align-items: baseline;
  }
  .chronica-logo .cl-suffix { color: #86827A; }
  .chronica-logo .cl-cursor {
    display: inline-block;
    width: 3px; height: 0.78em;
    background: #B43A1F;
    margin-left: 6px;
    align-self: center;
    animation: cl-blink 1.05s steps(2) infinite;
  }
  @keyframes cl-blink {
    0%, 100% { opacity: 1; }
    50%      { opacity: 0; }
  }
</style>

<div class="not-prose flex flex-col items-center mt-16 mb-12">

  <span class="chronica-logo" aria-label="chronica.life">
    <span class="cl-disk"><span class="cl-disk-c">c</span></span>
    <span class="cl-word">
      chronica<span class="cl-suffix">.<span data-chronica-suffix="">love</span></span>
      <span class="cl-cursor" aria-hidden="true"></span>
    </span>
  </span>

  <p class="text-gray-400 text-xs leading-relaxed mt-16 max-w-lg text-center">
    Собираем материалы из открытых источников, группируем по темам и формируем ежедневные сводки — чтобы следить за событиями без лишнего шума.
  </p>

</div>
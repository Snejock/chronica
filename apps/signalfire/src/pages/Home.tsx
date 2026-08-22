import { useEffect, useRef } from "react";

// Ротация слова в бейдже "CHRONICA.<слово>": state machine печатающейся анимации
// (typing → hold → deleting → blank → следующее слово).
const WORDS = ["AI", "MONEY", "TECH", "WAR", "LIFE", "WORLD", "ART", "DATA"];
const TYPE_MS = 95;
const DELETE_MS = 55;
const HOLD_MS = 1300;
const BLANK_MS = 320;

type Phase = "typing" | "hold" | "deleting" | "blank";

export default function Home() {
  const suffixRef = useRef<HTMLSpanElement>(null);
  const caretRef = useRef<HTMLSpanElement>(null);

  useEffect(() => {
    const suffixEl = suffixRef.current;
    const caretEl = caretRef.current;
    if (!suffixEl) return;

    const setSolid = () => caretEl?.classList.add("is-typing");
    const setBlinking = () => {
      if (!caretEl) return;
      caretEl.classList.remove("is-typing");
      // Перезапуск CSS-анимации моргания каретки с нуля через принудительный reflow
      caretEl.style.animation = "none";
      void caretEl.offsetWidth;
      caretEl.style.animation = "";
    };

    let idx = 0;
    let text = suffixEl.textContent || WORDS[0];
    let phase: Phase = "hold";
    let timerId: ReturnType<typeof setTimeout>;

    const tick = () => {
      const word = WORDS[idx];
      if (phase === "typing") {
        setSolid();
        if (text.length < word.length) {
          text = word.slice(0, text.length + 1);
          suffixEl.textContent = text;
          timerId = setTimeout(tick, TYPE_MS);
        } else {
          phase = "hold";
          setBlinking();
          timerId = setTimeout(tick, HOLD_MS);
        }
      } else if (phase === "hold") {
        phase = "deleting";
        timerId = setTimeout(tick, DELETE_MS);
      } else if (phase === "deleting") {
        setSolid();
        if (text.length > 0) {
          text = text.slice(0, -1);
          suffixEl.textContent = text;
          timerId = setTimeout(tick, DELETE_MS);
        } else {
          phase = "blank";
          setBlinking();
          timerId = setTimeout(tick, BLANK_MS);
        }
      } else if (phase === "blank") {
        idx = (idx + 1) % WORDS.length;
        phase = "typing";
        tick();
      }
    };

    timerId = setTimeout(tick, HOLD_MS);
    return () => clearTimeout(timerId);
  }, []);

  return (
    <div className="flex flex-col items-center mt-16 mb-12">
      <span className="chronica-flag" aria-label="CHRONICA">
        <span className="cf-word">CHRONICA</span>
        <span className="cf-flag">
          <span className="cf-dot">.</span>
          <span className="cf-suffix" ref={suffixRef}>
            AI
          </span>
          <span className="cf-caret" ref={caretRef} aria-hidden="true"></span>
        </span>
      </span>

      <p className="text-gray-400 text-xs leading-relaxed mt-16 max-w-lg text-center">
        Собираем материалы из открытых источников, группируем по темам и формируем ежедневные
        сводки — чтобы следить за событиями без лишнего шума.
      </p>

      <a href="/stories" className="chronica-btn mt-10">
        Сюжеты →
      </a>
    </div>
  );
}

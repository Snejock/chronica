// Заглушка на моковых данных — заменить на реальный запрос к services/api, когда
// появится эндпоинт с историей котировок и объёмов торгов.
export type PricePoint = {
  date: string; // YYYY-MM-DD
  price: number;
  volume: number;
};

function seededRandom(seed: number) {
  let state = seed;
  return () => {
    state = (state * 1664525 + 1013904223) >>> 0;
    return state / 0xffffffff;
  };
}

function hashSeed(text: string) {
  let hash = 0;
  for (const char of text) {
    hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
  }
  return hash;
}

// Детерминированная псевдослучайная история по тикеру — стабильно выглядит одинаково
// для одной и той же компании между перерендерами, но не одинаково между компаниями.
export function generateMockPriceHistory(ticker: string, days = 30): PricePoint[] {
  const random = seededRandom(hashSeed(ticker));
  let price = 100 + random() * 400;
  const points: PricePoint[] = [];
  const today = new Date();

  for (let i = days - 1; i >= 0; i--) {
    const date = new Date(today);
    date.setDate(date.getDate() - i);
    price = Math.max(1, price * (1 + (random() - 0.5) * 0.04));
    const volume = Math.round(50_000 + random() * 200_000);
    points.push({
      date: date.toISOString().slice(0, 10),
      price: Math.round(price * 100) / 100,
      volume,
    });
  }

  return points;
}
// Заглушка на моковых данных — заменить на реальный запрос к services/api, когда там
// появится эндпоинт со списком компаний.
export type Company = {
  ticker: string;
  name: string;
  sector: string;
};

export const MOCK_COMPANIES: Company[] = [
  { ticker: "SBER", name: "Сбербанк", sector: "Финансы" },
  { ticker: "GAZP", name: "Газпром", sector: "Энергетика" },
  { ticker: "LKOH", name: "Лукойл", sector: "Энергетика" },
  { ticker: "GMKN", name: "Норникель", sector: "Металлургия" },
  { ticker: "YDEX", name: "Яндекс", sector: "Технологии" },
  { ticker: "MGNT", name: "Магнит", sector: "Ритейл" },
  { ticker: "ROSN", name: "Роснефть", sector: "Энергетика" },
  { ticker: "NVTK", name: "Новатэк", sector: "Энергетика" },
];
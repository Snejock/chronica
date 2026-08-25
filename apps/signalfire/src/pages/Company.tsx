import { useParams } from "react-router";
import { MOCK_COMPANIES } from "@/lib/mock-companies";
import { PriceVolumeChart } from "@/components/price-volume-chart";

export default function Company() {
  const { id } = useParams<{ id: string }>();
  const company = MOCK_COMPANIES.find((c) => c.ticker === id);

  return (
    <div className="flex flex-col gap-6 p-4">
      <h1 className="text-xl font-semibold text-foreground">
        {company ? company.name : id}
      </h1>

      <PriceVolumeChart ticker={id ?? "UNKNOWN"} />

      <p className="text-sm text-muted-foreground">
        Заглушка — здесь будет автоматически формируемое summary текущего состояния
        компании: сводка последних новостей, трендов и ключевых метрик.
      </p>
    </div>
  );
}
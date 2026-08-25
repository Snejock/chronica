import { Area, AreaChart, Bar, BarChart, CartesianGrid, XAxis } from "recharts";
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart";
import { generateMockPriceHistory } from "@/lib/mock-price-history";

const priceConfig = {
  price: { label: "Цена", color: "var(--chart-1)" },
} satisfies ChartConfig;

const volumeConfig = {
  volume: { label: "Объём", color: "var(--chart-2)" },
} satisfies ChartConfig;

function formatDate(value: unknown) {
  return new Date(String(value)).toLocaleDateString("ru-RU", {
    day: "2-digit",
    month: "2-digit",
  });
}

// Цена и объём — разные единицы измерения, поэтому два отдельных графика с общей
// осью X, а не один график с двумя Y-осями (см. dataviz-skill: no dual-axis charts).
export function PriceVolumeChart({ ticker }: { ticker: string }) {
  const data = generateMockPriceHistory(ticker);

  return (
    <div className="flex flex-col gap-4">
      <ChartContainer config={priceConfig} className="aspect-auto h-40 w-full">
        <AreaChart data={data} margin={{ left: 0, right: 0 }}>
          <CartesianGrid vertical={false} strokeDasharray="none" />
          <XAxis
            dataKey="date"
            tickFormatter={formatDate}
            tickLine={false}
            axisLine={false}
            minTickGap={32}
          />
          <ChartTooltip
            cursor={{ stroke: "var(--border)" }}
            content={<ChartTooltipContent labelFormatter={formatDate} />}
          />
          <Area
            dataKey="price"
            type="monotone"
            stroke="var(--color-price)"
            strokeWidth={2}
            fill="var(--color-price)"
            fillOpacity={0.1}
          />
        </AreaChart>
      </ChartContainer>

      <ChartContainer config={volumeConfig} className="aspect-auto h-24 w-full">
        <BarChart data={data} margin={{ left: 0, right: 0 }}>
          <CartesianGrid vertical={false} strokeDasharray="none" />
          <XAxis
            dataKey="date"
            tickFormatter={formatDate}
            tickLine={false}
            axisLine={false}
            minTickGap={32}
          />
          <ChartTooltip
            cursor={{ fill: "var(--muted)" }}
            content={<ChartTooltipContent labelFormatter={formatDate} />}
          />
          <Bar dataKey="volume" fill="var(--color-volume)" radius={[4, 4, 0, 0]} maxBarSize={24} />
        </BarChart>
      </ChartContainer>
    </div>
  );
}
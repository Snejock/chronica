import { useNavigate } from "react-router";
import { Button } from "@/components/ui/button";

export default function Home() {
  const navigate = useNavigate();

  return (
    <div className="flex flex-col items-center justify-center gap-4 mt-24 text-center">
      <h1 className="text-2xl font-semibold text-foreground">Signalfire</h1>
      <p className="text-sm text-muted-foreground max-w-sm">
        Заготовка на shadcn/ui — стартовая точка для Telegram Mini App.
      </p>
      <Button onClick={() => navigate("/dashboard")}>Начать</Button>
    </div>
  );
}

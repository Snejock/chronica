import { Link } from "react-router";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardTitle } from "@/components/ui/card";
import { MOCK_COMPANIES } from "@/lib/mock-companies";

export default function Dashboard() {
  return (
    <div className="flex flex-col gap-2 p-4">
      {MOCK_COMPANIES.map((company) => (
        <Link key={company.ticker} to={`/company/${company.ticker}`}>
          <Card size="sm" className="flex-row items-center">
            <CardContent className="flex flex-1 items-center gap-3">
              <Avatar>
                <AvatarFallback>{company.ticker.slice(0, 2)}</AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex-1">
                <CardTitle className="truncate">{company.name}</CardTitle>
                <CardDescription className="truncate">
                  {company.sector}
                </CardDescription>
              </div>
              <Badge variant="outline">{company.ticker}</Badge>
            </CardContent>
          </Card>
        </Link>
      ))}
    </div>
  );
}
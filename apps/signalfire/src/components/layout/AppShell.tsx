import { Outlet, Link, useLocation, useParams } from "react-router";
import {
  Sidebar,
  SidebarContent,
  SidebarGroup,
  SidebarGroupContent,
  SidebarHeader,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { MOCK_COMPANIES } from "@/lib/mock-companies";

const NAV_ITEMS = [
  { title: "Главная", url: "/" },
  { title: "Компании", url: "/dashboard" },
];

// Общий каркас "внутренних" страниц (всё, что за кнопкой "Начать"): сайдбар с навигацией
// и шапка с Breadcrumb. Сама страница рендерится через <Outlet />.
export default function AppShell() {
  const { pathname } = useLocation();
  const { id } = useParams<{ id?: string }>();
  const company = id ? MOCK_COMPANIES.find((c) => c.ticker === id) : undefined;
  const isCompanyPage = pathname.startsWith("/company/");

  return (
    <SidebarProvider>
      <Sidebar>
        <SidebarHeader>
          <span className="px-2 text-sm font-semibold">Signalfire</span>
        </SidebarHeader>
        <SidebarContent>
          <SidebarGroup>
            <SidebarGroupContent>
              <SidebarMenu>
                {NAV_ITEMS.map((item) => (
                  <SidebarMenuItem key={item.url}>
                    <SidebarMenuButton
                      render={<Link to={item.url} />}
                      isActive={pathname === item.url}
                    >
                      {item.title}
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        </SidebarContent>
      </Sidebar>
      <SidebarInset>
        <header className="flex h-12 items-center gap-2 border-b px-2">
          <SidebarTrigger />
          <Breadcrumb>
            <BreadcrumbList>
              <BreadcrumbItem>
                {isCompanyPage ? (
                  <BreadcrumbLink render={<Link to="/dashboard" />}>
                    Компании
                  </BreadcrumbLink>
                ) : (
                  <BreadcrumbPage>Компании</BreadcrumbPage>
                )}
              </BreadcrumbItem>
              {isCompanyPage && (
                <>
                  <BreadcrumbSeparator />
                  <BreadcrumbItem>
                    <BreadcrumbPage>{company ? company.name : id}</BreadcrumbPage>
                  </BreadcrumbItem>
                </>
              )}
            </BreadcrumbList>
          </Breadcrumb>
        </header>
        <div className="flex-1 overflow-y-auto">
          <Outlet />
        </div>
      </SidebarInset>
    </SidebarProvider>
  );
}
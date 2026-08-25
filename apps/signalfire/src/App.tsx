import { Routes, Route } from "react-router";
import AppShell from "./components/layout/AppShell.tsx";
import Home from "./pages/Home.tsx";
import Dashboard from "./pages/Dashboard.tsx";
import Company from "./pages/Company.tsx";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Home />} />
      <Route element={<AppShell />}>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/company/:id" element={<Company />} />
      </Route>
    </Routes>
  );
}
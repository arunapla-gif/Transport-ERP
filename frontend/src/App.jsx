import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route, Link, NavLink, useLocation } from 'react-router-dom';
import { Printer } from 'lucide-react';
import GcEntry from './pages/GcEntry';
import WarehouseEntry from './pages/WarehouseEntry';
import WarehouseStatement from './pages/WarehouseStatement';
import ConsignorMaster from './pages/ConsignorMaster';
import ConsigneeMaster from './pages/ConsigneeMaster';
import VehicleMaster from './pages/VehicleMaster';
import TailwindDemo from './pages/TailwindDemo';
import VanillaDemo from './pages/VanillaDemo';
import SampleDesign from './pages/SampleDesign';
import LorryHire from './pages/LorryHire';
import FreightEntry from './pages/FreightEntry';
import GdmEntry from './pages/GdmEntry';
import Reports from './pages/Reports';
import { Truck } from 'lucide-react';

import CompanyMaster from './pages/CompanyMaster';
import GodownMaster from './pages/GodownMaster';
import GcPrint from './pages/GcPrint';
import GdmPrint from './pages/GdmPrint';
import PrintHub from './pages/PrintHub';
import Login from './pages/Login';
import PartyAccounts from './pages/PartyAccounts';
import TechnologyUsage from './pages/TechnologyUsage';
import TripSettlement from './pages/TripSettlement';
import DailyAccounts from './pages/DailyAccounts';
import GodownPlanner from './pages/GodownPlanner';
import RemoteScanner from './pages/RemoteScanner';
import { LogOut, AlertCircle } from 'lucide-react';
import { Toaster } from 'react-hot-toast';

function Layout({ children, role, onLogout }) {
  const location = useLocation();
  // Hide header ONLY for actual print receipts
  if (location.pathname.startsWith('/print/')) {
    return <>{children}</>;
  }

  return (
    <div className="min-h-screen bg-[#F8F6F0] selection:bg-stone-200 print:bg-white print:min-h-0">
      <header className="bg-gradient-to-r from-stone-900 via-stone-800 to-stone-900 text-white px-3 md:px-5 py-2 md:py-2.5 shadow-md border-b border-white/10 sticky top-0 z-50 flex flex-col md:flex-row justify-between items-center min-h-[52px] gap-2 md:gap-0 backdrop-blur-sm print:hidden">
        <div className="flex items-center justify-between w-full md:w-auto">
          <div className="flex items-center gap-2 md:gap-3">
            <div className="w-7 h-7 md:w-8 md:h-8 rounded-lg bg-gradient-to-br from-stone-600 to-stone-800 flex items-center justify-center shadow-inner border border-stone-500/30">
              <Truck className="text-stone-100 w-4 h-4 md:w-5 md:h-5" />
            </div>
            <h1 className="text-base md:text-lg font-black m-0 tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-stone-300">Transport ERP</h1>
          </div>
          
          {/* Logout shown in top row on mobile for space-saving */}
          <button onClick={onLogout} title="Logout" className="md:hidden px-2 py-1.5 rounded-md bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-all shadow-sm flex items-center justify-center">
            <LogOut size={14} />
          </button>
        </div>

        <nav className="flex flex-wrap justify-center gap-1.5 md:gap-2.5 items-center w-full md:w-auto pb-1 md:pb-0">
          <div className="flex bg-white/5 rounded-md border border-white/10 p-0.5 shadow-sm">
             <Link to="/" className="px-2.5 md:px-3.5 py-1 rounded-[4px] hover:bg-white/10 transition-all text-[11px] md:text-xs font-bold text-emerald-200 hover:text-emerald-100">Warehouse</Link>
             <Link to="/warehouse-statement" className="px-2.5 md:px-3.5 py-1 rounded-[4px] hover:bg-white/10 transition-all text-[11px] md:text-xs font-bold text-emerald-200 hover:text-emerald-100 border-l border-white/10">Statement</Link>
          </div>
          
          <div className="relative group">
            <button className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Masters <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className="absolute right-0 top-full pt-1.5 hidden group-hover:block z-50">
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link to="/masters/consignors" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignor Master</Link>
                <Link to="/masters/consignees" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignee Master</Link>
                <Link to="/masters/godowns" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 font-bold transition-colors">Godown Master</Link>
              </div>
            </div>
          </div>
          
          {/* SETTINGS MENU */}
          <div className="relative group">
            <button className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Settings <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className="absolute right-0 top-full pt-1.5 hidden group-hover:block z-50">
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link to="/settings/usage" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Tech Usage</Link>
              </div>
            </div>
          </div>

          {/* Logout shown in nav row only on PC */}
          <button onClick={onLogout} title="Logout" className="hidden md:flex ml-1 px-2 py-1.5 rounded-md bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-all shadow-sm items-center justify-center">
            <LogOut size={14} />
          </button>
        </nav>
      </header>
      <main className="w-full px-4 py-3">
        {children}
      </main>
    </div>
  );
}

function App() {
  const [role, setRole] = useState(localStorage.getItem('erp_role') || null);

  const handleLogin = (selectedRole) => {
    localStorage.setItem('erp_role', selectedRole);
    setRole(selectedRole);
  };

  const handleLogout = () => {
    localStorage.removeItem('erp_role');
    setRole(null);
  };

  if (!role) {
    return <Login onLogin={handleLogin} />;
  }

  return (
    <Router>
      <Toaster position="top-right" toastOptions={{ duration: 3000, style: { fontWeight: 'bold' } }} />
      <Layout role={role} onLogout={handleLogout}>
        <Routes>
          <Route path="/print/gc/:id" element={<GcPrint />} />
          <Route path="/print/gdm/:id" element={<GdmPrint />} />
          <Route path="/" element={<WarehouseEntry />} />
          <Route path="/warehouse-entry" element={<WarehouseEntry />} />
          <Route path="/warehouse-statement" element={<WarehouseStatement />} />
          <Route path="/freight-entry" element={<FreightEntry />} />
          
          {role === 'owner' && (
            <>
              <Route path="/lorry-hire" element={<LorryHire />} />
              <Route path="/trip-settlement" element={<TripSettlement />} />
              <Route path="/party-accounts" element={<PartyAccounts />} />
              <Route path="/daily-accounts" element={<DailyAccounts />} />
              <Route path="/godown-planner" element={<GodownPlanner />} />
            </>
          )}

          <Route path="/tailwind-demo" element={<TailwindDemo />} />
          <Route path="/vanilla-demo" element={<VanillaDemo />} />
          <Route path="/sample-design" element={<SampleDesign />} />
          <Route path="/gdm" element={<GdmEntry />} />
          <Route path="/remote-scanner" element={<RemoteScanner />} />
          <Route path="/print-hub" element={<PrintHub />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="/settings/usage" element={<TechnologyUsage />} />
          <Route path="/masters/company" element={<CompanyMaster />} />
          <Route path="/masters/vehicles" element={<VehicleMaster />} />
          <Route path="/masters/godowns" element={<GodownMaster />} />
          <Route path="/masters/consignors" element={<ConsignorMaster />} />
          <Route path="/masters/consignees" element={<ConsigneeMaster />} />
        </Routes>
      </Layout>
    </Router>
  );
}

export default App;

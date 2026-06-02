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
import TripSettlement from './pages/TripSettlement';
import DailyAccounts from './pages/DailyAccounts';
import GodownPlanner from './pages/GodownPlanner';
import RemoteScanner from './pages/RemoteScanner';
import { LogOut, AlertCircle } from 'lucide-react';

function Layout({ children, role, onLogout }) {
  const location = useLocation();
  // Hide header ONLY for actual print receipts
  if (location.pathname.startsWith('/print/')) {
    return <>{children}</>;
  }

  return (
    <div className="min-h-screen bg-[#F8F6F0] selection:bg-stone-200 print:bg-white print:min-h-0">
      <header className="bg-gradient-to-r from-stone-900 via-stone-800 to-stone-900 text-white px-5 py-2.5 shadow-md border-b border-white/10 sticky top-0 z-50 flex justify-between items-center h-[52px] backdrop-blur-sm print:hidden">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-stone-600 to-stone-800 flex items-center justify-center shadow-inner border border-stone-500/30">
            <Truck size={16} className="text-stone-100" />
          </div>
          <h1 className="text-lg font-black m-0 tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-stone-300">Transport ERP</h1>
        </div>
        <nav className="flex gap-2.5 items-center">
          <div className="flex bg-white/5 rounded-md border border-white/10 p-0.5 shadow-sm">
             <Link to="/" className="px-3.5 py-1 rounded-[4px] hover:bg-white/10 transition-all text-xs font-bold text-emerald-200 hover:text-emerald-100">Warehouse</Link>
             <Link to="/warehouse-statement" className="px-3.5 py-1 rounded-[4px] hover:bg-white/10 transition-all text-xs font-bold text-emerald-200 hover:text-emerald-100 border-l border-white/10">Statement</Link>
          </div>
          
          <div className="relative group">
            <button className="px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-xs font-bold shadow-sm flex items-center gap-1">Masters <span className="text-[10px] opacity-70">▼</span></button>
            <div className="absolute right-0 top-full pt-2 hidden group-hover:block z-50">
              <div className="w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link to="/masters/consignors" className="block px-4 py-2.5 text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignor Master</Link>
                <Link to="/masters/consignees" className="block px-4 py-2.5 text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignee Master</Link>
                <Link to="/masters/godowns" className="block px-4 py-2.5 text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 font-bold transition-colors">Godown Master</Link>
              </div>
            </div>
          </div>
          <button onClick={onLogout} title="Logout" className="ml-2 px-2 py-1.5 rounded-md bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-all shadow-sm flex items-center justify-center">
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

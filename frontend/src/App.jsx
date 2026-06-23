import React, { useState, useEffect } from 'react';
import { api } from './api';
import { BrowserRouter as Router, Routes, Route, Link, NavLink, useLocation } from 'react-router-dom';
import { Printer, Wifi, Database, Loader2 } from 'lucide-react';
import { Truck } from 'lucide-react';
import { LogOut, AlertCircle } from 'lucide-react';
import { Toaster } from 'react-hot-toast';

// Lazy load all pages to drastically reduce the initial bundle size
const SystemBoot = React.lazy(() => import('./pages/SystemBoot'));
const NewGcEntry = React.lazy(() => import('./pages/NewGcEntry'));
const WarehouseEntry = React.lazy(() => import('./pages/WarehouseEntry'));
const WarehouseStatement = React.lazy(() => import('./pages/WarehouseStatement'));
const ConsignorMaster = React.lazy(() => import('./pages/ConsignorMaster'));
const ConsigneeMaster = React.lazy(() => import('./pages/ConsigneeMaster'));
const VehicleMaster = React.lazy(() => import('./pages/VehicleMaster'));
const LorryHire = React.lazy(() => import('./pages/LorryHire'));
const FreightEntry = React.lazy(() => import('./pages/FreightEntry'));
const LegacyRapidEntry = React.lazy(() => import('./pages/LegacyRapidEntry'));
const GdmEntry = React.lazy(() => import('./pages/GdmEntry'));
const Reports = React.lazy(() => import('./pages/Reports'));
const CompanyMaster = React.lazy(() => import('./pages/CompanyMaster'));
const GodownMaster = React.lazy(() => import('./pages/GodownMaster'));
const GcPrint = React.lazy(() => import('./pages/GcPrint'));
const GdmPrint = React.lazy(() => import('./pages/GdmPrint'));
const CewbPrint = React.lazy(() => import('./pages/CewbPrint'));
const CombinedGdmPrint = React.lazy(() => import('./pages/CombinedGdmPrint'));
const PrintHub = React.lazy(() => import('./pages/PrintHub'));
const UnitMaster = React.lazy(() => import('./pages/UnitMaster'));
const HSNMaster = React.lazy(() => import('./pages/HSNMaster'));
const Login = React.lazy(() => import('./pages/Login'));
const PartyAccounts = React.lazy(() => import('./pages/PartyAccounts'));
const TechnologyUsage = React.lazy(() => import('./pages/TechnologyUsage'));
const TripSettlement = React.lazy(() => import('./pages/TripSettlement'));
const DailyAccounts = React.lazy(() => import('./pages/DailyAccounts'));
const GodownPlanner = React.lazy(() => import('./pages/GodownPlanner'));
const RemoteScanner = React.lazy(() => import('./pages/RemoteScanner'));
const LegacyViewer = React.lazy(() => import('./pages/LegacyViewer'));

const SystemStatus = () => {
  const [dbStatus, setDbStatus] = useState('idle'); // idle, waking, ready, error
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);
    
    const handleDbStatus = (e) => {
      setDbStatus(e.detail);
      if (e.detail === 'ready' || e.detail === 'error') {
        setTimeout(() => setDbStatus('idle'), 3000); // revert to idle after 3s
      }
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    window.addEventListener('erp-db-status', handleDbStatus);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
      window.removeEventListener('erp-db-status', handleDbStatus);
    };
  }, []);

  return (
    <div className="flex items-center gap-2 mx-2 px-2 py-1 rounded-lg bg-stone-900/40 border border-white/10 shadow-inner">
      {/* Network Status */}
      <div title={isOnline ? 'Network Online' : 'Network Offline'} className={`flex items-center gap-1 ${isOnline ? 'text-emerald-400' : 'text-rose-500 animate-pulse'}`}>
        <Wifi size={13} />
      </div>
      
      <div className="w-px h-3 bg-stone-700"></div>

      {/* DB Status */}
      <div title={`Database ${dbStatus === 'idle' ? 'Connected (Idle)' : dbStatus}`} className={`flex items-center gap-1 ${
        dbStatus === 'waking' ? 'text-amber-400' :
        dbStatus === 'ready' ? 'text-emerald-400' :
        dbStatus === 'error' ? 'text-rose-500' :
        'text-blue-400'
      }`}>
        {dbStatus === 'waking' ? <Loader2 size={13} className="animate-spin" /> : <Database size={13} />}
      </div>
    </div>
  );
};

function Layout({ children, role, onLogout }) {
  const location = useLocation();
  const [activeDropdown, setActiveDropdown] = useState(null);

  // Hide header ONLY for actual print receipts
  if (location.pathname.startsWith('/print/')) {
    return <>{children}</>;
  }

  const toggleMenu = (menuName) => {
    setActiveDropdown(activeDropdown === menuName ? null : menuName);
  };

  const closeMenu = () => {
    setActiveDropdown(null);
  };

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
          
          <div className="flex items-center gap-2 md:hidden">
            <SystemStatus />
            {/* Logout shown in top row on mobile for space-saving */}
            <button onClick={onLogout} title="Logout" className="px-2 py-1.5 rounded-md bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-all shadow-sm flex items-center justify-center">
              <LogOut size={14} />
            </button>
          </div>
        </div>

        <nav className="flex flex-wrap justify-center gap-1.5 md:gap-2.5 items-center w-full md:w-auto pb-1 md:pb-0">
          <Link to="/" className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1 text-white">Dashboard</Link>
          <div className="relative group">
            <button onClick={() => toggleMenu('warehouse')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1 text-emerald-200">Warehouse <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute left-0 top-full pt-1.5 z-50 ${activeDropdown === 'warehouse' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link onClick={closeMenu} to="/warehouse-entry" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-emerald-50 hover:text-emerald-700 border-b border-slate-100 font-bold transition-colors">Warehouse Entry</Link>
                <Link onClick={closeMenu} to="/warehouse-statement" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-emerald-50 hover:text-emerald-700 font-bold transition-colors">Warehouse Statement</Link>
              </div>
            </div>
          </div>
          
          <div className="relative group">
            <button onClick={() => toggleMenu('operations')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1 text-amber-200">Entry <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 md:left-0 top-full pt-1.5 z-50 ${activeDropdown === 'operations' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link onClick={closeMenu} to="/new-gc" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-amber-50 hover:text-amber-700 border-b border-slate-100 font-bold transition-colors">GC Entry</Link>
                <Link onClick={closeMenu} to="/legacy-rapid-entry" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-amber-50 hover:text-amber-700 border-b border-slate-100 font-bold transition-colors">Legacy Rapid Entry</Link>
                <Link onClick={closeMenu} to="/gdm" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">GDM Entry</Link>
                <Link onClick={closeMenu} to="/freight-entry" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Freight Entry</Link>
                <Link onClick={closeMenu} to="/lorry-hire" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-indigo-50 hover:text-indigo-700 border-b border-slate-100 font-bold transition-colors">Lorry Hire</Link>
                <Link onClick={closeMenu} to="/trip-settlement" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-indigo-50 hover:text-indigo-700 font-bold transition-colors">Trip Settlement</Link>
              </div>
            </div>
          </div>

          <div className="relative group">
            <button onClick={() => toggleMenu('masters')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Masters <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'masters' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link onClick={closeMenu} to="/masters/consignors" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignor Master</Link>
                <Link onClick={closeMenu} to="/masters/consignees" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Consignee Master</Link>
                <Link onClick={closeMenu} to="/masters/vehicles" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Vehicle Master</Link>
                <Link onClick={closeMenu} to="/masters/godowns" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Godown Master</Link>
                <Link onClick={closeMenu} to="/masters/units" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Unit Master</Link>
                <Link onClick={closeMenu} to="/masters/hsn" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">HSN Tax Master</Link>

              </div>
            </div>
          </div>

          <div className="relative group">
            <button onClick={() => toggleMenu('reports')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Print/Hub <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'reports' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link onClick={closeMenu} to="/print-hub" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Print Hub</Link>
                <Link onClick={closeMenu} to="/reports" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Reports</Link>
                <Link onClick={closeMenu} to="/godown-planner" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Godown Planner</Link>
                <Link onClick={closeMenu} to="/party-accounts" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-emerald-50 hover:text-emerald-700 border-b border-slate-100 font-bold transition-colors">Party Accounts</Link>
                <Link onClick={closeMenu} to="/daily-accounts" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-emerald-50 hover:text-emerald-700 font-bold transition-colors">Daily Accounts</Link>
                <Link onClick={closeMenu} to="/legacy-viewer" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-rose-50 hover:text-rose-700 border-t border-slate-100 font-black transition-colors">Old ERP Data (MS Access)</Link>
              </div>
            </div>
          </div>
          
          {/* GLOBAL BRANCH SWITCHER - VISIBLE ONLY IF ASSIGNED TO 'ALL' */}
          {localStorage.getItem('assignedBranch') === 'ALL' && (
            <div className="relative group">
              <button onClick={() => toggleMenu('branch_switcher')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-indigo-500/30 bg-indigo-500/10 hover:bg-indigo-500/20 hover:border-indigo-500/50 transition-all text-[11px] md:text-xs font-black text-indigo-200 shadow-sm flex items-center gap-1">
                {localStorage.getItem('activeBranch') === 'AP_BNG' ? 'AP BNG' : 'MAIN BRANCH'} <span className="text-[9px] md:text-[10px] opacity-70">▼</span>
              </button>
              <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'branch_switcher' ? 'block' : 'hidden md:group-hover:block'}`}>
                <div className="w-40 md:w-48 bg-white shadow-xl shadow-indigo-900/10 border border-indigo-200 rounded-lg overflow-hidden backdrop-blur-xl flex flex-col">
                  <button 
                    onClick={() => {
                      localStorage.setItem('activeBranch', 'MAIN');
                      window.location.href = '/';
                    }} 
                    className={`block w-full text-left px-3 md:px-4 py-2.5 text-[11px] md:text-xs ${localStorage.getItem('activeBranch') === 'MAIN' ? 'bg-indigo-50 text-indigo-700 font-black' : 'text-slate-700 hover:bg-slate-50 font-bold'} border-b border-slate-100 transition-colors`}
                  >
                    Main Branch
                  </button>
                  <button 
                    onClick={() => {
                      localStorage.setItem('activeBranch', 'AP_BNG');
                      window.location.href = '/';
                    }} 
                    className={`block w-full text-left px-3 md:px-4 py-2.5 text-[11px] md:text-xs ${localStorage.getItem('activeBranch') === 'AP_BNG' ? 'bg-amber-50 text-amber-700 font-black' : 'text-slate-700 hover:bg-slate-50 font-bold'} transition-colors`}
                  >
                    AP BNG
                  </button>
                </div>
              </div>
            </div>
          )}
          
          {/* SETTINGS MENU */}
          <div className="relative group">
            <button onClick={() => toggleMenu('settings')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Settings <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'settings' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-40 md:w-48 bg-white shadow-xl shadow-slate-900/10 border border-slate-200 rounded-lg overflow-hidden backdrop-blur-xl">
                <Link onClick={closeMenu} to="/settings/usage" className="block px-3 md:px-4 py-2.5 text-[11px] md:text-xs text-slate-700 hover:bg-blue-50 hover:text-blue-700 border-b border-slate-100 font-bold transition-colors">Tech Usage</Link>
              </div>
            </div>
          </div>

          <div className="hidden md:flex items-center gap-1.5 ml-2">
            <SystemStatus />
            <button onClick={onLogout} title="Logout" className="px-2 py-1.5 rounded-md bg-rose-500/20 hover:bg-rose-500/40 text-rose-200 transition-all shadow-sm flex items-center justify-center">
              <LogOut size={14} />
            </button>
          </div>


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
    // Force the router to start at the dashboard (/) when logging in
    window.history.pushState({}, '', '/');
  };

  const handleLogout = () => {
    localStorage.removeItem('erp_role');
    localStorage.removeItem('erp_token');
    localStorage.removeItem('assignedBranch');
    localStorage.removeItem('activeBranch');
    sessionStorage.removeItem('system_booted');
    setRole(null);
  };

  if (!role) {
    return (
      <React.Suspense fallback={
        <div className="fixed inset-0 flex items-center justify-center bg-[#1c1917] z-[9999]">
          <div className="w-10 h-10 border-4 border-white/10 border-t-indigo-500 rounded-full animate-spin"></div>
        </div>
      }>
        <Login onLogin={handleLogin} />
      </React.Suspense>
    );
  }

  return (
    <Router>
      <Toaster position="top-right" toastOptions={{ duration: 3000, style: { fontWeight: 'bold' } }} />
      <Layout role={role} onLogout={handleLogout}>
        <React.Suspense fallback={
          <div className="flex items-center justify-center min-h-[50vh]">
            <div className="animate-spin rounded-full h-12 w-12 border-4 border-stone-200 border-t-stone-800"></div>
          </div>
        }>
          <Routes>
            <Route path="/print/gc/:id" element={<GcPrint />} />
            <Route path="/print/gdm/:id" element={<GdmPrint />} />
            <Route path="/print/cewb/:id" element={<CewbPrint />} />
            <Route path="/print/gdm-combined/:id" element={<CombinedGdmPrint />} />
            <Route path="/" element={<SystemBoot />} />
            <Route path="/new-gc" element={<NewGcEntry />} />
            <Route path="/legacy-rapid-entry" element={<LegacyRapidEntry />} />
            <Route path="/warehouse-entry" element={<WarehouseEntry />} />
            <Route path="/warehouse-statement" element={<WarehouseStatement />} />
            <Route path="/freight-entry" element={<FreightEntry />} />
            
            <Route path="/lorry-hire" element={<LorryHire />} />
            <Route path="/trip-settlement" element={<TripSettlement />} />
            <Route path="/party-accounts" element={<PartyAccounts />} />
            <Route path="/daily-accounts" element={<DailyAccounts />} />
            <Route path="/godown-planner" element={<GodownPlanner />} />

            <Route path="/gdm" element={<GdmEntry />} />
            <Route path="/remote-scanner" element={<RemoteScanner />} />
            <Route path="/print-hub" element={<PrintHub />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/legacy-viewer" element={<LegacyViewer />} />
            <Route path="/settings/usage" element={<TechnologyUsage />} />
            <Route path="/masters/company" element={<CompanyMaster />} />
            <Route path="/masters/vehicles" element={<VehicleMaster />} />
            <Route path="/masters/godowns" element={<GodownMaster />} />
            <Route path="/masters/units" element={<UnitMaster />} />
            <Route path="/masters/hsn" element={<HSNMaster />} />
            <Route path="/masters/consignors" element={<ConsignorMaster />} />
            <Route path="/masters/consignees" element={<ConsigneeMaster />} />

          </Routes>
        </React.Suspense>
      </Layout>
    </Router>
  );
}

export default App;

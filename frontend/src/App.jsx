import React, { useState, useEffect } from 'react';
import { api } from './api';
import { BrowserRouter as Router, Routes, Route, Link, NavLink, useLocation } from 'react-router-dom';
import { Printer, Wifi, Database, Loader2, Truck, LogOut, AlertCircle, FileText, Package, LayoutGrid, Users, Building2, MapPin, Scale, FileQuestion, BarChart3, Settings, ShieldCheck, QrCode, FileArchive, Navigation, HandCoins, TruckIcon, Banknote } from 'lucide-react';
import toast, { Toaster } from 'react-hot-toast';
import { QueryClientProvider } from '@tanstack/react-query';
import { queryClient } from './api/queryClient';

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
const DriverMaster = React.lazy(() => import('./pages/DriverMaster'));
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
const AuditLogs = React.lazy(() => import('./pages/AuditLogs'));
const AdminDashboard = React.lazy(() => import('./pages/AdminDashboard'));
const QrDemo = React.lazy(() => import('./pages/QrDemo'));
const GovtCompliance = React.lazy(() => import('./pages/GovtCompliance'));

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
    <div className="flex items-center gap-3 mx-2 h-9 px-3 rounded-lg bg-stone-900/40 border border-white/10 shadow-inner">
      {/* Network Status */}
      <div title={isOnline ? 'Network Online' : 'Network Offline'} className={`flex items-center justify-center ${isOnline ? 'text-emerald-400' : 'text-rose-500 animate-pulse'}`}>
        <Wifi size={18} />
      </div>
      
      <div className="w-px h-5 bg-stone-700"></div>

      {/* DB Status */}
      <div title={`Database ${dbStatus === 'idle' ? 'Connected (Idle)' : dbStatus}`} className={`flex items-center justify-center transition-all duration-300 ${
        dbStatus === 'waking' ? 'text-amber-400' :
        dbStatus === 'ready' ? 'text-emerald-300 drop-shadow-[0_0_8px_rgba(110,231,183,0.8)] scale-110' :
        dbStatus === 'error' ? 'text-rose-500' :
        'text-emerald-600'
      }`}>
        {dbStatus === 'waking' ? <Loader2 size={18} className="animate-spin" /> : <Database size={18} />}
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
    <div className="flex flex-col h-screen w-full bg-[#F8F6F0] selection:bg-stone-200 print:bg-white print:h-auto overflow-hidden">
      <header className="shrink-0 bg-gradient-to-r from-stone-900 via-stone-800 to-stone-900 text-white px-3 md:px-5 py-2 md:py-2.5 shadow-md border-b border-white/10 z-50 flex flex-col md:flex-row justify-between items-center min-h-[52px] gap-2 md:gap-0 print:hidden">
        <div className="flex items-center justify-between w-full md:w-auto">
          <div className="flex items-center gap-2 md:gap-3">
            <div className="w-7 h-7 md:w-8 md:h-8 rounded-lg bg-gradient-to-br from-stone-600 to-stone-800 flex items-center justify-center shadow-inner border border-stone-500/30">
              <Truck className="text-stone-100 w-4 h-4 md:w-5 md:h-5" />
            </div>
            <h1 className="text-base md:text-lg font-black m-0 tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white to-stone-300">Transport ERP</h1>
            {/* GLOBAL BRANCH SWITCHER - READ ONLY BADGE (MOVED TO LEFT) */}
            {localStorage.getItem('assignedBranch') === 'ALL' && (
              <Link to="/" className="ml-2 px-3 md:px-4 py-1 rounded-full border border-indigo-500/50 bg-indigo-500/10 hover:bg-indigo-500/20 hover:border-indigo-400 transition-all text-[10px] md:text-xs font-black text-indigo-200 shadow-sm flex items-center gap-1.5 cursor-pointer" title="Click to change branch">
                <span className="text-indigo-400">📍 Active:</span> {localStorage.getItem('activeBranch') === 'AP_BNG' ? 'AP BNG' : 'MAIN BRANCH'}
              </Link>
            )}
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
          <Link to="/" className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1 text-white">Home</Link>
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
            <div className={`absolute left-0 top-full pt-1.5 z-50 ${activeDropdown === 'operations' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-[420px] bg-white/95 shadow-2xl shadow-slate-900/10 border border-slate-200 rounded-2xl overflow-hidden backdrop-blur-xl p-3 grid grid-cols-2 gap-2">
                 <div className="col-span-2 mb-1 pb-2 border-b border-slate-100 flex items-center justify-between px-2">
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Logistics Operations</span>
                 </div>
                 
                 <Link onClick={closeMenu} to="/new-gc" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-indigo-50 text-indigo-600 rounded-lg group-hover:bg-indigo-500 group-hover:text-white transition-colors shadow-sm"><FileText size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">GC Entry</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Create Consignments</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/gdm" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-blue-50 text-blue-600 rounded-lg group-hover:bg-blue-500 group-hover:text-white transition-colors shadow-sm"><Package size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">GDM Entry</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Generate Delivery Memos</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/freight-entry" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg group-hover:bg-emerald-500 group-hover:text-white transition-colors shadow-sm"><HandCoins size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Freight Entry</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Manage Income & FPA</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/lorry-hire" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-amber-50 text-amber-600 rounded-lg group-hover:bg-amber-500 group-hover:text-white transition-colors shadow-sm"><TruckIcon size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Lorry Hire</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Record Lorry Advances</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/trip-settlement" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-rose-50 text-rose-600 rounded-lg group-hover:bg-rose-500 group-hover:text-white transition-colors shadow-sm"><Banknote size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Trip Settlement</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Finalize Driver Expenses</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/govt-compliance" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-sky-50 text-sky-600 rounded-lg group-hover:bg-sky-500 group-hover:text-white transition-colors shadow-sm"><ShieldCheck size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Govt EWB Hub</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Master CEWB & Verify</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/legacy-rapid-entry" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-slate-100 text-slate-600 rounded-lg group-hover:bg-slate-600 group-hover:text-white transition-colors shadow-sm"><FileArchive size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Legacy Entry</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Rapid Old Data Input</p>
                   </div>
                 </Link>
              </div>
            </div>
          </div>

          <div className="relative group">
            <button onClick={() => toggleMenu('masters')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Masters <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute left-1/2 -translate-x-1/2 top-full pt-1.5 z-50 ${activeDropdown === 'masters' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-[420px] bg-white/95 shadow-2xl shadow-slate-900/10 border border-slate-200 rounded-2xl overflow-hidden backdrop-blur-xl p-3 grid grid-cols-2 gap-2">
                 <div className="col-span-2 mb-1 pb-2 border-b border-slate-100 flex items-center justify-between px-2">
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Master Directories</span>
                 </div>
                 
                 <Link onClick={closeMenu} to="/masters/consignors" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-indigo-50 text-indigo-600 rounded-lg group-hover:bg-indigo-500 group-hover:text-white transition-colors shadow-sm"><Building2 size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Consignors</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Sender Profiles & GST</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/masters/consignees" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-blue-50 text-blue-600 rounded-lg group-hover:bg-blue-500 group-hover:text-white transition-colors shadow-sm"><Users size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Consignees</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Receiver Profiles & GST</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/masters/vehicles" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-amber-50 text-amber-600 rounded-lg group-hover:bg-amber-500 group-hover:text-white transition-colors shadow-sm"><Truck size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Vehicles</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Lorry Registry & RTO</p>
                   </div>
                 </Link>

                 <Link onClick={closeMenu} to="/masters/drivers" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-rose-50 text-rose-600 rounded-lg group-hover:bg-rose-500 group-hover:text-white transition-colors shadow-sm"><Users size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Drivers</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Driver Profiles & Licenses</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/masters/godowns" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg group-hover:bg-emerald-500 group-hover:text-white transition-colors shadow-sm"><LayoutGrid size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Godowns</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Warehouse Locations</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/masters/units" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-slate-100 text-slate-600 rounded-lg group-hover:bg-slate-600 group-hover:text-white transition-colors shadow-sm"><Scale size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Units</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Measurement Codes</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/masters/hsn" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-slate-100 text-slate-600 rounded-lg group-hover:bg-slate-600 group-hover:text-white transition-colors shadow-sm"><FileQuestion size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">HSN Tax</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Commodities</p>
                   </div>
                 </Link>
              </div>
            </div>
          </div>

          <div className="relative group">
            <button onClick={() => toggleMenu('reports')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Print/Hub <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'reports' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-[420px] bg-white/95 shadow-2xl shadow-slate-900/10 border border-slate-200 rounded-2xl overflow-hidden backdrop-blur-xl p-3 grid grid-cols-2 gap-2">
                 <div className="col-span-2 mb-1 pb-2 border-b border-slate-100 flex items-center justify-between px-2">
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">Reports & Print Hub</span>
                 </div>
                 
                 <Link onClick={closeMenu} to="/print-hub" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-indigo-50 text-indigo-600 rounded-lg group-hover:bg-indigo-500 group-hover:text-white transition-colors shadow-sm"><Printer size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Print Hub</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Batch Print GCs & GDMs</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/reports" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-blue-50 text-blue-600 rounded-lg group-hover:bg-blue-500 group-hover:text-white transition-colors shadow-sm"><BarChart3 size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Reports</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Analytics & Extracts</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/godown-planner" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-amber-50 text-amber-600 rounded-lg group-hover:bg-amber-500 group-hover:text-white transition-colors shadow-sm"><Navigation size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Godown Planner</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Floor & Loading Plan</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/party-accounts" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg group-hover:bg-emerald-500 group-hover:text-white transition-colors shadow-sm"><Users size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Party Accounts</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Customer Ledgers</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/daily-accounts" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-emerald-50 text-emerald-600 rounded-lg group-hover:bg-emerald-500 group-hover:text-white transition-colors shadow-sm"><Database size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Daily Accounts</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Day Book & Cash</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/legacy-viewer" className="group flex items-start gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-rose-50 text-rose-600 rounded-lg group-hover:bg-rose-500 group-hover:text-white transition-colors shadow-sm"><FileArchive size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Legacy Data</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">Old MS Access Archive</p>
                   </div>
                 </Link>
              </div>
            </div>
          </div>
          
          {/* SETTINGS MENU */}
          <div className="relative group">
            <button onClick={() => toggleMenu('settings')} className="px-2.5 md:px-3.5 py-1.5 rounded-md border border-white/10 hover:bg-white/10 hover:border-white/20 transition-all text-[11px] md:text-xs font-bold shadow-sm flex items-center gap-1">Settings <span className="text-[9px] md:text-[10px] opacity-70">▼</span></button>
            <div className={`absolute right-0 top-full pt-1.5 z-50 ${activeDropdown === 'settings' ? 'block' : 'hidden md:group-hover:block'}`}>
              <div className="w-[280px] bg-white/95 shadow-2xl shadow-slate-900/10 border border-slate-200 rounded-2xl overflow-hidden backdrop-blur-xl p-3 flex flex-col gap-2">
                 <div className="mb-1 pb-2 border-b border-slate-100 flex items-center justify-between px-2">
                    <span className="text-[10px] font-black text-slate-400 uppercase tracking-widest">System & Config</span>
                 </div>
                 
                 {role === 'admin' && (
                 <Link onClick={closeMenu} to="/settings/admin" className="group flex items-center gap-3 p-2.5 hover:bg-indigo-50 rounded-xl transition-all border border-transparent hover:border-indigo-100 hover:shadow-sm">
                   <div className="p-2 bg-indigo-100 text-indigo-700 rounded-lg group-hover:bg-indigo-600 group-hover:text-white transition-colors shadow-sm"><Settings size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-indigo-900">Admin Dashboard</h4>
                     <p className="text-[10px] font-medium text-indigo-500 mt-0.5 leading-tight">Manage Users & Settings</p>
                   </div>
                 </Link>
                 )}
                 
                 <Link onClick={closeMenu} to="/settings/audit-logs" className="group flex items-center gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-slate-100 text-slate-600 rounded-lg group-hover:bg-slate-600 group-hover:text-white transition-colors shadow-sm"><ShieldCheck size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Audit Trails</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">System Activity Logs</p>
                   </div>
                 </Link>
                 
                 <Link onClick={closeMenu} to="/settings/usage" className="group flex items-center gap-3 p-2.5 hover:bg-slate-50 rounded-xl transition-all border border-transparent hover:border-slate-100 hover:shadow-sm">
                   <div className="p-2 bg-slate-100 text-slate-600 rounded-lg group-hover:bg-slate-600 group-hover:text-white transition-colors shadow-sm"><Loader2 size={16}/></div>
                   <div>
                     <h4 className="text-xs font-black text-slate-800">Tech Usage</h4>
                     <p className="text-[10px] font-medium text-slate-500 mt-0.5 leading-tight">API & System Metrics</p>
                   </div>
                 </Link>
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
      <main className={`flex-1 flex flex-col w-full overflow-y-auto custom-scrollbar relative print:h-auto print:overflow-visible ${location.pathname === '/new-gc' || location.pathname === '/gdm' ? '' : 'px-4 py-4 md:px-6 md:py-6'}`}>
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

  // Auto-logout after 30 minutes of inactivity
  useEffect(() => {
    if (!role) return;

    let timeoutId;
    const INACTIVITY_LIMIT = 30 * 60 * 1000; // 30 minutes

    const resetTimer = () => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        handleLogout();
        // Use a slight delay to ensure it renders after redirect
        setTimeout(() => toast.error('Logged out due to inactivity', { icon: '🔒' }), 100);
      }, INACTIVITY_LIMIT);
    };

    // Initialize timer
    resetTimer();

    // Event listeners for activity
    const events = ['mousemove', 'keydown', 'scroll', 'click', 'touchstart'];
    events.forEach(event => window.addEventListener(event, resetTimer));

    return () => {
      clearTimeout(timeoutId);
      events.forEach(event => window.removeEventListener(event, resetTimer));
    };
  }, [role]);

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
    <QueryClientProvider client={queryClient}>
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
              <Route path="/govt-compliance" element={<GovtCompliance />} />
              
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
              <Route path="/settings/audit-logs" element={<AuditLogs />} />
              <Route path="/settings/admin" element={<AdminDashboard />} />
              <Route path="/masters/company" element={<CompanyMaster />} />
              <Route path="/masters/vehicles" element={<VehicleMaster />} />
              <Route path="/masters/drivers" element={<DriverMaster />} />
              <Route path="/masters/godowns" element={<GodownMaster />} />
              <Route path="/masters/units" element={<UnitMaster />} />
              <Route path="/masters/hsn" element={<HSNMaster />} />
              <Route path="/masters/consignors" element={<ConsignorMaster />} />
              <Route path="/masters/consignees" element={<ConsigneeMaster />} />
              <Route path="/qr-demo" element={<QrDemo />} />

            </Routes>
          </React.Suspense>
        </Layout>
      </Router>
    </QueryClientProvider>
  );
}

export default App;

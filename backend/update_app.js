const fs = require('fs');

const path = '/Users/arun_ap/Desktop/TRANSPORT ERP/frontend/src/App.jsx';
let content = fs.readFileSync(path, 'utf8');

// 1. Replace Imports
content = content.replace(
  /import { Printer, Wifi, Database, Loader2 } from 'lucide-react';\nimport { Truck } from 'lucide-react';\nimport { LogOut, AlertCircle } from 'lucide-react';/g,
  "import { Printer, Wifi, Database, Loader2, Truck, LogOut, AlertCircle, LayoutDashboard, Package, FileText, Settings, Users, ChevronDown, Menu, X } from 'lucide-react';"
);

// 2. Extract SystemStatus
const layoutRegex = /function Layout\(\{ children, role, onLogout \}\) \{[\s\S]*?\}\n\nfunction App\(\) \{/g;

const newLayout = `function Layout({ children, role, onLogout }) {
  const location = useLocation();
  const [activeMenu, setActiveMenu] = useState(null);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  // Hide header ONLY for actual print receipts
  if (location.pathname.startsWith('/print/')) {
    return <>{children}</>;
  }

  const toggleMenu = (menuName) => {
    setActiveMenu(activeMenu === menuName ? null : menuName);
  };

  const closeMenu = () => {
    if (window.innerWidth < 768) {
      setIsMobileMenuOpen(false);
    }
  };

  const SidebarContent = () => (
    <div className="flex flex-col h-full text-slate-300">
      <div className="flex items-center gap-3 px-6 py-6 border-b border-white/5">
        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-indigo-700 flex items-center justify-center shadow-inner shadow-white/20">
          <Truck className="text-white w-6 h-6" />
        </div>
        <div>
          <h1 className="text-xl font-black tracking-tight text-white leading-tight">Transport</h1>
          {localStorage.getItem('assignedBranch') === 'ALL' ? (
            <div className="text-[10px] font-bold text-indigo-400 uppercase tracking-wider mt-0.5">📍 {localStorage.getItem('activeBranch') === 'AP_BNG' ? 'AP BNG' : 'MAIN BRANCH'}</div>
          ) : (
            <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mt-0.5">ERP System</div>
          )}
        </div>
      </div>

      <div className="flex-1 overflow-y-auto py-6 px-4 space-y-2 custom-scrollbar">
        <NavLink onClick={closeMenu} to="/" className={({isActive}) => \`flex items-center gap-3 px-4 py-3 rounded-xl font-bold transition-all \${isActive ? 'bg-indigo-600 text-white shadow-md' : 'hover:bg-white/5 hover:text-white'}\`}>
          <LayoutDashboard size={18} className={location.pathname === '/' ? 'text-white' : 'text-indigo-400'} /> Dashboard
        </NavLink>
        
        {/* Warehouse */}
        <div>
           <button onClick={() => toggleMenu('warehouse')} className={\`w-full flex items-center justify-between px-4 py-3 rounded-xl font-bold transition-all hover:bg-white/5 hover:text-white \${activeMenu === 'warehouse' ? 'text-white bg-white/5' : ''}\`}>
             <div className="flex items-center gap-3">
               <Package size={18} className="text-emerald-400" /> Warehouse
             </div>
             <ChevronDown size={14} className={\`transition-transform \${activeMenu === 'warehouse' ? 'rotate-180' : ''}\`} />
           </button>
           {activeMenu === 'warehouse' && (
             <div className="pl-12 pr-4 py-2 space-y-2">
                <NavLink onClick={closeMenu} to="/warehouse-entry" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-emerald-400' : 'text-slate-400 hover:text-white'}\`}>Warehouse Entry</NavLink>
                <NavLink onClick={closeMenu} to="/warehouse-statement" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-emerald-400' : 'text-slate-400 hover:text-white'}\`}>Warehouse Statement</NavLink>
             </div>
           )}
        </div>

        {/* Entry */}
        <div>
           <button onClick={() => toggleMenu('entry')} className={\`w-full flex items-center justify-between px-4 py-3 rounded-xl font-bold transition-all hover:bg-white/5 hover:text-white \${activeMenu === 'entry' ? 'text-white bg-white/5' : ''}\`}>
             <div className="flex items-center gap-3">
               <FileText size={18} className="text-amber-400" /> Operations
             </div>
             <ChevronDown size={14} className={\`transition-transform \${activeMenu === 'entry' ? 'rotate-180' : ''}\`} />
           </button>
           {activeMenu === 'entry' && (
             <div className="pl-12 pr-4 py-2 space-y-2">
                <NavLink onClick={closeMenu} to="/new-gc" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>GC Entry</NavLink>
                <NavLink onClick={closeMenu} to="/gdm" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>GDM Entry</NavLink>
                <NavLink onClick={closeMenu} to="/freight-entry" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>Freight Entry</NavLink>
                <NavLink onClick={closeMenu} to="/lorry-hire" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>Lorry Hire</NavLink>
                <NavLink onClick={closeMenu} to="/trip-settlement" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>Trip Settlement</NavLink>
                <NavLink onClick={closeMenu} to="/legacy-rapid-entry" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>Legacy Rapid Entry</NavLink>
             </div>
           )}
        </div>

        {/* Masters */}
        <div>
           <button onClick={() => toggleMenu('masters')} className={\`w-full flex items-center justify-between px-4 py-3 rounded-xl font-bold transition-all hover:bg-white/5 hover:text-white \${activeMenu === 'masters' ? 'text-white bg-white/5' : ''}\`}>
             <div className="flex items-center gap-3">
               <Users size={18} className="text-blue-400" /> Masters
             </div>
             <ChevronDown size={14} className={\`transition-transform \${activeMenu === 'masters' ? 'rotate-180' : ''}\`} />
           </button>
           {activeMenu === 'masters' && (
             <div className="pl-12 pr-4 py-2 space-y-2">
                <NavLink onClick={closeMenu} to="/masters/consignors" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>Consignors</NavLink>
                <NavLink onClick={closeMenu} to="/masters/consignees" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>Consignees</NavLink>
                <NavLink onClick={closeMenu} to="/masters/vehicles" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>Vehicles</NavLink>
                <NavLink onClick={closeMenu} to="/masters/godowns" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>Godowns</NavLink>
                <NavLink onClick={closeMenu} to="/masters/units" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>Units</NavLink>
                <NavLink onClick={closeMenu} to="/masters/hsn" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-blue-400' : 'text-slate-400 hover:text-white'}\`}>HSN Tax</NavLink>
             </div>
           )}
        </div>

        {/* Print & Reports */}
        <div>
           <button onClick={() => toggleMenu('reports')} className={\`w-full flex items-center justify-between px-4 py-3 rounded-xl font-bold transition-all hover:bg-white/5 hover:text-white \${activeMenu === 'reports' ? 'text-white bg-white/5' : ''}\`}>
             <div className="flex items-center gap-3">
               <Printer size={18} className="text-purple-400" /> Print / Reports
             </div>
             <ChevronDown size={14} className={\`transition-transform \${activeMenu === 'reports' ? 'rotate-180' : ''}\`} />
           </button>
           {activeMenu === 'reports' && (
             <div className="pl-12 pr-4 py-2 space-y-2">
                <NavLink onClick={closeMenu} to="/print-hub" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-purple-400' : 'text-slate-400 hover:text-white'}\`}>Print Hub</NavLink>
                <NavLink onClick={closeMenu} to="/reports" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-purple-400' : 'text-slate-400 hover:text-white'}\`}>Reports</NavLink>
                <NavLink onClick={closeMenu} to="/godown-planner" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-purple-400' : 'text-slate-400 hover:text-white'}\`}>Godown Planner</NavLink>
                <NavLink onClick={closeMenu} to="/party-accounts" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-purple-400' : 'text-slate-400 hover:text-white'}\`}>Party Accounts</NavLink>
                <NavLink onClick={closeMenu} to="/daily-accounts" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-purple-400' : 'text-slate-400 hover:text-white'}\`}>Daily Accounts</NavLink>
                <NavLink onClick={closeMenu} to="/legacy-viewer" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-rose-400' : 'text-slate-400 hover:text-white'}\`}>Old ERP Data</NavLink>
             </div>
           )}
        </div>

        {/* Settings */}
        <div>
           <button onClick={() => toggleMenu('settings')} className={\`w-full flex items-center justify-between px-4 py-3 rounded-xl font-bold transition-all hover:bg-white/5 hover:text-white \${activeMenu === 'settings' ? 'text-white bg-white/5' : ''}\`}>
             <div className="flex items-center gap-3">
               <Settings size={18} className="text-slate-400" /> Settings
             </div>
             <ChevronDown size={14} className={\`transition-transform \${activeMenu === 'settings' ? 'rotate-180' : ''}\`} />
           </button>
           {activeMenu === 'settings' && (
             <div className="pl-12 pr-4 py-2 space-y-2">
                {role === 'admin' && <NavLink onClick={closeMenu} to="/settings/admin" className={({isActive}) => \`block py-1.5 text-sm font-black transition-colors \${isActive ? 'text-indigo-400' : 'text-indigo-300 hover:text-white'}\`}>Admin Dashboard</NavLink>}
                <NavLink onClick={closeMenu} to="/settings/audit-logs" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-white' : 'text-slate-400 hover:text-white'}\`}>Audit Trails</NavLink>
                <NavLink onClick={closeMenu} to="/settings/usage" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-white' : 'text-slate-400 hover:text-white'}\`}>Tech Usage</NavLink>
                <NavLink onClick={closeMenu} to="/qr-demo" className={({isActive}) => \`block py-1.5 text-sm font-semibold transition-colors \${isActive ? 'text-amber-400' : 'text-slate-400 hover:text-white'}\`}>VPA QR Test</NavLink>
             </div>
           )}
        </div>
      </div>

      <div className="p-5 border-t border-white/5 bg-black/20">
        <div className="flex items-center justify-between">
           <SystemStatus />
           <button onClick={onLogout} title="Logout" className="p-2.5 rounded-xl bg-rose-500/10 hover:bg-rose-500/30 text-rose-400 hover:text-rose-300 transition-all shadow-sm">
             <LogOut size={18} />
           </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="flex h-screen w-full bg-[#F3F4F6] selection:bg-indigo-200 overflow-hidden font-sans">
      
      {/* DESKTOP SIDEBAR */}
      <aside className="hidden md:block w-[280px] h-full bg-[#0F172A] flex-shrink-0 z-50 shadow-2xl relative">
         <SidebarContent />
      </aside>

      {/* MOBILE OVERLAY */}
      {isMobileMenuOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-40 md:hidden" onClick={() => setIsMobileMenuOpen(false)} />
      )}

      {/* MOBILE SIDEBAR */}
      <aside className={\`fixed inset-y-0 left-0 w-[280px] bg-[#0F172A] shadow-2xl z-50 transform transition-transform duration-300 md:hidden \${isMobileMenuOpen ? 'translate-x-0' : '-translate-x-full'}\`}>
         <div className="absolute top-4 right-[-52px]">
            <button onClick={() => setIsMobileMenuOpen(false)} className="p-3 bg-[#0F172A] text-white rounded-r-xl shadow-lg border border-l-0 border-white/10">
              <X size={24} />
            </button>
         </div>
         <SidebarContent />
      </aside>

      {/* MAIN CONTENT AREA */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden relative">
        
        {/* MOBILE HEADER */}
        <header className="md:hidden flex items-center justify-between p-4 bg-white border-b border-slate-200 shadow-sm z-30">
           <div className="flex items-center gap-3">
             <button onClick={() => setIsMobileMenuOpen(true)} className="p-2 hover:bg-slate-100 rounded-xl text-slate-700 transition-colors">
               <Menu size={24} />
             </button>
             <h1 className="text-xl font-black tracking-tight text-slate-800">Transport ERP</h1>
           </div>
           <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-indigo-700 flex items-center justify-center shadow-inner">
             <Truck className="text-white w-6 h-6" />
           </div>
        </header>

        {/* PAGE CONTENT */}
        <main className="flex-1 overflow-y-auto w-full relative custom-scrollbar print:h-auto print:overflow-visible">
          {children}
        </main>
      </div>
      
    </div>
  );
}

function App() {`;

content = content.replace(layoutRegex, newLayout);
fs.writeFileSync(path, content);
console.log('Successfully updated App.jsx Layout');

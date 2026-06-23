import React, { useState, useMemo } from 'react';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Search, Calculator, FileText, CheckCircle2 } from 'lucide-react';

// Specialized compact input primitives for the Premium layout
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] read-only:bg-slate-50 read-only:text-slate-500" 
      {...props} 
    />
  </div>
);

// Glassmorphic Card Wrapper Component
const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function FreightEntry() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  
  const [searchGc, setSearchGc] = useState('');
  const [companyMode, setCompanyMode] = useState('A'); // 'A' for AP, 'B' for BELL
  const [activeGc, setActiveGc] = useState(null);
  const [recentActivities, setRecentActivities] = useState([]);

  // Fetch initial recent activities
  React.useEffect(() => {
    const fetchRecent = async () => {
      try {
        const gcs = await api.get('/gcs');
        const pricedGcs = gcs.filter(gc => gc.freightTotal > 0).slice(0, 5);
        setRecentActivities(pricedGcs);
      } catch (err) {
        console.error('Failed to fetch recent freight activities', err);
      }
    };
    fetchRecent();
  }, []);

  // Editable Freight fields
  const [freightRate, setFreightRate] = useState('');
  const [advancePaid, setAdvancePaid] = useState('');

  // Hook for full keyboard flow!
  useKeyboardFlow();

  const handleSearch = async () => {
    if (!searchGc.trim()) return;
    
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      setActiveGc(null);
      const prefix = companyMode === 'A' ? 'AP-' : 'BELL-';
      const fullGcNumber = `${prefix}${searchGc.trim()}`;
      
      const res = await api.get(`/gcs/${fullGcNumber}`);
      setActiveGc(res);
      setFreightRate(res.freightRate?.toString() || '');
      setAdvancePaid(res.advancePaid?.toString() || '');
      
    } catch (err) {
      if (err.status === 404) {
        setError('GC not found. Please check the GC Number.');
      } else {
        setError('Failed to fetch GC details.');
      }
    } finally {
      setLoading(false);
    }
  };

  const handleSearchKeyDown = (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleSearch();
    }
  };

  const totalGoods = useMemo(() => {
    if (!activeGc?.goods) return 0;
    return activeGc.goods.reduce((sum, item) => sum + (item.articleCount || 0), 0);
  }, [activeGc]);

  const totalFreight = useMemo(() => {
    const rate = Number(freightRate) || 0;
    return rate * totalGoods;
  }, [freightRate, totalGoods]);

  const balanceFreight = useMemo(() => {
    const advance = Number(advancePaid) || 0;
    return totalFreight - advance;
  }, [totalFreight, advancePaid]);

  const handleSave = async () => {
    if (!activeGc) return;
    
    try {
      setLoading(true);
      setError('');
      setSuccess('');

      const payload = {
        freightRate: Number(freightRate),
        freightTotal: totalFreight,
        advancePaid: Number(advancePaid),
        balanceFreight: balanceFreight,
      };

      await api.put(`/gcs/${activeGc.id}/freight`, payload);
      setSuccess('GC Freight successfully updated!');
      
      // Update recent activities instantly
      const updatedGc = { ...activeGc, ...payload, updatedAt: new Date().toISOString() };
      setRecentActivities(prev => {
        const filtered = prev.filter(g => g.id !== updatedGc.id);
        return [updatedGc, ...filtered].slice(0, 5);
      });
      
      setTimeout(() => {
        setSuccess('');
        setActiveGc(null);
        setSearchGc('');
        setFreightRate('');
        setAdvancePaid('');
      }, 3000);
      
    } catch (err) {
      setError('Failed to update GC Freight.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-3 max-w-[900px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* 1. SEARCH SECTION */}
      <GlassCard>
        <div className="flex items-center gap-2 mb-3">
          <div className="bg-blue-50 text-blue-600 p-1.5 rounded-lg shadow-inner border border-blue-100/50"><Search size={16} /></div>
          <h3 className="font-bold text-sm text-slate-800 tracking-tight">Post-Booking Freight Entry</h3>
        </div>
        <div className="flex items-center gap-3 items-end">
           
           {/* Company Toggle */}
           <div className="flex flex-col">
             <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Company</label>
             <div className="flex bg-slate-100/80 p-0.5 rounded-lg border border-slate-200 h-9">
               <button 
                 type="button"
                 onClick={() => setCompanyMode('A')}
                 className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${companyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
               >
                 AP
               </button>
               <button 
                 type="button"
                 onClick={() => setCompanyMode('B')}
                 className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${companyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
               >
                 BELL
               </button>
             </div>
           </div>

           <div className="flex flex-col group w-48">
             <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">GC Number *</label>
             <div className="flex h-9 rounded-lg overflow-hidden border border-slate-200 bg-white focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/20 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]">
               <span className="flex items-center justify-center px-2 bg-slate-50 text-slate-500 font-bold text-xs border-r border-slate-200">
                 {companyMode === 'A' ? 'AP' : 'BELL'}-
               </span>
               <input 
                 autoFocus
                 placeholder="5000"
                 className="w-full px-2 text-sm font-black text-indigo-900 bg-transparent outline-none" 
                 value={searchGc} 
                 onChange={e => setSearchGc(e.target.value)} 
                 onKeyDown={handleSearchKeyDown}
               />
             </div>
           </div>

           <button 
             type="button" 
             onClick={handleSearch} 
             disabled={loading}
             className="h-9 px-5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold text-xs shadow-[0_2px_8px_rgba(79,70,229,0.3)] hover:shadow-[0_4px_12px_rgba(79,70,229,0.4)] transition-all flex items-center"
           >
             {loading && !activeGc ? 'Searching...' : 'Search GC'}
           </button>
        </div>
      </GlassCard>

      {error && <div className="px-5 py-3 bg-rose-50/90 backdrop-blur-sm text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">⚠️</span> {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 backdrop-blur-sm text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm flex items-center gap-2"><CheckCircle2 size={18} /> {success}</div>}

      {activeGc && (
        <>
          {/* 2. GC DETAILS (READ ONLY) */}
          <GlassCard>
            <div className="flex items-center gap-2 mb-3">
              <div className="bg-slate-100 text-slate-600 p-1.5 rounded-lg shadow-inner border border-slate-200"><FileText size={16} /></div>
              <h3 className="font-bold text-sm text-slate-800 tracking-tight">GC Details</h3>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <DenseInput label="Consignor" value={activeGc.consignor?.name || ''} readOnly tabIndex="-1" />
              <DenseInput label="Consignee" value={activeGc.consignee?.name || ''} readOnly tabIndex="-1" />
              <DenseInput label="GC Date" value={new Date(activeGc.date).toLocaleDateString()} readOnly tabIndex="-1" />
              <DenseInput label="Total Articles" value={totalGoods} readOnly tabIndex="-1" className="[&>input]:font-black [&>input]:text-indigo-900 [&>input]:bg-indigo-50/30" />
            </div>
          </GlassCard>

          {/* 3. FREIGHT CALCULATION */}
          <GlassCard>
            <div className="flex items-center gap-2 mb-3">
              <div className="bg-emerald-50 text-emerald-600 p-1.5 rounded-lg shadow-inner border border-emerald-100/50"><Calculator size={16} /></div>
              <h3 className="font-bold text-sm text-slate-800 tracking-tight">Freight Calculation</h3>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4 items-end">
              <DenseInput 
                label="Rate Per Article ₹" 
                type="number" 
                value={freightRate} 
                onChange={e => setFreightRate(e.target.value)} 
                className="[&>input]:font-bold [&>input]:text-slate-800"
              />
              
              <div className="flex flex-col group">
                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Total Freight</label>
                <div className="h-9 px-3 border border-indigo-100 rounded-lg bg-indigo-50/50 text-base font-black text-indigo-900 flex items-center shadow-inner">
                  {totalFreight.toFixed(2)}
                </div>
              </div>

              <DenseInput 
                label="Advance Received ₹" 
                type="number" 
                value={advancePaid} 
                onChange={e => setAdvancePaid(e.target.value)} 
              />
              
              <div className="flex flex-col group">
                <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Balance</label>
                <div className={`h-9 px-3 border rounded-lg text-base font-black flex items-center shadow-inner
                  ${balanceFreight > 0 ? 'bg-emerald-50 border-emerald-200 text-emerald-700' : 'bg-slate-50 border-slate-200 text-slate-700'}`}>
                  {balanceFreight.toFixed(2)}
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 mt-5 pt-4 border-t border-slate-100">
               <button type="button" tabIndex="-1" onClick={() => setActiveGc(null)} className="h-9 px-4 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 shadow-sm transition-all flex items-center">
                 Cancel
               </button>
               <button type="button" onClick={handleSave} disabled={loading} className="h-9 px-6 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg font-bold text-xs shadow-sm transition-all flex items-center gap-1.5">
                 <CheckCircle2 size={14} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Saving...' : 'Save Freight Entry'}
               </button>
            </div>
          </GlassCard>
        </>
      )}

      {/* 4. RECENT ACTIVITY AUDIT FEED */}
      {!activeGc && recentActivities.length > 0 && (
        <div className="mt-8 animate-in fade-in slide-in-from-bottom-4">
          <div className="flex items-center gap-2 mb-3 px-1">
            <div className="bg-slate-100 text-slate-500 p-1.5 rounded-lg border border-slate-200"><FileText size={16} /></div>
            <h3 className="font-bold text-sm text-slate-700 tracking-tight uppercase">Recent Freight Entries</h3>
          </div>
          <GlassCard className="!p-0 border-slate-200/60 shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-50/80 text-[10px] font-extrabold text-slate-400 uppercase tracking-wider border-b border-slate-100">
                    <th className="p-3 pl-5">GC Number</th>
                    <th className="p-3">Consignee</th>
                    <th className="p-3 text-center">Bundles</th>
                    <th className="p-3 text-right">Freight Total</th>
                    <th className="p-3 text-right pr-5">Advance</th>
                  </tr>
                </thead>
                <tbody className="text-sm font-semibold text-slate-600 divide-y divide-slate-50">
                  {recentActivities.map((gc, i) => {
                    const bundles = gc.goods ? gc.goods.reduce((s, item) => s + (item.articleCount || 0), 0) : 0;
                    return (
                      <tr key={gc.id || i} className="hover:bg-slate-50/50 transition-colors">
                        <td className="p-3 pl-5 font-bold text-indigo-700">{gc.gcNumber}</td>
                        <td className="p-3 truncate max-w-[200px]">{gc.consignee?.name || '-'}</td>
                        <td className="p-3 text-center text-slate-800 font-bold">{bundles}</td>
                        <td className="p-3 text-right font-black text-emerald-600">₹{gc.freightTotal?.toFixed(2)}</td>
                        <td className="p-3 text-right pr-5 font-medium text-slate-500">₹{gc.advancePaid?.toFixed(2) || '0.00'}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </GlassCard>
        </div>
      )}

    </div>
  );
}

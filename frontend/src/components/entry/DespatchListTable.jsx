import React from 'react';
import { GlassCard } from '../ui/DensePrimitives';
import { Button } from '../ui/Button';
import { FileText, Search, PackageCheck, Truck, Trash2, ChevronDown, Save } from 'lucide-react';

export const DespatchListTable = React.memo(({
  gcs,
  gdmCompanyMode,
  freightMode,
  setFreightMode,
  overallRate,
  setOverallRate,
  searchGcText,
  setSearchGcText,
  handleSearchGc,
  removeGc,
  totals,
  allUnitOptions,
  loading,
  success,
  error,
  handleSaveGDM,
  setIsDispatchDrawerOpen,
  page,
  totalPages,
  setPage
}) => {
  return (
    <GlassCard className="h-full flex flex-col">
      <div className="flex flex-wrap gap-4 justify-between items-center mb-5 pb-4 border-b border-slate-100">
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex items-center gap-2">
            <div className="bg-amber-50 text-amber-600 p-2 rounded-lg shadow-inner border border-amber-100/50"><FileText size={18} /></div>
            <h3 className="font-bold text-lg text-slate-800 tracking-tight whitespace-nowrap">Despatch List</h3>
          </div>
          
          <div className="hidden sm:flex items-center bg-slate-100/50 border border-slate-200 rounded-lg p-0.5 shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] transition-all">
             <select 
               className="h-8 px-2.5 bg-transparent text-xs font-bold text-slate-600 focus:outline-none cursor-pointer"
               value={freightMode}
               onChange={e => setFreightMode(e.target.value)}
             >
               <option>Use Individual GC Freight</option>
               <option>Overall Rate for GDM</option>
             </select>
             {freightMode === 'Overall Rate for GDM' && (
               <div className="flex items-center h-8 bg-white border border-slate-200 rounded-md px-2 ml-1 shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] focus-within:border-emerald-400 focus-within:ring-2 focus-within:ring-emerald-500/20 transition-all">
                 <span className="text-[10px] font-bold text-slate-400 mr-1">₹</span>
                 <input 
                   type="number" 
                   className="w-20 bg-transparent text-xs font-black text-emerald-700 focus:outline-none placeholder-slate-300" 
                   placeholder="Amount" 
                   value={overallRate} 
                   onChange={e => setOverallRate(e.target.value)} 
                 />
               </div>
             )}
          </div>
        </div>

        {/* Infinite Scroll Observer */}
        {page < totalPages && (
          <div 
            className="h-10 mt-4 flex items-center justify-center px-2"
            ref={(el) => {
              if (!el) return;
              const observer = new IntersectionObserver(
                (entries) => {
                  if (entries[0].isIntersecting) {
                    setPage(p => p + 1);
                  }
                },
                { threshold: 1.0 }
              );
              observer.observe(el);
              return () => observer.disconnect();
            }}
          >
            <div className="animate-pulse text-xs font-bold text-slate-500">Loading more...</div>
          </div>
        )}
        
        <div className="flex items-center gap-2 bg-slate-50 p-1.5 rounded-xl border border-slate-200/60 shadow-inner shrink-0 w-full sm:w-auto overflow-x-auto">
          {success && (
            <div className="h-9 px-3 bg-emerald-100 text-emerald-800 rounded-lg text-[11px] font-black tracking-wide flex items-center whitespace-nowrap border border-emerald-200 animate-in fade-in slide-in-from-right-2 duration-300">
              ✓ {success}
            </div>
          )}
          {error && (
            <div className="h-9 px-3 bg-rose-100 text-rose-800 rounded-lg text-[11px] font-black tracking-wide flex items-center whitespace-nowrap border border-rose-200 animate-in fade-in slide-in-from-right-2 duration-300">
              ⚠️ {error}
            </div>
          )}
          <div className="flex flex-col group w-48">
            <div className="flex h-9 rounded-lg overflow-hidden border border-slate-200 bg-white focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/20 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]">
              <span className="flex items-center justify-center px-2 bg-slate-50 text-slate-500 font-bold text-xs border-r border-slate-200">
                {gdmCompanyMode === 'A' ? 'AP' : 'BELL'}-
              </span>
              <input 
                id="gdm-gc-search"
                placeholder="GC Number"
                className="w-full px-2 text-sm font-black text-indigo-900 bg-transparent outline-none" 
                value={searchGcText} 
                onChange={e => setSearchGcText(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleSearchGc(); } }}
              />
            </div>
          </div>
          <Button 
            variant="primary"
            onClick={handleSearchGc}
            disabled={loading}
            className="h-9 px-4 text-xs shadow-sm flex items-center gap-1.5"
          >
            <Search size={14} /> Add
          </Button>
        </div>
      </div>

      {/* Bulk Generate Ribbon */}
      {gcs.length > 0 && gcs.some(gc => gc.ewbStatus === 'Expired' || gc.ewbStatus === 'Pending') && (
        <div className="mb-4 px-4 py-3 bg-amber-50 rounded-xl border border-amber-200 flex items-center justify-between shadow-sm animate-in fade-in slide-in-from-top-2">
          <div className="flex items-center gap-3">
            <span className="text-2xl">⚠️</span>
            <div>
              <h4 className="text-sm font-bold text-amber-900 tracking-tight">E-Way Bill Action Required</h4>
              <p className="text-[11px] font-semibold text-amber-700">Some GCs have expired or missing E-Way Bills. Regenerate them before dispatching.</p>
            </div>
          </div>
        </div>
      )}

      <div className="flex-1 overflow-x-auto">
        <table className="w-full text-left border-collapse min-w-[700px]">
          <thead>
            <tr className="bg-slate-50 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
              <th className="p-3 pl-4 rounded-tl-lg">GC No</th>
              <th className="p-3">EWB Status</th>
              <th className="p-3">Consignor</th>
              <th className="p-3">Consignee</th>
              <th className="p-3 text-center">Packages</th>
              <th className="p-3 text-right">Freight</th>
              <th className="p-3 text-center rounded-tr-lg">Action</th>
            </tr>
          </thead>
          <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-100">
            {gcs.length === 0 ? (
              <tr>
                <td colSpan="7" className="p-12 text-center text-slate-400 font-medium">
                  <div className="flex flex-col items-center justify-center gap-2">
                    <PackageCheck size={32} className="opacity-20" />
                    <p>Scan or type a GC Number above to add it to the Despatch Memo</p>
                  </div>
                </td>
              </tr>
            ) : (
              gcs.map(gc => {
                let c = 0, n = 0, b = 0, totalPkgs = 0;
                if (gc.goods) {
                  gc.goods.forEach(item => {
                    const qty = parseInt(item.articleCount) || 0;
                    totalPkgs += qty;
                    const unitStr = (item.units || '').toLowerCase().trim();
                    const match = allUnitOptions.find(o => 
                      (o.label || '').toLowerCase().trim() === unitStr || 
                      (o.code || '').toLowerCase().trim() === unitStr ||
                      (o.category || '').toLowerCase().trim() === unitStr
                    );
                    const cat = match ? (match.category || '').toLowerCase() : null;
                    if (cat === 'cases') c += qty;
                    else if (cat === 'cartons') n += qty;
                    else if (cat === 'bundles') b += qty;
                  });
                }
                
                const tallyParts = [];
                if (c > 0) tallyParts.push(`${c} C/S`);
                if (n > 0) tallyParts.push(`${n} C/N`);
                if (b > 0) tallyParts.push(`${b} BD/S`);
                const otherPkgs = totalPkgs - (c + n + b);
                if (otherPkgs > 0) tallyParts.push(`${otherPkgs} OTH`);
                const tallyStr = tallyParts.length > 0 ? tallyParts.join(' + ') : '0';
                
                // Status Badge Logic
                let badgeClass = "bg-slate-100 text-slate-600";
                if (gc.ewbStatus === 'Valid') badgeClass = "bg-emerald-100 text-emerald-700 border-emerald-200";
                else if (gc.ewbStatus === 'Expired') badgeClass = "bg-rose-100 text-rose-700 border-rose-200";
                else if (gc.ewbStatus === 'Expiring') badgeClass = "bg-amber-100 text-amber-700 border-amber-200";
                else if (gc.ewbStatus === 'Pending') badgeClass = "bg-blue-100 text-blue-700 border-blue-200";

                return (
                  <tr key={gc.id} className="hover:bg-indigo-50/30 transition-colors group">
                    <td className="p-3 pl-4 text-indigo-700 font-bold">{gc.gcNumber}</td>
                    <td className="p-3">
                      <div className="flex flex-col items-start gap-1.5">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider border ${badgeClass}`}>
                          {gc.ewbStatus || 'Unknown'} {gc.ewbAge > 0 ? `(${gc.ewbAge}d)` : ''}
                        </span>
                        {gc.ewbNumber && (
                          <span className="text-xs font-mono text-indigo-700 font-bold bg-indigo-50/50 px-1.5 py-0.5 rounded border border-indigo-100">
                            {gc.ewbNumber.replace(/(\d{4})(\d{4})(\d{4})/, '$1 $2 $3')}
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="p-3 truncate max-w-[150px]">{gc.consignor?.name || 'N/A'}</td>
                    <td className="p-3 truncate max-w-[150px]">{gc.consignee?.name || 'N/A'}</td>
                    <td className="p-3 text-center">
                      <div className="flex flex-col items-center">
                        <span className="text-slate-900 font-black">{totalPkgs}</span>
                        {tallyStr !== '0' && <span className="text-[10px] text-slate-500 font-bold">{tallyStr}</span>}
                      </div>
                    </td>
                    <td className="p-3 text-right tabular-nums">₹{gc.freightTotal?.toFixed(2) || '0.00'}</td>
                    <td className="p-3 text-center">
                      <div className="flex items-center justify-center gap-1">
                        {(gc.ewbStatus === 'Expired' || gc.ewbStatus === 'Expiring') && (
                          <Button 
                            variant="icon"
                            title="Extend / Update Part-B"
                            className="text-amber-500 hover:text-amber-700 bg-transparent hover:bg-amber-50 p-1.5 w-8 h-8"
                          >
                            <Truck size={16} />
                          </Button>
                        )}
                        <Button variant="iconDanger" onClick={() => removeGc(gc.id)} className="p-1.5 w-8 h-8 bg-transparent">
                          <Trash2 size={16} />
                        </Button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Totals Footer */}
      <div className="mt-4 pt-4 border-t border-slate-100 flex flex-col sm:flex-row justify-between items-center gap-4 bg-slate-50/50 p-4 rounded-xl border">
        
        <div className="flex flex-wrap gap-6">
          <div className="flex flex-col">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Cases</span>
            <span className="text-2xl font-black text-indigo-900">{totals.cases}</span>
          </div>
          <div className="flex flex-col border-l border-slate-200 pl-4">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Cartons</span>
            <span className="text-2xl font-black text-indigo-900">{totals.cartons}</span>
          </div>
          <div className="flex flex-col border-l border-slate-200 pl-4">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Bundles</span>
            <span className="text-2xl font-black text-indigo-900">{totals.bundles}</span>
          </div>
          {totals.others > 0 && (
            <div className="flex flex-col border-l border-slate-200 pl-4">
              <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Others</span>
              <span className="text-2xl font-black text-slate-700">{totals.others}</span>
            </div>
          )}
          <div className="flex flex-col border-l border-slate-200 pl-4">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Total Packages</span>
            <span className="text-2xl font-black text-indigo-900">{totals.total}</span>
          </div>
          <div className="flex flex-col border-l border-slate-200 pl-4">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Total Freight</span>
            <span className="text-2xl font-black text-emerald-600">₹{totals.totalFreightAmount.toFixed(2)}</span>
          </div>
        </div>

        <div className="flex gap-3">
           <Button 
             variant="secondary"
             onClick={() => handleSaveGDM('Created')}
             disabled={loading || gcs.length === 0}
             className="h-12 px-6 text-sm shadow-sm flex items-center gap-2 whitespace-nowrap"
           >
             <Save size={16} className={loading ? 'animate-pulse' : ''} /> Save Draft
           </Button>
           <Button 
             variant="primary"
             onClick={() => setIsDispatchDrawerOpen(true)}
             className="h-12 px-6 sm:px-8 bg-slate-800 hover:bg-slate-700 shadow-lg hover:shadow-xl hover:-translate-y-1 flex items-center gap-3 whitespace-nowrap !transition-all"
           >
              Proceed to Dispatch <ChevronDown className="-rotate-90" size={20} />
           </Button>
        </div>
      </div>
    </GlassCard>
  );
});

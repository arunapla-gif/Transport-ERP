import React from 'react';
import { Search, MapPin, Edit2, Trash2 } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { GlassCard } from './ConsignorForm';

export default function ConsignorTable({
  consignors,
  filteredConsignors,
  desktopTableRows,
  loading,
  hasMore,
  searchTerm,
  setSearchTerm,
  activeTab,
  setActiveTab,
  desktopObserverRef,
  mobileObserverRef,
  handleEdit,
  handleDelete,
  handleRestore,
  canEdit,
  canDelete
}) {
  const apiOnlyCount = consignors.filter(c => !c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED').length;
  const oldDataCount = consignors.filter(c => c.migrationType === 'OLD_DATA_ONLY').length;
  const mergedCount = consignors.filter(c => c.migrationType === 'MERGED_NAME').length;

  return (
    <GlassCard className="!p-0 mt-4">
      <div className="p-4 border-b border-slate-100 flex flex-col md:flex-row justify-between items-start md:items-center gap-3 bg-slate-50/50">
        <div className="flex bg-slate-200/50 p-1 rounded-lg w-full md:w-auto">
           <Button variant="custom" onClick={() => setActiveTab('API_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'API_ONLY' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>API Data ({apiOnlyCount})</Button>
           <Button variant="custom" onClick={() => setActiveTab('OLD_DATA_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'OLD_DATA_ONLY' ? 'bg-white text-rose-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Kept Old Data ({oldDataCount})</Button>
           <Button variant="custom" onClick={() => setActiveTab('MERGED_NAME')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'MERGED_NAME' ? 'bg-white text-blue-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Merged Names ({mergedCount})</Button>
        </div>
        <div className="relative w-full md:w-auto group">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 md:w-3.5 md:h-3.5 group-focus-within:text-indigo-500 transition-colors z-10" />
          {/* The Glow */}
          <div className="absolute inset-0 bg-indigo-500/20 blur-md rounded-lg opacity-0 group-focus-within:opacity-100 transition-opacity duration-500"></div>
          <input 
            type="text" 
            placeholder="Search party..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="relative h-12 md:h-8 pl-10 md:pl-9 pr-3 w-full md:w-64 border border-slate-200 rounded-xl md:rounded-lg bg-white/90 backdrop-blur text-base md:text-xs focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 shadow-sm transition-all duration-300"
          />
        </div>
      </div>

      <>
        {/* MOBILE CARDS VIEW */}
      <div className="md:hidden divide-y divide-slate-100 max-h-[60vh] overflow-y-auto">
        {filteredConsignors.length > 0 ? filteredConsignors.map((c, index) => (
          <div key={c.id} className={`p-4 bg-white hover:bg-slate-50 transition-colors ${c.isActive === false ? 'opacity-60 bg-slate-50 border-slate-300' : ''}`}>
            <div className="flex justify-between items-start mb-2">
              <div className="pr-2">
                <h4 className="font-black text-slate-800 text-base leading-tight flex flex-wrap items-center gap-1.5">
                  <span className="text-slate-400 font-bold mr-1 text-sm">{index + 1}.</span>
                  {c.isActive === false && <span title="Archived Record" className="flex items-center justify-center bg-slate-200 text-slate-700 px-1.5 rounded border border-slate-300 text-[10px] font-black shrink-0 whitespace-nowrap">ARCHIVED</span>}
                  {c.name}
                  {c.gstin && c.migrationType === 'GST_VERIFIED' && <span title="Fully Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0">✓</span>}
                  {c.migrationType === 'EWB_LITE' && <span title="Partial Profile - Verify GST" className="flex items-center justify-center bg-amber-100 text-amber-700 px-1.5 rounded border border-amber-300 text-[10px] font-black shrink-0 whitespace-nowrap">⚠️ EWB Lite</span>}
                </h4>
                {c.legalName && c.legalName !== c.name && (
                  <p className="text-[11px] font-semibold text-slate-500 mt-1">Legal: {c.legalName}</p>
                )}
                {Array.isArray(c.tradeNames) && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name && (
                  <p className="text-[11px] font-semibold text-slate-500 mt-0.5">Trade: {c.tradeNames.join(', ')}</p>
                )}
                <p className="text-xs font-bold text-indigo-600 mt-1 uppercase tracking-wider">{c.gstin || 'NO GSTIN'}</p>
                {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                  <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200 mt-1 inline-block">+{c.addresses.length} Addr</span>
                )}
              </div>
              <div className="flex gap-2 shrink-0">
                {canEdit && <Button variant="secondary" onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-blue-600 bg-blue-50 hover:bg-blue-100 border-blue-200 shadow-none"><Edit2 size={14} /><span className="text-xs">Edit</span></Button>}
                {canDelete && c.isActive !== false && <Button variant="secondary" onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-amber-600 bg-amber-50 hover:bg-amber-100 border-amber-200 shadow-none"><Trash2 size={14} /><span className="text-xs">Archive</span></Button>}
                {canDelete && c.isActive === false && <Button variant="secondary" onClick={() => handleRestore(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-emerald-600 bg-emerald-50 hover:bg-emerald-100 border-emerald-200 shadow-none"><span className="text-xs">Restore</span></Button>}
              </div>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm font-medium text-slate-600 mt-4 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
              <div className="flex items-center gap-1.5 truncate"><MapPin size={14} className="text-slate-400 shrink-0"/> <span className="truncate">{c.city || '-'}</span></div>
              <div className="flex items-center gap-1.5 truncate">📞 <span className="truncate">{c.phone || '-'}</span></div>
            </div>
          </div>
        )) : (
          <div className="p-8 text-center font-bold text-slate-500 text-sm">No records found.</div>
        )}
      </div>

      {/* DESKTOP TABLE VIEW - PREMIUM DATA GRID */}
      <div className="hidden md:block overflow-x-auto max-h-[500px] overflow-y-auto custom-scrollbar border border-slate-200/60 rounded-b-xl rounded-t-none">
        <table className="w-full text-sm text-left border-collapse">
          <thead className="text-[11px] font-black text-slate-500 uppercase tracking-wider bg-slate-50/95 sticky top-0 backdrop-blur-xl z-20 shadow-[0_1px_3px_rgba(0,0,0,0.05)]">
            <tr>
              <th className="px-4 py-3 w-12 text-center border-b border-slate-200">#</th>
              <th className="px-4 py-3 w-[40%] border-b border-slate-200">Consignor Details</th>
              <th className="px-4 py-3 w-[20%] border-b border-slate-200">Location</th>
              <th className="px-4 py-3 border-b border-slate-200">Tax ID (GSTIN)</th>
              <th className="px-4 py-3 border-b border-slate-200">Contact</th>
              <th className="px-4 py-3 text-right sticky right-0 bg-slate-50/95 backdrop-blur-xl z-30 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.05)] border-l border-b border-slate-200">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            {desktopTableRows}
            {hasMore && (
              <tr>
                <td colSpan="6" className="py-6 text-center text-slate-500 font-medium" ref={desktopObserverRef}>
                  {loading ? (
                    <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span>
                  ) : 'Scroll for more'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
      
      {/* MOBILE OBSERVER DIV (only shown on mobile if desktop hidden) */}
      <div className="md:hidden p-4 text-center text-slate-500 text-sm font-medium" ref={mobileObserverRef}>
         {hasMore && (loading ? 'Loading more...' : 'Scroll for more')}
      </div>
      </>
    </GlassCard>
  );
}

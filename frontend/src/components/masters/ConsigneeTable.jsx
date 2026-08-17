import React from 'react';
import { Search, MapPin, Edit2, Trash2 } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { GlassCard } from './ConsigneeForm';

export default function ConsigneeTable({
  consignees,
  loading,
  hasMore,
  searchTerm,
  setSearchTerm,
  activeTab,
  setActiveTab,
  desktopObserverRef,
  mobileObserverRef,
  updateConsigneeName,
  handleEdit,
  handleDelete,
  handleRestore
}) {
  const apiOnlyCount = consignees.filter(c => !c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED').length;
  const oldDataCount = consignees.filter(c => c.migrationType === 'OLD_DATA_ONLY').length;
  const retailPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_WITH_PHONE').length;
  const retailNoPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_NO_PHONE').length;

  const filteredConsignees = consignees.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
      (c.gstin && c.gstin.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (c.city && c.city.toLowerCase().includes(searchTerm.toLowerCase()));
      
    if (activeTab === 'API_ONLY') return matchesSearch && (!c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED');
    if (activeTab === 'OLD_DATA_ONLY') return matchesSearch && c.migrationType === 'OLD_DATA_ONLY';
    if (activeTab === 'RETAIL_WITH_PHONE') return matchesSearch && c.migrationType === 'RETAIL_WITH_PHONE';
    if (activeTab === 'RETAIL_NO_PHONE') return matchesSearch && c.migrationType === 'RETAIL_NO_PHONE';
    return false;
  });

  return (
    <GlassCard className="!p-0 mt-4">
      <div className="p-4 border-b border-slate-100 flex flex-col md:flex-row justify-between items-start md:items-center gap-3 bg-slate-50/50">
        <div className="flex bg-slate-200/50 p-1 rounded-lg w-full md:w-auto">
            <Button variant="custom" onClick={() => setActiveTab('API_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'API_ONLY' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>API Data ({apiOnlyCount})</Button>
            <Button variant="custom" onClick={() => setActiveTab('OLD_DATA_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'OLD_DATA_ONLY' ? 'bg-white text-rose-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Kept Old Data ({oldDataCount})</Button>
            <Button variant="custom" onClick={() => setActiveTab('RETAIL_WITH_PHONE')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'RETAIL_WITH_PHONE' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Retail (Has Phone) ({retailPhoneCount})</Button>
            <Button variant="custom" onClick={() => setActiveTab('RETAIL_NO_PHONE')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'RETAIL_NO_PHONE' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Retail (No Phone) ({retailNoPhoneCount})</Button>
        </div>
        <div className="relative w-full md:w-auto">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 md:w-3.5 md:h-3.5" />
          <input 
            type="text" 
            placeholder="Search party..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="h-12 md:h-8 pl-10 md:pl-9 pr-3 w-full md:w-64 border border-slate-200 rounded-xl md:rounded-lg bg-white text-base md:text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 shadow-sm md:shadow-none"
          />
        </div>
      </div>

      <>
      {/* MOBILE CARDS VIEW */}
      <div className="md:hidden divide-y divide-slate-100 max-h-[60vh] overflow-y-auto">
        {filteredConsignees.length > 0 ? filteredConsignees.map((c, index) => (
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
                {c.parentId && (
                  <p className="text-[11px] font-bold text-indigo-600 mt-1 bg-indigo-50 px-1.5 py-0.5 rounded inline-block">Parent: {consignees.find(p => p.id === c.parentId)?.name}</p>
                )}
                {Array.isArray(c.tradeNames) && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name && (
                  <p className="text-[11px] font-semibold text-slate-500 mt-0.5">Trade: {c.tradeNames.join(', ')}</p>
                )}
                <p className="text-xs font-bold text-emerald-600 mt-1 uppercase tracking-wider">{c.gstin || 'NO GSTIN'}</p>
                {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                  <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200 mt-1 inline-block">+{c.addresses.length} Addr</span>
                )}
              </div>
              <div className="flex gap-2 shrink-0 opacity-100">
                <Button variant="secondary" onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-blue-600 bg-blue-50 hover:bg-blue-100 border-blue-200 shadow-none"><Edit2 size={14} /><span className="text-xs">Edit</span></Button>
                {c.isActive !== false && <Button variant="secondary" onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-amber-600 bg-amber-50 hover:bg-amber-100 border-amber-200 shadow-none"><Trash2 size={14} /><span className="text-xs">Archive</span></Button>}
                {c.isActive === false && <Button variant="secondary" onClick={() => handleRestore(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-emerald-600 bg-emerald-50 hover:bg-emerald-100 border-emerald-200 shadow-none"><span className="text-xs">Restore</span></Button>}
              </div>
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm font-medium text-slate-600 mt-4 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
              <div className="flex items-center gap-1.5 truncate"><MapPin size={14} className="text-slate-400 shrink-0"/> <span className="truncate">{c.city || '-'}</span></div>
              <div className="flex items-center gap-1.5 truncate">📞 <span className="truncate">{c.phone || '-'}</span></div>
            </div>
          </div>
        )) : (
          !loading && <div className="p-8 text-center font-bold text-slate-500 text-sm">No records found.</div>
        )}
        
        <div className="md:hidden p-4 text-center text-slate-500 text-sm font-medium" ref={mobileObserverRef}>
           {hasMore && (loading ? 'Loading more...' : 'Scroll for more')}
        </div>
      </div>

      {/* DESKTOP TABLE VIEW */}
      <div className="hidden md:block overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
        <table className="w-full text-sm text-left">
          <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
            <tr>
              <th className="px-3 py-2 font-bold uppercase tracking-wider w-12 text-center">S.No</th>
              <th className="px-3 py-2 font-bold uppercase tracking-wider w-[40%]">Name</th>
              <th className="px-3 py-2 font-bold uppercase tracking-wider w-[20%]">City</th>
              <th className="px-3 py-2 font-bold uppercase tracking-wider">GSTIN</th>
              <th className="px-3 py-2 font-bold uppercase tracking-wider">Phone</th>
              <th className="px-3 py-2 font-bold uppercase tracking-wider text-right sticky right-0 bg-slate-50/95 backdrop-blur-md z-20 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.05)] border-l border-slate-100">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredConsignees.length > 0 ? filteredConsignees.map((c, index) => (
              <tr key={c.id} className={`hover:bg-slate-50/80 transition-colors group ${c.isActive === false ? 'opacity-60 bg-slate-50' : ''}`}>
                <td className="px-3 py-3 font-bold text-slate-400 text-center">{index + 1}</td>
                <td className="px-3 py-2 font-medium text-slate-800">
                  <div className="flex flex-col">
                    <div className="flex items-center gap-2">
                      {c.name}
                      {c.isActive === false && <span title="Archived Record" className="flex items-center justify-center bg-slate-200 text-slate-700 px-1.5 rounded border border-slate-300 text-[10px] font-black shrink-0 whitespace-nowrap">ARCHIVED</span>}
                      {c.gstin && c.migrationType === 'GST_VERIFIED' && <span title="Fully Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0">✓</span>}
                      {c.migrationType === 'EWB_LITE' && <span title="Partial Profile - Verify GST" className="flex items-center justify-center bg-amber-100 text-amber-700 px-1.5 rounded border border-amber-300 text-[10px] font-black shrink-0 whitespace-nowrap">⚠️ EWB Lite</span>}
                    </div>
                    
                    {c.legalName && (
                      <span className="text-[11px] text-slate-500 font-medium mt-1">Legal: {c.legalName}</span>
                    )}
                    {c.parentId && (
                      <span className="text-[11px] font-bold text-indigo-600 mt-1">Parent: {consignees.find(p => p.id === c.parentId)?.name}</span>
                    )}
                    
                    {(() => {
                      const allNames = Array.from(new Set([c.name, ...(c.tradeNames || []), c.legalName].filter(Boolean)));
                      if (allNames.length > 1) {
                        return (
                          <div className="flex items-center gap-1 mt-1">
                            <span className="text-[11px] text-slate-500 font-medium">Trade:</span>
                            <select 
                              className="text-[11px] border border-slate-200 rounded px-1 py-0.5 bg-slate-50 focus:outline-none focus:ring-1 focus:ring-emerald-500 max-w-[200px]"
                              value={c.name}
                              onChange={(e) => {
                                if (e.target.value !== c.name) {
                                  updateConsigneeName(c.id, e.target.value);
                                }
                              }}
                            >
                              {allNames.map((n, idx) => (
                                <option key={idx} value={n}>{n}</option>
                              ))}
                            </select>
                          </div>
                        );
                      } else if (c.tradeNames && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name) {
                        return <span className="text-[11px] text-slate-500 font-medium mt-1">Trade: {c.tradeNames.join(', ')}</span>;
                      }
                      return null;
                    })()}
                  </div>
                </td>
                <td className="px-3 py-2 text-slate-600">
                  <div className="flex flex-col">
                    <span>{c.city || '-'}</span>
                    {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                      <span className="text-[10px] text-amber-600 font-medium mt-0.5">+{c.addresses.length} Addr</span>
                    )}
                  </div>
                </td>
                <td className="px-3 py-2 text-slate-600 font-mono text-xs uppercase">{c.gstin || '-'}</td>
                <td className="px-3 py-2 text-slate-600">{c.phone || '-'}</td>
                <td className="px-3 py-2 sticky right-0 bg-white z-10 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.03)] border-l border-slate-50 group-hover:bg-slate-50/50 transition-colors">
                  <div className="flex justify-end gap-2 opacity-100">
                    <Button variant="secondary" onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 h-auto bg-blue-50 text-blue-600 hover:bg-blue-100 border-blue-200 whitespace-nowrap shadow-none">
                      <Edit2 size={14} /> <span className="text-xs hidden lg:inline">Edit</span>
                    </Button>
                    {c.isActive !== false && (
                      <Button variant="secondary" onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto bg-amber-50 text-amber-600 hover:bg-amber-100 border-amber-200 whitespace-nowrap shadow-none">
                        <Trash2 size={14} /> <span className="text-xs hidden lg:inline">Archive</span>
                      </Button>
                    )}
                    {c.isActive === false && (
                      <Button variant="secondary" onClick={() => handleRestore(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto bg-emerald-50 text-emerald-600 hover:bg-emerald-100 border-emerald-200 whitespace-nowrap shadow-none">
                        <span className="text-xs hidden lg:inline">Restore</span>
                      </Button>
                    )}
                  </div>
                </td>
              </tr>
            )) : (
              !loading && (
                <tr>
                  <td colSpan="6" className="px-4 py-8 text-center text-slate-500 text-sm">No records found.</td>
                </tr>
              )
            )}
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
      </>
    </GlassCard>
  );
}

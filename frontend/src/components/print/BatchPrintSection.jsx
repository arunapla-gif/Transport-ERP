import React, { memo } from 'react';
import { Search, CheckSquare, Printer } from 'lucide-react';
import { Button } from '../ui/Button';

export const BatchPrintSection = memo(({
  activeTab,
  setActiveTab,
  gcSearchTerm,
  setGcSearchTerm,
  gdmSearchTerm,
  setGdmSearchTerm,
  handleOpenCopiesModal,
  handleOpenGdmFormatModal,
  selectedGcs,
  selectedGdms,
  toggleGcSelection,
  toggleGdmSelection,
  toggleAllGcs,
  toggleAllGdms,
  recentGcs,
  recentGdms,
  hasMoreGcs,
  hasMoreGdms,
  loading,
  gcObserverRef,
  gdmObserverRef
}) => {
  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
      {/* Tabs */}
      <div className="flex border-b border-slate-200 bg-slate-50/50 pt-2 px-4 gap-2">
        <Button variant="custom" 
          onClick={() => setActiveTab('GC')}
          className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GC' ? 'bg-white border-indigo-600 text-indigo-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
        >
          All GCs
        </Button>
        <Button variant="custom" 
          onClick={() => setActiveTab('GDM')}
          className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GDM' ? 'bg-white border-emerald-600 text-emerald-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
        >
          All GDMs
        </Button>
      </div>

      {/* Tab Content Header */}
      <div className="p-5 border-b border-slate-100 flex flex-col md:flex-row items-center justify-between bg-white gap-4">
        <div>
          <h2 className="text-lg font-black text-slate-800 flex items-center gap-2">
            <CheckSquare className={activeTab === 'GC' ? "text-indigo-600" : "text-emerald-600"} size={20} />
            Batch Print {activeTab === 'GC' ? 'GCs' : 'GDMs'}
          </h2>
          <p className="text-xs font-semibold text-slate-500 mt-0.5">Select multiple documents to print them all in one go.</p>
        </div>
        
        <div className="flex gap-4 items-center w-full md:w-auto">
           <div className="relative flex-1 md:w-64">
              <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input 
                type="text" 
                placeholder={`Search ${activeTab === 'GC' ? 'GCs...' : 'GDMs...'}`} 
                value={activeTab === 'GC' ? gcSearchTerm : gdmSearchTerm}
                onChange={(e) => activeTab === 'GC' ? setGcSearchTerm(e.target.value) : setGdmSearchTerm(e.target.value)}
                className="w-full h-10 pl-9 pr-3 border border-slate-200 rounded-lg bg-slate-50 text-xs font-bold text-slate-700 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"
              />
           </div>
           
          {activeTab === 'GC' ? (
            <Button variant="custom" 
              onClick={(e) => handleOpenCopiesModal(e, selectedGcs.join(','))}
              disabled={selectedGcs.length === 0}
              className={`h-10 px-6 shrink-0 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGcs.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={16} /> Print Selected ({selectedGcs.length})
            </Button>
          ) : (
            <Button variant="custom" 
              onClick={(e) => handleOpenGdmFormatModal(e, selectedGdms.join(','))}
              disabled={selectedGdms.length === 0}
              className={`h-10 px-6 shrink-0 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGdms.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={16} /> Print Selected ({selectedGdms.length})
            </Button>
          )}
        </div>
      </div>

      {/* Tab Content Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse">
          <thead>
            {activeTab === 'GC' ? (
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="px-4 py-3 w-12 text-center">
                  <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" onChange={toggleAllGcs} checked={recentGcs.length > 0 && selectedGcs.length === recentGcs.length} />
                </th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">GC No.</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Date</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Consignor</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Consignee</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-center">Bundles</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">Freight</th>
              </tr>
            ) : (
              <tr className="bg-slate-50 border-b border-slate-200">
                <th className="px-4 py-3 w-12 text-center">
                  <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500" onChange={toggleAllGdms} checked={recentGdms.length > 0 && selectedGdms.length === recentGdms.length} />
                </th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">GDM No.</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Date</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Vehicle</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Destination</th>
                <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">GCs Linked</th>
              </tr>
            )}
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            {loading && recentGcs.length === 0 && recentGdms.length === 0 ? (
              <tr><td colSpan="7" className="p-8 text-center text-slate-400 font-semibold animate-pulse">Loading records...</td></tr>
            ) : activeTab === 'GC' ? (
              <>
                {recentGcs.length === 0 ? (
                  <tr><td colSpan="7" className="p-8 text-center text-slate-400 font-semibold">No GCs found.</td></tr>
                ) : (
                  recentGcs.map((gc) => (
                    <tr key={gc.id} className={`hover:bg-slate-50 transition-colors cursor-pointer ${selectedGcs.includes(gc.gcNumber) ? 'bg-indigo-50/50' : ''}`} onClick={() => toggleGcSelection(gc.gcNumber)}>
                      <td className="px-4 py-3 text-center">
                        <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" checked={selectedGcs.includes(gc.gcNumber)} readOnly />
                      </td>
                      <td className="px-4 py-3"><span className="font-bold text-slate-800">{gc.gcNumber}</span></td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600">{gc.date ? new Date(gc.date).toLocaleDateString('en-GB') : '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gc.consignor?.name || '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gc.consignee?.name || '-'}</td>
                      <td className="px-4 py-3 text-sm font-bold text-slate-800 text-center">{gc.goods?.reduce((sum, g) => sum + (g.articleCount || 0), 0) || 0}</td>
                      <td className="px-4 py-3 text-sm font-bold text-emerald-600 text-right">₹{gc.freightTotal?.toFixed(2) || '0.00'}</td>
                    </tr>
                  ))
                )}
                {hasMoreGcs && (
                  <tr ref={gcObserverRef}>
                    <td colSpan="7" className="p-6 text-center text-slate-500 font-medium">
                      {loading ? <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span> : 'Scroll for more'}
                    </td>
                  </tr>
                )}
              </>
            ) : (
              <>
                {recentGdms.length === 0 ? (
                  <tr><td colSpan="6" className="p-8 text-center text-slate-400 font-semibold">No GDMs found.</td></tr>
                ) : (
                  recentGdms.map((gdm) => (
                    <tr key={gdm.id} className={`hover:bg-slate-50 transition-colors cursor-pointer ${selectedGdms.includes(gdm.gdmNumber) ? 'bg-emerald-50/50' : ''}`} onClick={() => toggleGdmSelection(gdm.gdmNumber)}>
                      <td className="px-4 py-3 text-center">
                        <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500" checked={selectedGdms.includes(gdm.gdmNumber)} readOnly />
                      </td>
                      <td className="px-4 py-3"><span className="font-bold text-slate-800">{gdm.gdmNumber}</span></td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600">{gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gdm.vehicle?.vehicleNumber || '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gdm.toName || '-'}</td>
                      <td className="px-4 py-3 text-sm font-bold text-slate-800 text-right">{gdm.gcs?.length || 0}</td>
                    </tr>
                  ))
                )}
                {hasMoreGdms && (
                  <tr ref={gdmObserverRef}>
                    <td colSpan="6" className="p-6 text-center text-slate-500 font-medium">
                      {loading ? <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span> : 'Scroll for more'}
                    </td>
                  </tr>
                )}
              </>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
});

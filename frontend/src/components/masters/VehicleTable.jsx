import React from 'react';
import { Search, Edit2, Trash2 } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import { GlassCard } from './VehicleForm';

export default function VehicleTable({
  vehicles,
  filteredVehicles,
  totalRecords,
  loading,
  hasMore,
  searchTerm,
  setSearchTerm,
  desktopObserverRef,
  handleEdit,
  handleDelete
}) {
  return (
    <GlassCard className="!p-0">
      <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
        <h3 className="font-bold text-sm text-slate-800">Saved Vehicles <span className="text-slate-400 font-medium ml-1">({totalRecords || vehicles.length})</span></h3>
        <div className="relative">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input 
            type="text" 
            placeholder="Search lorry or driver..." 
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="h-8 pl-9 pr-3 w-64 border border-slate-200 rounded-lg bg-white text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
          />
        </div>
      </div>
      <div className="overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
        <table className="w-full text-sm text-left">
          <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
            <tr>
              <th className="px-4 py-3 font-bold uppercase tracking-wider w-12 text-center">S.No</th>
              <th className="px-4 py-3 font-bold uppercase tracking-wider">Vehicle No</th>
              <th className="px-4 py-3 font-bold uppercase tracking-wider">Type</th>
              <th className="px-4 py-3 font-bold uppercase tracking-wider">Owner</th>
              <th className="px-4 py-3 font-bold uppercase tracking-wider text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredVehicles.length > 0 ? filteredVehicles.map((v, index) => (
              <tr key={v.id} className="hover:bg-slate-50/50 transition-colors group">
                <td className="px-4 py-3 font-bold text-slate-400 text-center">{index + 1}</td>
                <td className="px-4 py-3 font-bold text-emerald-700">
                  <div className="flex items-center gap-2">
                     {v.vehicleNumber}
                     {v.rcVerified && <span title="VAHAN Verified" className="bg-blue-100 text-blue-700 text-[8px] px-1.5 py-0.5 rounded-sm uppercase tracking-wider font-black">Verified</span>}
                  </div>
                </td>
                <td className="px-4 py-3 text-slate-600">
                  <div>{v.type || '-'}</div>
                  <div className="text-[10px] uppercase font-bold text-slate-400 mt-0.5">{v.ladenType || 'Open Body'}</div>
                </td>
                <td className="px-4 py-3 text-slate-600">
                  <div className="text-xs truncate max-w-[150px]" title={v.ownerName}>{v.ownerName || '-'}</div>
                  {v.ownerPhone && <div className="text-[10px] text-slate-400 mt-0.5">Ph1: {v.ownerPhone}</div>}
                  {v.ownerPhone2 && <div className="text-[10px] text-slate-400 mt-0.5">Ph2: {v.ownerPhone2}</div>}
                </td>
                <td className="px-4 py-3">
                  <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <Button variant="icon" onClick={() => handleEdit(v)}><Edit2 size={14} /></Button>
                    <Button variant="iconDanger" onClick={() => handleDelete(v.id)}><Trash2 size={14} /></Button>
                  </div>
                </td>
              </tr>
            )) : (
              !loading && (
                <tr>
                  <td colSpan="5" className="px-4 py-8 text-center text-slate-500 text-sm">No records found.</td>
                </tr>
              )
            )}
            {hasMore && (
              <tr>
                <td colSpan="5" className="py-6 text-center text-slate-500 font-medium" ref={desktopObserverRef}>
                  {loading ? (
                    <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span>
                  ) : 'Scroll for more'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </GlassCard>
  );
}

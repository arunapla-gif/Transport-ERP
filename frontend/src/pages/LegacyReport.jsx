import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Database, Package, Truck, Search, Archive, Clock } from 'lucide-react';

export default function LegacyReport() {
  const [legacyGcs, setLegacyGcs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('All'); // All, Pending, Dispatched

  useEffect(() => {
    fetchLegacyData();
  }, []);

  const fetchLegacyData = async () => {
    try {
      setLoading(true);
      const data = await api.get('/gcs');
      // Filter only legacy entries
      const filtered = data.filter(gc => gc.gcNumber?.startsWith('LEGACY-'));
      setLegacyGcs(filtered);
    } catch (err) {
      console.error("Failed to fetch legacy GCs", err);
    } finally {
      setLoading(false);
    }
  };

  const filteredData = legacyGcs.filter(gc => {
    const matchesSearch = 
      gc.gcNumber.toLowerCase().includes(search.toLowerCase()) ||
      gc.consignor?.name?.toLowerCase().includes(search.toLowerCase()) ||
      gc.consignee?.name?.toLowerCase().includes(search.toLowerCase());
    
    if (filter === 'Pending') return matchesSearch && gc.status === 'Created';
    if (filter === 'Dispatched') return matchesSearch && gc.status === 'Dispatched';
    return matchesSearch;
  });

  const pendingCount = legacyGcs.filter(g => g.status === 'Created').length;
  const dispatchedCount = legacyGcs.filter(g => g.status === 'Dispatched').length;

  return (
    <div className="max-w-[1400px] mx-auto py-8 px-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* Header */}
      <div className="flex justify-between items-end mb-8">
        <div className="flex items-center gap-4">
          <div className="bg-amber-100 text-amber-700 p-3 rounded-2xl shadow-sm">
            <Database size={28} />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight">Legacy Data Upload Report</h1>
            <p className="text-sm font-bold text-slate-500">Read-only view of historical Excel records</p>
          </div>
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
        <div className="bg-white p-5 rounded-xl border border-slate-200 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-slate-400 uppercase">Total Imported</p>
            <p className="text-3xl font-black text-slate-800">{legacyGcs.length}</p>
          </div>
          <div className="h-12 w-12 rounded-full bg-slate-50 flex items-center justify-center text-slate-400"><Database size={24} /></div>
        </div>
        <div className="bg-gradient-to-br from-indigo-50 to-white p-5 rounded-xl border border-indigo-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-indigo-500 uppercase">Pending In Godown</p>
            <p className="text-3xl font-black text-indigo-900">{pendingCount}</p>
          </div>
          <div className="h-12 w-12 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600"><Clock size={24} /></div>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-xl border border-emerald-100 shadow-sm flex items-center justify-between">
          <div>
            <p className="text-xs font-bold text-emerald-500 uppercase">Dispatched Archive</p>
            <p className="text-3xl font-black text-emerald-900">{dispatchedCount}</p>
          </div>
          <div className="h-12 w-12 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-600"><Archive size={24} /></div>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white p-4 rounded-xl shadow-sm border border-slate-200 flex flex-wrap justify-between items-center gap-4 mb-6">
        <div className="flex items-center gap-2">
          {['All', 'Pending', 'Dispatched'].map(f => (
            <button 
              key={f}
              onClick={() => setFilter(f)}
              className={`px-4 py-2 rounded-lg text-sm font-bold transition-all ${filter === f ? 'bg-slate-800 text-white shadow-md' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}
            >
              {f}
            </button>
          ))}
        </div>
        <div className="relative w-72">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none text-slate-400">
            <Search size={16} />
          </div>
          <input 
            type="text" 
            placeholder="Search GC, Consignor..." 
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full h-10 pl-10 pr-4 bg-slate-50 border border-slate-200 rounded-lg text-sm font-bold text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
          />
        </div>
      </div>

      {/* Data Table */}
      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="overflow-x-auto">
          {loading ? (
            <div className="p-10 text-center font-bold text-slate-400 animate-pulse">Loading Legacy Data...</div>
          ) : (
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200">
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Legacy GC No</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Date</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Consignor</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Consignee</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Articles</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Status</th>
                  <th className="p-4 text-xs font-black text-slate-500 uppercase">Dispatch Lorry</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-sm font-semibold text-slate-700">
                {filteredData.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="p-8 text-center text-slate-400">No records found.</td>
                  </tr>
                ) : (
                  filteredData.map(gc => {
                    const totalArticles = gc.goods?.reduce((acc, curr) => acc + (curr.articleCount || 0), 0) || 0;
                    const isPending = gc.status === 'Created';
                    
                    return (
                      <tr key={gc.id} className="hover:bg-slate-50/50">
                        <td className="p-4 font-black text-slate-800">{gc.gcNumber.replace('LEGACY-', '')}</td>
                        <td className="p-4">{new Date(gc.date).toLocaleDateString('en-IN')}</td>
                        <td className="p-4">
                          <span className="truncate max-w-[200px] inline-block">{gc.consignor?.name}</span>
                        </td>
                        <td className="p-4">
                          <span className="truncate max-w-[200px] inline-block">{gc.consignee?.name}</span>
                        </td>
                        <td className="p-4 text-indigo-700 font-black">{totalArticles} {gc.goods?.[0]?.units || 'Units'}</td>
                        <td className="p-4">
                          {isPending ? (
                            <span className="px-2.5 py-1 bg-indigo-50 text-indigo-700 rounded text-xs font-bold border border-indigo-100">In Godown</span>
                          ) : (
                            <span className="px-2.5 py-1 bg-emerald-50 text-emerald-700 rounded text-xs font-bold border border-emerald-100">Dispatched</span>
                          )}
                        </td>
                        <td className="p-4">
                          {gc.gdm ? (
                            <div className="flex items-center gap-1.5 text-slate-600">
                              <Truck size={14} className="text-slate-400" />
                              {gc.gdm.vehicle?.vehicleNumber || 'Unknown'}
                            </div>
                          ) : (
                            <span className="text-slate-300">-</span>
                          )}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}

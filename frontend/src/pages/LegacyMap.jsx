import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Network, Search, CheckCircle2, MapPin, ArrowDownToLine, AlertCircle } from 'lucide-react';

const LegacyMap = () => {
  const [activeTab, setActiveTab] = useState('consignor');
  const [mappings, setMappings] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [selectedGhosts, setSelectedGhosts] = useState({}); // { masterId: [ghostId1, ghostId2] }

  const fetchMappings = async (type) => {
    setLoading(true);
    setError('');
    setSelectedGhosts({});
    try {
      const res = await api.get(`/legacy/mappings?type=${type}`);
      setMappings(res);
      
      // Auto-select all suggestions by default
      const initialSelection = {};
      res.forEach(master => {
        initialSelection[master.id] = master.suggestions.map(s => s.id);
      });
      setSelectedGhosts(initialSelection);
    } catch (err) {
      setError('Failed to load legacy mappings.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMappings(activeTab);
  }, [activeTab]);

  const toggleGhostSelection = (masterId, ghostId) => {
    setSelectedGhosts(prev => {
      const current = prev[masterId] || [];
      if (current.includes(ghostId)) {
        return { ...prev, [masterId]: current.filter(id => id !== ghostId) };
      } else {
        return { ...prev, [masterId]: [...current, ghostId] };
      }
    });
  };

  const handleApprove = async (masterId) => {
    const legacyIds = selectedGhosts[masterId];
    if (!legacyIds || legacyIds.length === 0) return;

    try {
      await api.post('/legacy/approve', { masterId, legacyIds, type: activeTab });
      setSuccess('Successfully pulled legacy GCs into Master Profile!');
      setTimeout(() => setSuccess(''), 3000);
      
      // Remove the master from the list if all suggestions were approved, or just refetch
      setMappings(prev => prev.filter(m => m.id !== masterId));
    } catch (err) {
      setError('Failed to approve mapping.');
      setTimeout(() => setError(''), 3000);
    }
  };

  return (
    <div className="p-6 max-w-5xl mx-auto">
      <div className="flex justify-between items-center mb-6">
        <div>
          <h1 className="text-2xl font-black text-slate-800 flex items-center gap-2">
            <Network className="text-indigo-600" />
            GC Claiming Tool
          </h1>
          <p className="text-sm text-slate-500 font-semibold mt-1">Anchor to your official Master Profiles and pull in historical GCs.</p>
        </div>
        
        <div className="flex gap-2 p-1 bg-slate-200 rounded-lg font-bold text-sm">
          <button 
            onClick={() => setActiveTab('consignor')}
            className={`px-4 py-2 rounded-md transition-all ${activeTab === 'consignor' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
          >
            Consignors
          </button>
          <button 
            onClick={() => setActiveTab('consignee')}
            className={`px-4 py-2 rounded-md transition-all ${activeTab === 'consignee' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
          >
            Consignees
          </button>
        </div>
      </div>

      {error && <div className="mb-4 p-3 bg-rose-100 text-rose-700 rounded-lg font-bold flex items-center gap-2"><AlertCircle size={18}/>{error}</div>}
      {success && <div className="mb-4 p-3 bg-emerald-100 text-emerald-700 rounded-lg font-bold flex items-center gap-2"><CheckCircle2 size={18}/>{success}</div>}

      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-200 bg-slate-50 flex justify-between items-center">
          <h2 className="font-bold text-slate-700">
            {mappings.length} Official Masters have unclaimed GCs
          </h2>
        </div>

        {loading ? (
          <div className="p-10 text-center text-slate-500 font-bold animate-pulse">Scanning database for unclaimed GCs...</div>
        ) : mappings.length === 0 ? (
          <div className="p-10 text-center text-slate-500 font-bold">
            <CheckCircle2 className="mx-auto mb-2 text-emerald-500 w-12 h-12" />
            All legacy GCs have been claimed by Master Profiles!
          </div>
        ) : (
          <div className="divide-y divide-slate-100 max-h-[70vh] overflow-y-auto bg-slate-50">
            {mappings.map((master) => {
              const selectedCount = (selectedGhosts[master.id] || []).length;
              
              return (
                <div key={master.id} className="p-5">
                  <div className="bg-white border-2 border-indigo-100 rounded-xl overflow-hidden shadow-sm">
                    {/* Header: Master Profile */}
                    <div className="bg-indigo-50/50 p-4 border-b border-indigo-100 flex justify-between items-start">
                      <div>
                        <div className="text-[10px] font-black uppercase text-indigo-600 tracking-wider mb-1 flex items-center gap-1">
                          <CheckCircle2 size={12}/> Official Master Profile
                        </div>
                        <div className="font-black text-slate-800 text-xl">{master.name}</div>
                        {master.legalName && master.legalName !== master.name && (
                          <div className="text-xs font-bold text-slate-500 mt-0.5">Legal: {master.legalName}</div>
                        )}
                        <div className="flex gap-3 mt-2">
                          <span className="text-xs font-bold bg-white px-2 py-0.5 rounded border border-slate-200 text-slate-600">GSTIN: {master.gstin}</span>
                          {master.city && <span className="text-xs font-bold bg-white px-2 py-0.5 rounded border border-slate-200 text-slate-600 flex items-center gap-1"><MapPin size={12}/> {master.city}</span>}
                        </div>
                      </div>
                      
                      <button 
                        onClick={() => handleApprove(master.id)}
                        disabled={selectedCount === 0}
                        className="h-10 px-5 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:hover:bg-indigo-600 text-white text-sm font-bold rounded-lg shadow-sm flex items-center gap-2 transition-all"
                      >
                        <ArrowDownToLine size={16}/>
                        Pull in {selectedCount} GC{selectedCount !== 1 ? 's' : ''}
                      </button>
                    </div>

                    {/* Body: Ghost Suggestions */}
                    <div className="p-4">
                      <div className="text-xs font-bold text-slate-500 mb-3 uppercase tracking-wider">Unclaimed Legacy GCs matching this profile:</div>
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                        {master.suggestions.map((ghost) => {
                          const isSelected = (selectedGhosts[master.id] || []).includes(ghost.id);
                          return (
                            <div 
                              key={ghost.id} 
                              onClick={() => toggleGhostSelection(master.id, ghost.id)}
                              className={`border-2 rounded-xl p-3 cursor-pointer transition-all flex items-center gap-3 ${isSelected ? 'border-emerald-400 bg-emerald-50/30' : 'border-slate-200 bg-white hover:border-slate-300'}`}
                            >
                              <div className={`w-5 h-5 rounded-md border-2 flex items-center justify-center ${isSelected ? 'bg-emerald-500 border-emerald-500' : 'border-slate-300'}`}>
                                {isSelected && <CheckCircle2 size={14} className="text-white" />}
                              </div>
                              <div>
                                <div className={`font-bold ${isSelected ? 'text-emerald-900' : 'text-slate-700'}`}>{ghost.name}</div>
                                <div className={`text-xs font-semibold mt-0.5 ${isSelected ? 'text-emerald-700' : 'text-slate-500'}`}>
                                  {ghost.gcCount} GCs attached to this spelling
                                </div>
                              </div>
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default LegacyMap;

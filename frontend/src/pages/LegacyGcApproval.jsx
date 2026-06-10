import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { CheckCircle2, AlertTriangle, ShieldCheck, Database, Search, ArrowRight } from 'lucide-react';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import toast from 'react-hot-toast';

const LegacyGcApproval = () => {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState(null);
  
  const [consignors, setConsignors] = useState([]);
  const [consignees, setConsignees] = useState([]);
  
  // State for mappings per row: { rowId: { consignorId: 1, consigneeId: 2, verified: false } }
  const [mappings, setMappings] = useState({});

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      // Fetch master data for dropdowns
      const [cnorRes, cneeRes, previewRes] = await Promise.all([
        api.get('/consignors'),
        api.get('/consignees'),
        api.get('/legacy-gc/preview')
      ]);
      
      const cnorOptions = cnorRes.map(c => ({ value: c.id, label: c.name, gstin: c.gstin }));
      const cneeOptions = cneeRes.map(c => ({ value: c.id, label: c.name, gstin: c.gstin }));
      
      setConsignors(cnorOptions);
      setConsignees(cneeOptions);
      
      // Initialize mappings
      const initialMappings = {};
      previewRes.forEach(row => {
        initialMappings[row.id] = {
          consignorId: null,
          consigneeId: null,
          verified: false
        };
      });
      setMappings(initialMappings);
      setData(previewRes);
    } catch (err) {
      setErrorMsg(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSelect = (rowId, field, value) => {
    setMappings(prev => ({
      ...prev,
      [rowId]: {
        ...prev[rowId],
        [field]: value,
        verified: false // Require re-verification if changed
      }
    }));
  };

  const stringSimilarity = (s1, s2) => {
    if (!s1 || !s2) return 0;
    const clean1 = s1.toLowerCase().replace(/[^a-z0-9]/g, '');
    const clean2 = s2.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (clean1 === clean2) return 100;
    if (clean1.includes(clean2) || clean2.includes(clean1)) return 80;
    return 0; // Simple threshold for now
  };

  const handleAutoCheck = (row) => {
    let cnorId = mappings[row.id]?.consignorId;
    let cneeId = mappings[row.id]?.consigneeId;
    
    // Auto Match Logic if not manually selected
    if (!cnorId && row.consignor) {
      const match = consignors.find(c => stringSimilarity(c.label, row.consignor) > 70);
      if (match) cnorId = match.value;
    }
    if (!cneeId && row.consignee) {
      const match = consignees.find(c => stringSimilarity(c.label, row.consignee) > 70);
      if (match) cneeId = match.value;
    }

    const cnorSelected = consignors.find(c => c.value === cnorId);
    const cneeSelected = consignees.find(c => c.value === cneeId);

    // Similarity Warning
    let warnings = [];
    if (cnorSelected && stringSimilarity(cnorSelected.label, row.consignor) === 0) {
      warnings.push("Consignor name looks completely different!");
    }
    if (cneeSelected && stringSimilarity(cneeSelected.label, row.consignee) === 0) {
      warnings.push("Consignee name looks completely different!");
    }

    if (warnings.length > 0) {
      toast.error(warnings.join(" "), { duration: 4000 });
      return;
    }

    if (!cnorId || !cneeId) {
      toast.error("Could not verify. Please map both parties.");
      setMappings(prev => ({ ...prev, [row.id]: { consignorId: cnorId, consigneeId: cneeId, verified: false } }));
      return;
    }

    toast.success("1-on-1 Check Passed! Mapping is verified.");
    setMappings(prev => ({
      ...prev,
      [row.id]: { consignorId: cnorId, consigneeId: cneeId, verified: true }
    }));
  };

  const handleApprove = async (row) => {
    const map = mappings[row.id];
    if (!map || !map.verified) return toast.error("Please Verify the mapping first!");
    
    try {
      await api.post('/legacy-gc/approve', { 
        rawData: row.rawData, 
        consignorId: map.consignorId, 
        consigneeId: map.consigneeId 
      });
      
      setData(prev => prev.map(item => item.id === row.id ? { ...item, status: 'APPROVED' } : item));
      toast.success("GC Mapped & Approved successfully!");
    } catch (err) {
      toast.error("Error approving: " + err.message);
    }
  };

  return (
    <div className="p-6 max-w-[1200px] mx-auto bg-slate-50 min-h-screen">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-black text-slate-800 flex items-center gap-3 tracking-tight">
            <Database className="text-indigo-600" size={32} />
            Legacy GC Mapping
          </h1>
          <p className="text-slate-500 font-medium mt-1">Safely map dirty legacy data to clean Master profiles.</p>
        </div>
      </div>

      {loading ? (
        <div className="text-center p-12 text-slate-500 font-bold animate-pulse text-lg">Loading Excel Data...</div>
      ) : errorMsg ? (
        <div className="bg-rose-100 border border-rose-200 text-rose-700 p-4 rounded-xl font-bold">{errorMsg}</div>
      ) : (
        <div className="space-y-6">
          {data.map(row => {
            const mapState = mappings[row.id] || {};
            const isApproved = row.status === 'APPROVED';

            if (isApproved) {
              return (
                <div key={row.id} className="bg-emerald-50 border border-emerald-200 p-6 rounded-2xl flex items-center justify-between">
                  <div>
                    <h3 className="font-black text-emerald-900 text-xl">{row.gcNo}</h3>
                    <p className="text-emerald-700 font-medium">Successfully Imported & Mapped!</p>
                  </div>
                  <CheckCircle2 size={32} className="text-emerald-500" />
                </div>
              );
            }

            return (
              <div key={row.id} className={`bg-white border-2 rounded-2xl p-6 transition-all shadow-sm ${mapState.verified ? 'border-indigo-400 shadow-indigo-100' : 'border-slate-200'}`}>
                <div className="flex justify-between items-start mb-6 pb-4 border-b border-slate-100">
                  <div>
                    <span className="bg-slate-100 text-slate-600 font-black px-3 py-1 rounded-lg text-sm tracking-wider">GC: {row.gcNo}</span>
                    <span className="text-sm font-bold text-slate-400 ml-3">{row.date}</span>
                  </div>
                  <div className="text-sm font-bold text-slate-500 bg-slate-50 px-3 py-1 rounded-lg border border-slate-100">
                    Lorry: <span className="text-slate-800">{row.lorry || 'N/A'}</span>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                  {/* CONSIGNOR MAPPING */}
                  <div className="bg-slate-50/50 p-5 rounded-xl border border-slate-100">
                    <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-2">Legacy Consignor Name</h3>
                    <div className="font-bold text-rose-800 text-lg mb-4 bg-rose-50 px-3 py-2 rounded-lg border border-rose-100 flex items-center gap-2">
                      <AlertTriangle size={16} className="text-rose-500" />
                      {row.consignor || 'NO NAME FOUND'}
                    </div>
                    
                    <div className="flex items-end gap-3">
                      <div className="flex-1">
                        <SearchableSelect 
                          label="Map to Master Consignor"
                          options={consignors}
                          value={mapState.consignorId}
                          onChange={(val) => handleSelect(row.id, 'consignorId', val)}
                          placeholder="Search clean database..."
                        />
                      </div>
                      <a href="/master/consignor" target="_blank" rel="noreferrer" className="shrink-0 h-[38px] px-3 bg-white border border-slate-200 text-slate-600 rounded-lg text-sm font-bold flex items-center hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                        + New
                      </a>
                    </div>
                  </div>

                  {/* CONSIGNEE MAPPING */}
                  <div className="bg-slate-50/50 p-5 rounded-xl border border-slate-100">
                    <h3 className="text-xs font-black text-slate-400 uppercase tracking-widest mb-2">Legacy Consignee Name</h3>
                    <div className="font-bold text-amber-800 text-lg mb-4 bg-amber-50 px-3 py-2 rounded-lg border border-amber-100 flex items-center gap-2">
                      <AlertTriangle size={16} className="text-amber-500" />
                      {row.consignee || 'NO NAME FOUND'}
                    </div>
                    
                    <div className="flex items-end gap-3">
                      <div className="flex-1">
                        <SearchableSelect 
                          label="Map to Master Consignee"
                          options={consignees}
                          value={mapState.consigneeId}
                          onChange={(val) => handleSelect(row.id, 'consigneeId', val)}
                          placeholder="Search clean database..."
                        />
                      </div>
                      <a href="/master/consignee" target="_blank" rel="noreferrer" className="shrink-0 h-[38px] px-3 bg-white border border-slate-200 text-slate-600 rounded-lg text-sm font-bold flex items-center hover:bg-slate-50 hover:text-indigo-600 transition-colors">
                        + New
                      </a>
                    </div>
                  </div>
                </div>

                <div className="mt-6 pt-6 border-t border-slate-100 flex items-center justify-between bg-slate-50 -mx-6 -mb-6 p-6 rounded-b-2xl">
                  {mapState.verified ? (
                    <div className="flex items-center gap-2 text-emerald-600 font-bold bg-emerald-50 px-4 py-2 rounded-xl border border-emerald-100">
                      <ShieldCheck size={20} /> 1-on-1 Verification Passed
                    </div>
                  ) : (
                    <button 
                      onClick={() => handleAutoCheck(row)}
                      className="px-6 py-2.5 bg-white border-2 border-slate-200 text-slate-700 font-bold rounded-xl hover:border-indigo-500 hover:text-indigo-600 transition-colors flex items-center gap-2 shadow-sm"
                    >
                      <Search size={18} /> {(!mapState.consignorId && !mapState.consigneeId) ? 'Auto-Identify' : '1-on-1 Verify Match'}
                    </button>
                  )}

                  <button 
                    onClick={() => handleApprove(row)}
                    disabled={!mapState.verified}
                    className={`px-8 py-2.5 font-black rounded-xl flex items-center gap-2 transition-all shadow-sm
                      ${mapState.verified 
                        ? 'bg-indigo-600 text-white hover:bg-indigo-700 hover:shadow-md' 
                        : 'bg-slate-200 text-slate-400 cursor-not-allowed'}`}
                  >
                    Approve GC Mapping <ArrowRight size={18} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default LegacyGcApproval;

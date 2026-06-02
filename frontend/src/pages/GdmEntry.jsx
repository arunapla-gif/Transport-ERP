import { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import { Save, Trash2, Truck, PackageCheck, FileText, Search } from 'lucide-react';

const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className={`h-9 px-3 bg-slate-50/50 border border-slate-200 text-sm font-semibold rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 focus:bg-white transition-all text-slate-800 placeholder-slate-300 shadow-sm ${props.readOnly ? 'bg-slate-100 text-slate-500 cursor-not-allowed' : 'hover:border-slate-300'}`}
      {...props}
    />
  </div>
);

// Reusable card container
const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-xl rounded-2xl border border-white/50 p-5 shadow-[0_8px_30px_rgb(0,0,0,0.04)] relative overflow-visible ${className}`}>
    <div className="absolute inset-0 bg-gradient-to-br from-white/40 to-white/0 pointer-events-none rounded-2xl" />
    <div className="relative z-10">{children}</div>
  </div>
);

export default function GdmEntry() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [vehicles, setVehicles] = useState([]);
  const [gdmNumberDisplay, setGdmNumberDisplay] = useState('');

  // Header Details
  const [gdmDetails, setGdmDetails] = useState({
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    fromLocation: 'Sivakasi',
    toName: 'AS PER BILLS',
    deliveryAt: ''
  });

  // Lorry Details
  const [lorryDetails, setLorryDetails] = useState({
    vehicleId: '',
    lorryNo: '',
    driverName: '',
    driverPhone: '',
    startKm: ''
  });

  const [activeGdmId, setActiveGdmId] = useState(null);
  const [recentGdms, setRecentGdms] = useState([]);

  // Despatch List (GCs)
  const [searchGcText, setSearchGcText] = useState('');
  const [searchCompanyMode, setSearchCompanyMode] = useState('A'); // 'A' for AP, 'B' for BELL
  const [gcs, setGcs] = useState([]);

  // Legacy Comparison Toggles
  const [consigneeMode, setConsigneeMode] = useState('Multiple Consignee');
  const [singleConsigneeSearch, setSingleConsigneeSearch] = useState('');
  const [consignees, setConsignees] = useState([]);
  
  const [freightMode, setFreightMode] = useState('Use Individual GC Freight');
  const [overallRate, setOverallRate] = useState('');
  
  const [isLorryExpanded, setIsLorryExpanded] = useState(false);

  useKeyboardFlow({ onSave: () => handleSaveGDM() });

  const fetchInitialData = async () => {
    try {
      const v = await api.get('/vehicles');
      setVehicles(v || []);

      const c = await api.get('/consignees');
      setConsignees(c || []);

      const gdms = await api.get('/gdms?_t=' + Date.now());
      setRecentGdms(gdms || []);
      
      let nextGdmNumber = 1001;
      if (gdms && gdms.length > 0) {
        const maxGdm = Math.max(...gdms.map(g => parseInt(g.gdmNumber) || 0));
        if (maxGdm >= 1001) nextGdmNumber = maxGdm + 1;
      }
      setGdmNumberDisplay(nextGdmNumber.toString());
    } catch (err) {
      console.error('Failed to fetch initial data', err);
    }
  };

  useEffect(() => {
    // eslint-disable-next-line
    fetchInitialData();
  }, []);

  const handleVehicleChange = (id) => {
    const vehicle = vehicles.find(v => v.id.toString() === id);
    setLorryDetails({
      vehicleId: id,
      lorryNo: vehicle?.vehicleNumber || '',
      driverName: vehicle?.driverName || '',
      driverPhone: vehicle?.phone || '',
      startKm: ''
    });
  };

  const handleSearchGc = async () => {
    if (!searchGcText.trim()) return;
    
    const prefix = searchCompanyMode === 'A' ? 'AP-' : 'BELL-';
    const fullGcNumber = `${prefix}${searchGcText.trim()}`;

    // Prevent adding duplicates
    if (gcs.some(gc => gc.gcNumber === fullGcNumber)) {
      setError(`GC ${fullGcNumber} is already in the list.`);
      setTimeout(() => setError(''), 3000);
      setSearchGcText('');
      return;
    }

    try {
      setLoading(true);
      setError('');
      const gc = await api.get(`/gcs/${fullGcNumber}`);
      
      if (gc.gdmId) {
        throw new Error(`GC ${gc.gcNumber} is already attached to a GDM.`);
      }
      if (gc.status === 'Cancelled') {
        throw new Error(`GC ${gc.gcNumber} is cancelled and cannot be added.`);
      }

      // Mock E-Way Bill Status Logic for UI demo
      // Calculate days since GC date
      const gcDate = new Date(gc.date || new Date());
      const today = new Date();
      const diffTime = Math.abs(today - gcDate);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      
      let ewbStatus = 'Valid';
      if (diffDays > 15) ewbStatus = 'Expired';
      else if (diffDays > 12) ewbStatus = 'Expiring';
      else if (gc.privateMark === 'NO_EWB') ewbStatus = 'Pending'; // Mock no EWB

      setGcs(prev => [...prev, { ...gc, ewbStatus, ewbAge: diffDays, includeInCewb: true }]);
      setSearchGcText('');
      setSuccess(`GC ${gc.gcNumber} added!`);
      setTimeout(() => setSuccess(''), 2000);
    } catch (err) {
      setError(err.error || err.message || 'GC Not Found');
      setTimeout(() => setError(''), 3000);
    } finally {
      setLoading(false);
    }
  };

  const removeGc = (gcId) => {
    setGcs(prev => prev.filter(gc => gc.id !== gcId));
  };

  const totals = useMemo(() => {
    let totalBundles = 0;
    let totalFreightAmount = 0;

    gcs.forEach(gc => {
      // Sum articles across goods in this GC
      const gcBundles = gc.goods ? gc.goods.reduce((sum, item) => sum + (item.articleCount || 0), 0) : 0;
      totalBundles += gcBundles;
      
      // Add freight total if in individual mode
      if (freightMode === 'Use Individual GC Freight') {
        totalFreightAmount += (gc.freightTotal || 0);
      }
    });

    if (freightMode === 'Overall Rate for GDM') {
      totalFreightAmount = parseFloat(overallRate) || 0;
    }

    return { totalBundles, totalFreightAmount };
  }, [gcs, freightMode, overallRate]);

  const handleBulkGenerateEwayBills = async () => {
    if (!lorryDetails.vehicleId) {
      setError('Please select a Lorry first. The vehicle number is required to generate the Consolidated E-Way Bill.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }
    
    const gcsForCewb = gcs.filter(gc => gc.includeInCewb !== false);
    
    // Extract E-Way bill numbers (assume stored in privateMark for now)
    const ewbNos = gcsForCewb.map(gc => gc.privateMark).filter(Boolean);
    if (ewbNos.length === 0) {
      setError('None of the selected GCs have an attached E-Way Bill Number to consolidate.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }

    setLoading(true);
    setSuccess('Initiating Smart CEWB Split Generation...');
    
    try {
      const bellEwbs = gcsForCewb.filter(gc => gc.gcNumber.startsWith('BELL')).map(gc => gc.privateMark).filter(Boolean);
      const apEwbs = gcsForCewb.filter(gc => !gc.gcNumber.startsWith('BELL')).map(gc => gc.privateMark).filter(Boolean);
      
      const basePayload = {
        vehicleNo: lorryDetails.lorryNo.replace(/[^A-Z0-9]/gi, ''), 
        fromPlace: gdmDetails.fromLocation,
        transDocNo: gdmNumberDisplay,
        transDocDate: gdmDetails.date.split('-').reverse().join('/') 
      };

      const generatedCewbs = [];
      
      // 1. Generate for BELL GCs
      if (bellEwbs.length > 0) {
        const resBell = await api.post(`/ewaybill/cewb?company=BELL`, { ...basePayload, ewbNos: bellEwbs });
        if (resBell && resBell.cEwbNo) generatedCewbs.push(`BELL: ${resBell.cEwbNo}`);
      }
      
      // 2. Generate for AP GCs
      if (apEwbs.length > 0) {
        const resAp = await api.post(`/ewaybill/cewb?company=AP`, { ...basePayload, ewbNos: apEwbs });
        if (resAp && resAp.cEwbNo) generatedCewbs.push(`AP: ${resAp.cEwbNo}`);
      }
      
      // On success, update UI to show valid
      setGcs(prev => prev.map(gc => ({
        ...gc,
        ewbStatus: 'Valid',
        ewbAge: 0
      })));
      
      setSuccess(`Successfully generated CEWBs -> ${generatedCewbs.join(' | ')}`);
      setTimeout(() => setSuccess(''), 8000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to generate CEWBs via API. One of the splits may have failed.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } finally {
      setLoading(false);
    }
  };

  const handleSaveGDM = async () => {
    if (loading) return;
    if (gcs.length === 0) {
      setError('Please add at least one GC to the Delivery Memo.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }
    if (!lorryDetails.vehicleId) {
      setError('Please select a Lorry/Vehicle.');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }

    setLoading(true);
    setError('');

    const payload = {
      gdmNumber: gdmNumberDisplay,
      date: gdmDetails.date,
      time: gdmDetails.time,
      fromLocation: gdmDetails.fromLocation,
      toName: gdmDetails.toName,
      deliveryAt: gdmDetails.deliveryAt,
      vehicleId: lorryDetails.vehicleId,
      driverName: lorryDetails.driverName,
      driverPhone: lorryDetails.driverPhone,
      startKm: lorryDetails.startKm,
      memoAmount: totals.totalFreightAmount,
      gcIds: gcs.map(gc => gc.id)
    };

    try {
      if (activeGdmId) {
        await api.put(`/gdms/${activeGdmId}`, payload);
        setSuccess(`Goods Delivery Memo ${gdmNumberDisplay} updated successfully!`);
      } else {
        await api.post('/gdms', payload);
        setSuccess(`Goods Delivery Memo ${gdmNumberDisplay} saved successfully!`);
      }
      window.scrollTo({ top: 0, behavior: 'smooth' });
      
      setTimeout(() => {
        setActiveGdmId(null);
        setGcs([]);
        setLorryDetails({ vehicleId: '', lorryNo: '', driverName: '', driverPhone: '', startKm: '' });
        setGdmDetails(prev => ({ ...prev, toName: 'AS PER BILLS', deliveryAt: '' }));
        fetchInitialData();
        setSuccess('');
      }, 2000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to save GDM');
      window.scrollTo({ top: 0, behavior: 'smooth' });
    } finally {
      setLoading(false);
    }
  };

  const loadGdmForEdit = async (gdmId) => {
    try {
      setLoading(true);
      setError('');
      window.scrollTo({ top: 0, behavior: 'smooth' });
      
      const gdm = recentGdms.find(g => g.id === gdmId);
      if (!gdm) throw new Error("GDM not found in recent list");

      setActiveGdmId(gdm.id);
      setGdmNumberDisplay(gdm.gdmNumber);
      
      setGdmDetails({
        date: gdm.date ? new Date(gdm.date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
        time: gdm.time || '',
        fromLocation: gdm.fromLocation || '',
        toName: gdm.toName || '',
        deliveryAt: gdm.deliveryAt || ''
      });

      if (gdm.vehicle) {
        setLorryDetails({
          vehicleId: gdm.vehicleId?.toString(),
          lorryNo: gdm.vehicle.vehicleNumber || '',
          driverName: gdm.driverName || '',
          driverPhone: gdm.driverPhone || '',
          startKm: gdm.startKm?.toString() || ''
        });
      }
      
      if (gdm.memoAmount > 0) {
        setFreightMode('Overall Rate for GDM');
        setOverallRate(gdm.memoAmount.toString());
      } else {
        setFreightMode('Use Individual GC Freight');
        setOverallRate('');
      }

      if (gdm.gcs && gdm.gcs.length > 0) {
        setGcs(gdm.gcs.map(gc => ({
          ...gc,
          ewbStatus: gc.status === 'Created' ? 'Pending' : 'Valid', 
          ewbAge: 0,
          includeInCewb: true
        })));
      } else {
        setGcs([]);
      }
      
      setSuccess(`Loaded GDM ${gdm.gdmNumber} for editing.`);
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.message || 'Failed to load GDM');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-4 max-w-[1300px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {error && <div className="px-5 py-3 bg-rose-50/90 backdrop-blur-sm text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">⚠️</span> {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 backdrop-blur-sm text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">✓</span> {success}</div>}

      
      {/* TOP ROW: Lorry & Memo Details */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Lorry Details (Left - 33%) */}
        <div className="col-span-1">
          <GlassCard>
            <div 
              className="flex items-center justify-between mb-4 cursor-pointer group"
              onClick={() => setIsLorryExpanded(!isLorryExpanded)}
            >
              <div className="flex items-center gap-2">
                <div className="bg-emerald-50 text-emerald-600 p-2 rounded-lg shadow-inner border border-emerald-100/50"><Truck size={18} /></div>
                <h3 className="font-bold text-lg text-slate-800 tracking-tight">Lorry Details</h3>
              </div>
              <button className="text-slate-400 group-hover:text-emerald-600 transition-colors p-1 bg-slate-50 rounded-md">
                <span className="text-xs font-bold">{isLorryExpanded ? '▲' : '▼'}</span>
              </button>
            </div>

            <div className="space-y-3">
              <SearchableSelect 
                id="vehicle-select"
                nextFocusId="gdm-gc-search"
                label="Search Lorry *"
                options={vehicles.map(v => ({ value: v.id.toString(), label: v.vehicleNumber }))}
                value={lorryDetails.vehicleId?.toString()}
                onChange={handleVehicleChange}
                placeholder=""
                className="[&>div>button]:h-9 [&>div>button]:bg-slate-50/50 [&>div>button]:border-slate-200"
              />
              
              {isLorryExpanded && (
                <div className="flex gap-2 pt-1 animate-in fade-in slide-in-from-top-2 duration-200">
                   <DenseInput label="Driver Name" value={lorryDetails.driverName} onChange={e => setLorryDetails({...lorryDetails, driverName: e.target.value})} className="w-1/2" />
                   <DenseInput label="Driver Phone" value={lorryDetails.driverPhone} onChange={e => setLorryDetails({...lorryDetails, driverPhone: e.target.value})} className="w-1/2" />
                </div>
              )}
            </div>
          </GlassCard>
        </div>

        {/* Delivery Memo (Right - 66%) */}
        <div className="lg:col-span-2">
          <GlassCard>
            <div className="flex items-center gap-2 mb-4">
              <div className="bg-indigo-50 text-indigo-600 p-2 rounded-lg shadow-inner border border-indigo-100/50"><PackageCheck size={18} /></div>
              <h3 className="font-bold text-lg text-slate-800 tracking-tight">Delivery Memo</h3>
            </div>
            
            <div className="space-y-3">
              <div className="flex gap-2">
                <DenseInput label="GDM No" value={gdmNumberDisplay} readOnly className="w-1/2 [&>input]:font-black [&>input]:text-indigo-900 [&>input]:bg-indigo-50/50" />
                <DenseInput label="Date" type="date" value={gdmDetails.date} onChange={e => setGdmDetails({...gdmDetails, date: e.target.value})} className="w-1/2" />
              </div>
              <div className="flex gap-2">
                <DenseInput label="From" value={gdmDetails.fromLocation} onChange={e => setGdmDetails({...gdmDetails, fromLocation: e.target.value})} className="w-1/3" />
                <DenseInput label="To (Name)" value={gdmDetails.toName} onChange={e => setGdmDetails({...gdmDetails, toName: e.target.value})} className="w-1/3" />
                <DenseInput label="Delivery At" value={gdmDetails.deliveryAt} onChange={e => setGdmDetails({...gdmDetails, deliveryAt: e.target.value})} className="w-1/3 [&>input]:border-amber-300 [&>input]:bg-amber-50 focus-within:[&>input]:border-amber-500" />
              </div>
              <div className="p-3 bg-slate-50/50 rounded-xl border border-slate-200 shadow-inner mt-2">
                <div className="flex flex-col gap-2">
                  <div className="flex flex-col">
                    <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Consignee Mode</label>
                    <select 
                      className="h-9 px-3 bg-white border border-slate-200 text-sm font-semibold rounded-lg focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 text-slate-700"
                      value={consigneeMode} 
                      onChange={e => {
                        const newMode = e.target.value;
                        setConsigneeMode(newMode);
                        if (newMode === 'Multiple Consignee') {
                          setGdmDetails({...gdmDetails, toName: 'AS PER BILLS', deliveryAt: ''});
                          setSingleConsigneeSearch('');
                        } else {
                          setGdmDetails({...gdmDetails, toName: '', deliveryAt: ''});
                        }
                      }}
                    >
                      <option>Multiple Consignee</option>
                      <option>Single Consignee</option>
                    </select>
                  </div>
                  {consigneeMode === 'Single Consignee' && (
                    <div className="mt-1">
                      <SearchableSelect 
                        id="consignee-select"
                        nextFocusId="gdm-gc-search"
                        label="Select Consignee"
                        options={consignees.map(c => ({ value: c.id.toString(), label: c.name }))}
                        value={singleConsigneeSearch}
                        onChange={id => {
                          setSingleConsigneeSearch(id);
                          const selected = consignees.find(c => c.id.toString() === id);
                          if (selected) {
                            setGdmDetails({...gdmDetails, toName: selected.name || '', deliveryAt: selected.city || ''});
                          }
                        }}
                        placeholder="Search consignee..."
                        className="[&>div>button]:h-9 [&>div>button]:bg-white [&>div>button]:border-slate-200"
                      />
                    </div>
                  )}
                  <p className="text-[9px] text-slate-400 font-medium leading-tight">
                    {consigneeMode === 'Multiple Consignee' 
                      ? "Each GC can have a different consignee." 
                      : "All GCs in this GDM are for one consignee."}
                  </p>
                </div>
              </div>
            </div>
          </GlassCard>
        </div>
      </div>

      {/* BOTTOM ROW: Despatch List */}
      <div className="mt-4">
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
              
              <div className="flex items-center gap-2 bg-slate-50 p-1.5 rounded-xl border border-slate-200/60 shadow-inner shrink-0 w-full sm:w-auto overflow-x-auto">
                {/* Multi-GSTIN Company Toggle */}
                <div className="flex bg-slate-100/80 p-0.5 rounded-lg border border-slate-200 shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] h-9">
                  <button 
                    type="button"
                    onClick={() => setSearchCompanyMode('A')}
                    className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${searchCompanyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
                  >
                    AP
                  </button>
                  <button 
                    type="button"
                    onClick={() => setSearchCompanyMode('B')}
                    className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${searchCompanyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
                  >
                    BELL
                  </button>
                </div>

                <div className="flex flex-col group w-48">
                  <div className="flex h-9 rounded-lg overflow-hidden border border-slate-200 bg-white focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/20 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]">
                    <span className="flex items-center justify-center px-2 bg-slate-50 text-slate-500 font-bold text-xs border-r border-slate-200">
                      {searchCompanyMode === 'A' ? 'AP' : 'BELL'}-
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
                <button 
                  onClick={handleSearchGc}
                  disabled={loading}
                  className="h-9 px-4 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold text-xs shadow-sm transition-all flex items-center gap-1.5 active:scale-95"
                >
                  <Search size={14} /> Add
                </button>
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
                <button 
                  onClick={handleBulkGenerateEwayBills}
                  disabled={loading}
                  className="h-9 px-5 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 text-white rounded-lg font-bold text-xs shadow-sm hover:shadow active:scale-95 transition-all flex items-center gap-1.5"
                >
                  Bulk Generate E-Way Bills
                </button>
              </div>
            )}

            <div className="flex-1 overflow-x-auto">
              <table className="w-full text-left border-collapse min-w-[700px]">
                <thead>
                  <tr className="bg-slate-50 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
                    <th className="p-3 pl-4 rounded-tl-lg w-10 text-center" title="Include in CEWB?">CEWB</th>
                    <th className="p-3">GC No</th>
                    <th className="p-3">EWB Status</th>
                    <th className="p-3">Consignor</th>
                    <th className="p-3">Consignee</th>
                    <th className="p-3 text-center">Bundles</th>
                    <th className="p-3 text-right">Freight</th>
                    <th className="p-3 text-center rounded-tr-lg">Action</th>
                  </tr>
                </thead>
                <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-100">
                  {gcs.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="p-12 text-center text-slate-400 font-medium">
                        <div className="flex flex-col items-center justify-center gap-2">
                          <PackageCheck size={32} className="opacity-20" />
                          <p>Scan or type a GC Number above to add it to the Despatch Memo</p>
                        </div>
                      </td>
                    </tr>
                  ) : (
                    gcs.map(gc => {
                      const bundles = gc.goods ? gc.goods.reduce((s, i) => s + (i.articleCount || 0), 0) : 0;
                      
                      // Status Badge Logic
                      let badgeClass = "bg-slate-100 text-slate-600";
                      if (gc.ewbStatus === 'Valid') badgeClass = "bg-emerald-100 text-emerald-700 border-emerald-200";
                      else if (gc.ewbStatus === 'Expired') badgeClass = "bg-rose-100 text-rose-700 border-rose-200";
                      else if (gc.ewbStatus === 'Expiring') badgeClass = "bg-amber-100 text-amber-700 border-amber-200";
                      else if (gc.ewbStatus === 'Pending') badgeClass = "bg-blue-100 text-blue-700 border-blue-200";

                      return (
                        <tr key={gc.id} className="hover:bg-indigo-50/30 transition-colors group">
                          <td className="p-3 pl-4 text-center">
                            <input 
                              type="checkbox" 
                              className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500 cursor-pointer shadow-sm"
                              checked={gc.includeInCewb !== false}
                              onChange={(e) => {
                                setGcs(prev => prev.map(g => g.id === gc.id ? { ...g, includeInCewb: e.target.checked } : g));
                              }}
                              title="Include in Consolidated E-Way Bill"
                            />
                          </td>
                          <td className="p-3 text-indigo-700 font-bold">{gc.gcNumber}</td>
                          <td className="p-3">
                            <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider border ${badgeClass}`}>
                              {gc.ewbStatus || 'Unknown'} {gc.ewbAge > 0 ? `(${gc.ewbAge}d)` : ''}
                            </span>
                          </td>
                          <td className="p-3 truncate max-w-[150px]">{gc.consignor?.name || 'N/A'}</td>
                          <td className="p-3 truncate max-w-[150px]">{gc.consignee?.name || 'N/A'}</td>
                          <td className="p-3 text-center text-slate-900 font-black">{bundles}</td>
                          <td className="p-3 text-right tabular-nums">₹{gc.freightTotal?.toFixed(2) || '0.00'}</td>
                          <td className="p-3 text-center">
                            <div className="flex items-center justify-center gap-1">
                              {(gc.ewbStatus === 'Expired' || gc.ewbStatus === 'Expiring') && (
                                <button 
                                  title="Extend / Update Part-B"
                                  className="text-amber-500 hover:text-amber-700 hover:bg-amber-50 p-1.5 rounded-lg transition-all"
                                >
                                  <Truck size={16} />
                                </button>
                              )}
                              <button onClick={() => removeGc(gc.id)} className="text-slate-300 hover:text-rose-500 hover:bg-rose-50 p-1.5 rounded-lg transition-all">
                                <Trash2 size={16} />
                              </button>
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
              
              <div className="flex gap-6">
                <div className="flex flex-col">
                  <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Total Bundles</span>
                  <span className="text-2xl font-black text-indigo-900">{totals.totalBundles}</span>
                </div>
                <div className="flex flex-col">
                  <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Total Freight</span>
                  <span className="text-2xl font-black text-emerald-600">₹{totals.totalFreightAmount.toFixed(2)}</span>
                </div>
              </div>
              <div className="flex flex-wrap items-center gap-4 w-full sm:w-auto mt-4 sm:mt-0 justify-between sm:justify-end">
                
                <div className="flex gap-2">
                <button 
                  onClick={() => {
                    setSuccess("Simulating Consolidated E-Way Bill Generation...");
                    setTimeout(() => setSuccess("Consolidated E-Way Bill Generated: CEWB-9988776655"), 2000);
                  }}
                  disabled={loading || gcs.length === 0} 
                  className="h-11 px-5 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-400 hover:to-amber-500 disabled:from-slate-300 disabled:to-slate-300 text-white rounded-xl font-bold text-sm shadow-sm transition-all flex items-center gap-2"
                >
                  <PackageCheck size={16} /> Generate CEWB
                </button>
                <button 
                  onClick={handleSaveGDM} 
                  disabled={loading || gcs.length === 0} 
                  className="h-11 px-8 bg-indigo-600 hover:bg-indigo-500 disabled:bg-slate-300 disabled:cursor-not-allowed text-white rounded-xl font-bold text-sm shadow-md hover:shadow-lg transition-all active:scale-95 flex items-center gap-2"
                >
                  <Save size={16} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Saving...' : 'Submit Delivery Memo'}
                </button>
              </div>
            </div>
            </div>
          </GlassCard>
      </div>

      {/* RECENT DRAFTS TABLE */}
      {recentGdms.length > 0 && (
        <div className="mt-8 animate-in fade-in slide-in-from-bottom-4">
          <GlassCard className="!p-0 overflow-hidden border-indigo-100">
            <div className="bg-gradient-to-r from-indigo-50 to-white px-5 py-4 border-b border-indigo-100/50 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="bg-indigo-100 text-indigo-700 p-1.5 rounded-lg"><FileText size={16} /></div>
                <h3 className="font-bold text-slate-800 tracking-tight">Recent Draft GDMs</h3>
              </div>
              <span className="text-[10px] font-bold text-indigo-500 uppercase tracking-wider px-2 py-1 bg-indigo-50 rounded-md">
                Click Edit to Modify
              </span>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse min-w-[800px]">
                <thead>
                  <tr className="bg-slate-50 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-100">
                    <th className="p-3 pl-5">GDM No</th>
                    <th className="p-3">Date</th>
                    <th className="p-3">Vehicle</th>
                    <th className="p-3">Route</th>
                    <th className="p-3 text-center">GCs</th>
                    <th className="p-3">Status</th>
                    <th className="p-3 text-right pr-5">Action</th>
                  </tr>
                </thead>
                <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-50">
                  {recentGdms.map(gdm => (
                    <tr key={gdm.id} className="hover:bg-indigo-50/20 transition-colors">
                      <td className="p-3 pl-5 font-black text-indigo-700">{gdm.gdmNumber}</td>
                      <td className="p-3 text-slate-600">{gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : '-'}</td>
                      <td className="p-3 font-bold text-slate-800">{gdm.vehicle?.vehicleNumber || '-'}</td>
                      <td className="p-3 text-slate-600 text-xs">{gdm.fromLocation} → {gdm.toName === 'AS PER BILLS' ? 'Multiple' : gdm.toName}</td>
                      <td className="p-3 text-center tabular-nums font-bold">{gdm.gcs?.length || 0}</td>
                      <td className="p-3">
                        <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider border ${gdm.status === 'Created' ? 'bg-amber-100 text-amber-700 border-amber-200' : 'bg-emerald-100 text-emerald-700 border-emerald-200'}`}>
                          {gdm.status === 'Created' ? 'Draft' : gdm.status}
                        </span>
                      </td>
                      <td className="p-3 text-right pr-5">
                        <button 
                          onClick={() => loadGdmForEdit(gdm.id)}
                          className="px-3 py-1 bg-white border border-indigo-200 text-indigo-600 hover:bg-indigo-50 rounded-md font-bold text-xs shadow-[0_1px_2px_rgba(0,0,0,0.05)] transition-all active:scale-95"
                        >
                          Edit
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </GlassCard>
        </div>
      )}

    </div>
  );
}
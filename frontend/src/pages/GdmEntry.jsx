import { useState, useEffect, useMemo, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { DenseInput, GlassCard } from '../components/ui/DensePrimitives';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import { AsyncSearchableSelect } from '../components/ui/AsyncSearchableSelect';
import { Button } from '../components/ui/Button';
import { Save, Trash2, Truck, PackageCheck, FileText, Search, ShieldAlert, ChevronDown, ChevronUp, Loader2, RefreshCw, Clock, X, Printer, Edit2, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';
import { LorryDetailsCard } from '../components/entry/LorryDetailsCard';
import { GdmDocumentDetails } from '../components/entry/GdmDocumentDetails';
import { DespatchListTable } from '../components/entry/DespatchListTable';



export default function GdmEntry() {
  const location = useLocation();
  const query = new URLSearchParams(location.search);
  const branch = query.get('branch') || 'MAIN';

  const [loading, setLoading] = useState(false);
  const [isBulkGenerating, setIsBulkGenerating] = useState(false);
  const [isCewbGenerating, setIsCewbGenerating] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [vehicles, setVehicles] = useState([]);
  const [gdmNumberDisplay, setGdmNumberDisplay] = useState('');

  // DRAFT PERSISTENCE LOGIC
  const loadDraft = (key, defaultVal) => {
    try {
      const draftStr = localStorage.getItem('gdmDraft');
      if (draftStr) {
        const draft = JSON.parse(draftStr);
        if (draft[key] !== undefined) return draft[key];
      }
    } catch(e) {}
    return defaultVal;
  };

  // Header Details
  const [gdmDetails, setGdmDetails] = useState(() => loadDraft('gdmDetails', {
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    fromLocation: 'Sivakasi',
    toName: 'AS PER BILLS',
    deliveryAt: '',
    cewbNumber: ''
  }));

  // Lorry Details
  const [lorryDetails, setLorryDetails] = useState(() => loadDraft('lorryDetails', {
    vehicleId: '',
    lorryNo: '',
    driverName: '',
    driverPhone: '',
    startKm: ''
  }));

  const [activeGdmId, setActiveGdmId] = useState(null);
  const [recentGdms, setRecentGdms] = useState([]);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [isDispatchDrawerOpen, setIsDispatchDrawerOpen] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalRecords, setTotalRecords] = useState(0);

  // DL Verification
  const [dlData, setDlData] = useState(null);
  const [fetchingDl, setFetchingDl] = useState(false);
  const [dlDetails, setDlDetails] = useState({ license: '', dob: '' });

  // Despatch List (GCs)
  const [searchGcText, setSearchGcText] = useState('');
  const [gdmCompanyMode, setGdmCompanyMode] = useState(() => loadDraft('gdmCompanyMode', 'A')); 
  const [gcs, setGcs] = useState(() => loadDraft('gcs', []));
  const [allUnitOptions, setAllUnitOptions] = useState([]);

  // Legacy Comparison Toggles
  const [consigneeMode, setConsigneeMode] = useState(() => loadDraft('consigneeMode', 'Multiple Consignee'));
  const [selectedConsigneeData, setSelectedConsigneeData] = useState(null);
  
  const [freightMode, setFreightMode] = useState(() => loadDraft('freightMode', 'Use Individual GC Freight'));
  const [overallRate, setOverallRate] = useState(() => loadDraft('overallRate', ''));
  
  const [isLorryExpanded, setIsLorryExpanded] = useState(false);




  // Auto-Save Draft
  useEffect(() => {
    if (!activeGdmId) {
      const draft = {
        gdmDetails,
        lorryDetails,
        gdmCompanyMode,
        gcs,
        consigneeMode,
        freightMode,
        overallRate
      };
      localStorage.setItem('gdmDraft', JSON.stringify(draft));
    }
  }, [gdmDetails, lorryDetails, gdmCompanyMode, gcs, consigneeMode, freightMode, overallRate, activeGdmId]);

  const vehicleOptions = useMemo(() => vehicles.map(v => ({ value: v.id.toString(), label: v.vehicleNumber })), [vehicles]);
  const fetchConsigneesAsync = useCallback(async (q) => {
    try {
      const res = await api.get(`/consignees/search?branch=${branch}&q=${encodeURIComponent(q)}`);
      return res.map(c => ({ value: c.id.toString(), label: c.name, raw: c }));
    } catch (err) {
      return [];
    }
  }, [branch]);

  const handleConsigneeChange = useCallback((id, opt) => {
    if (opt && opt.raw) {
      setSelectedConsigneeData(opt.raw);
      setGdmDetails(prev => ({...prev, toName: opt.raw.name || '', deliveryAt: opt.raw.city || ''}));
    } else {
      setSelectedConsigneeData(null);
    }
  }, []);

  const handleVehicleChange = useCallback((id) => {
    const selected = vehicles.find(v => v.id.toString() === id);
    if (selected) {
      setLorryDetails(prev => ({
        ...prev,
        vehicleId: selected.id,
        lorryNo: selected.vehicleNumber,
        driverName: selected.driverName || '',
        driverPhone: selected.phone || ''
      }));
    } else {
      setLorryDetails(prev => ({ ...prev, vehicleId: '', lorryNo: '', driverName: '', driverPhone: '' }));
    }
  }, [vehicles]);

  useKeyboardFlow({ onSave: () => handleSaveGDM() });

  const fetchInitialData = async () => {
    try {
      const [v, unitsRes] = await Promise.all([
        api.get('/vehicles'),
        api.get('/units').catch(() => [])
      ]);
      setVehicles(v || []);
      if (unitsRes && unitsRes.length > 0) {
        setAllUnitOptions(unitsRes.map(u => ({ label: u.description, code: u.code, category: u.category })));
      }
    } catch (err) {
      console.error('Failed to fetch initial data', err);
    }
  };

  // Dynamically update next GDM number when Company Mode changes
  useEffect(() => {
    if (!activeGdmId) {
      const fetchNextNum = async () => {
        try {
          const nextNumRes = await api.get(`/gdms/next-number?branch=${branch}&mode=${gdmCompanyMode}`);
          const prefix = gdmCompanyMode === 'A' ? 'AP-' : 'BELL-';
          setGdmNumberDisplay(prefix + (nextNumRes.nextNumber?.toString() || '1001'));
        } catch (err) {
          console.error("Failed to fetch next GDM number", err);
        }
      };
      fetchNextNum();
    }
  }, [gdmCompanyMode, branch, activeGdmId]);

  const fetchRecentGdms = async (pageNum = 1, append = false) => {
    try {
      const res = await api.get(`/gdms?branch=${branch}&page=${pageNum}&limit=10`);
      if (append) {
        setRecentGdms(prev => {
          const existingIds = new Set(prev.map(r => r.id));
          const uniqueNew = (res.data || []).filter(r => !existingIds.has(r.id));
          return [...prev, ...uniqueNew];
        });
      } else {
        setRecentGdms(res.data || []);
      }
      setTotalPages(res.totalPages || 1);
      setTotalRecords(res.total || 0);
    } catch (err) {
      console.error('Failed to fetch recent GDMs', err);
    }
  };

  useEffect(() => {
    // eslint-disable-next-line
    fetchInitialData();
    fetchRecentGdms(1, false);
  }, []);

  useEffect(() => {
    if (page > 1) {
      fetchRecentGdms(page, true);
    }
  }, [page, branch]);

  const handleFetchDL = async (e) => {
    e.preventDefault();
    if (!dlDetails.license || !dlDetails.dob) {
      toast.error('License Number and DOB are required for verification');
      return;
    }
    
    setFetchingDl(true);
    try {
      const sanitizedDL = dlDetails.license.replace(/[\s-]/g, '');
      const response = await api.post('/fastag/dl', { dlNumber: sanitizedDL, dob: dlDetails.dob });
      const data = response.data;
      setDlData(data);
      
      // Auto-fill Driver Name ONLY if it is not masked with asterisks
      if (!lorryDetails.driverName && data.owner_name && !data.owner_name.includes('*')) {
        setLorryDetails(prev => ({ ...prev, driverName: data.owner_name }));
      }
      
      const validClasses = ['TRANS', 'HTV', 'HMV', 'HGMV', 'MGV', 'MGMV'];
      const hasValidClass = data.vehicle_classes?.some(c => validClasses.includes(c?.toUpperCase()));
      
      let isExpired = false;
      if (data.validity_tr && data.validity_tr !== '-' && data.validity_tr !== 'NA') {
        const parts = data.validity_tr.split('-');
        if (parts.length === 3) {
          const [day, month, year] = parts;
          const expiryDate = new Date(`${year}-${month}-${day}`);
          if (expiryDate < new Date()) isExpired = true;
        } else {
           isExpired = true;
        }
      } else {
        isExpired = true;
      }

      if (!hasValidClass) {
        toast.error('Warning: Driver does NOT have a Heavy/Transport License class!', { duration: 5000, icon: '⚠️' });
      } else if (isExpired) {
        toast.error('Warning: Driver Transport License Validity has expired!', { duration: 5000, icon: '⚠️' });
      } else {
        toast.success('DL verified successfully and is eligible for Transport.');
      }
    } catch (err) {
      toast.error('Failed to verify Driving License: ' + (err.response?.data?.error || err.error || err.message || 'Unknown error'));
    } finally {
      setFetchingDl(false);
    }
  };


  const handleSearchGc = async () => {
    if (!searchGcText.trim()) return;
    
    let text = searchGcText.trim().toUpperCase();
    const prefix = gdmCompanyMode === 'A' ? 'AP-' : 'BELL-';
    
    // Strip prefix if already present (e.g., from a barcode scan)
    if (text.startsWith('AP-') || text.startsWith('BELL-')) {
      text = text.replace(/^(AP-|BELL-)/, '');
    }
    
    const fullGcNumber = `${prefix}${text}`;

    // Clear input IMMEDIATELY for rapid barcode scanning (prevent appending next scan)
    setSearchGcText('');

    // Prevent adding duplicates
    if (gcs.some(gc => gc.gcNumber === fullGcNumber)) {
      setError(`GC ${fullGcNumber} is already in the list.`);
      setTimeout(() => setError(''), 3000);
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

      // Enforce Single Consignee mode
      if (consigneeMode === 'Single Consignee') {
        if (!selectedConsigneeData) {
          throw new Error('Please select a Consignee first in Single Consignee mode.');
        }
        
        const selectedId = selectedConsigneeData.id;
        const gcId = gc.consigneeId;
        
        if (gcId !== selectedId) {
          const selectedParentId = selectedConsigneeData.parentId;
          const gcParentId = gc.consignee?.parentId;

          let isMatch = false;
          if (gcParentId && selectedParentId && gcParentId === selectedParentId) isMatch = true; // Sibling
          if (gcId === selectedParentId) isMatch = true; // GC is Parent
          if (selectedId === gcParentId) isMatch = true; // Selected is Parent
          
          if (!isMatch) {
            throw new Error(`Consignee mismatch! This GC belongs to ${gc.consignee?.name || 'another consignee'} (Not in the same Parent Group).`);
          }
        }
      }

      // Mock E-Way Bill Status Logic for UI demo
      let ewbStatus = 'Valid';
      let diffDays = 0;
      
      if (!gc.ewbNumber && gc.privateMark === 'NO_EWB') {
        ewbStatus = 'Pending';
      } else if (gc.ewbNumber || gc.privateMark) {
        const gcDate = new Date(gc.date || new Date());
        const today = new Date();
        const diffTime = Math.abs(today - gcDate);
        diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        
        if (diffDays > 15) ewbStatus = 'Expired';
        else if (diffDays > 12) ewbStatus = 'Expiring';
      } else {
        ewbStatus = 'Pending';
      }

      setGcs(prev => [...prev, { ...gc, ewbStatus, ewbAge: diffDays, includeInCewb: true }]);
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
    let cases = 0, cartons = 0, bundles = 0, others = 0, total = 0;
    let totalFreightAmount = 0;

    gcs.forEach(gc => {
      if (gc.goods) {
        gc.goods.forEach(item => {
          const qty = parseInt(item.articleCount) || 0;
          total += qty;
          const unitStr = (item.units || '').toLowerCase().trim();
          const match = allUnitOptions.find(o => 
            (o.label || '').toLowerCase().trim() === unitStr || 
            (o.code || '').toLowerCase().trim() === unitStr ||
            (o.category || '').toLowerCase().trim() === unitStr
          );
          const cat = match ? (match.category || '').toLowerCase() : null;
          if (cat === 'cases') cases += qty;
          else if (cat === 'cartons') cartons += qty;
          else if (cat === 'bundles') bundles += qty;
          else others += qty;
        });
      }
      
      // Add freight total if in individual mode
      if (freightMode === 'Use Individual GC Freight') {
        totalFreightAmount += (gc.freightTotal || 0);
      }
    });

    if (freightMode === 'Overall Rate for GDM') {
      totalFreightAmount = parseFloat(overallRate) || 0;
    }

    return { cases, cartons, bundles, others, total, totalFreightAmount };
  }, [gcs, freightMode, overallRate, allUnitOptions]);



  const handleSaveGDM = async (submitStatus = 'Created') => {
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
      cewbNumber: gdmDetails.cewbNumber,
      gcIds: gcs.map(gc => gc.id),
      dlData: dlData ? {
        licenseNumber: dlDetails.license.replace(/[\s-]/g, '').toUpperCase(),
        dob: dlDetails.dob,
        name: dlData.owner_name,
        phone: lorryDetails.driverPhone,
        rto: dlData.rto,
        status: dlData.status,
        validityNt: dlData.validity_nt,
        validityTr: dlData.validity_tr,
        vehicleClasses: dlData.vehicle_classes,
      } : null,
      status: submitStatus
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
        setGdmDetails(prev => ({ ...prev, toName: 'AS PER BILLS', deliveryAt: '', cewbNumber: '' }));
        setDlDetails({ license: '', dob: '' });
        setDlData(null);
        localStorage.removeItem('gdmDraft');
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
        deliveryAt: gdm.deliveryAt || '',
        cewbNumber: gdm.cewbNumber || ''
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
        // Infer company mode from the first GC
        const isBell = gdm.gcs[0].gcNumber?.startsWith('BELL-');
        setGdmCompanyMode(isBell ? 'B' : 'A');
        
        setGcs(gdm.gcs.map(gc => {
          // Calculate ewbStatus same as handleSearchGc
          let computedStatus = 'Valid';
          let diffDays = 0;
          
          if (!gc.ewbNumber && gc.privateMark === 'NO_EWB') {
            computedStatus = 'Pending';
          } else if (gc.ewbNumber || gc.privateMark) {
            const gcDate = new Date(gc.date || new Date());
            const today = new Date();
            const diffTime = Math.abs(today - gcDate);
            diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
            
            if (diffDays > 15) computedStatus = 'Expired';
            else if (diffDays > 12) computedStatus = 'Expiring';
          } else {
            computedStatus = 'Pending';
          }

          return {
            ...gc,
            ewbStatus: computedStatus,
            ewbAge: diffDays
          };
        }));
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
    <div className="flex flex-col flex-1 w-full h-full overflow-hidden bg-slate-100/50" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER RIBBON */}
      <div className="bg-white border-b border-slate-200 p-3 flex justify-between items-center shrink-0 z-20 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800 text-lg">New GDM</span>
            
            {/* Strict GDM Company Toggle */}
            <div className="flex bg-slate-100 p-0.5 rounded-lg border border-slate-200 h-8 ml-2">
              <button 
                type="button"
                onClick={() => {
                  if (gcs.length > 0) {
                    setError('Cannot switch company mode while GCs are loaded. Clear the list first.');
                    setTimeout(() => setError(''), 3000);
                    return;
                  }
                  setGdmCompanyMode('A');
                }}
                className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gdmCompanyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
              >
                AP
              </button>
              <button 
                type="button"
                onClick={() => {
                  if (gcs.length > 0) {
                    setError('Cannot switch company mode while GCs are loaded. Clear the list first.');
                    setTimeout(() => setError(''), 3000);
                    return;
                  }
                  setGdmCompanyMode('B');
                }}
                className={`px-3 flex items-center justify-center text-xs font-black rounded-md transition-all ${gdmCompanyMode === 'B' ? 'bg-indigo-600 text-white shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}
              >
                BELL
              </button>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {error && <div className="text-rose-600 font-bold text-sm flex items-center gap-1 animate-pulse"><AlertCircle size={14}/> {error}</div>}
          {success && <div className="text-emerald-600 font-bold text-sm flex items-center gap-1">✓ {success}</div>}
          
          <Button variant="secondary" onClick={() => setIsHistoryOpen(true)} className="flex items-center gap-2 h-9 px-3 py-0 text-xs shadow-sm">
            <Clock size={14} /> Recent GDMs
          </Button>
        </div>
      </div>

      {/* MAIN SCROLLABLE CONTENT */}
      <div className="flex-1 overflow-y-auto p-4 md:p-6 custom-scrollbar">
        <div className="max-w-[1300px] mx-auto space-y-4 pb-10">
      
          {/* TOP ROW: Lorry & Memo Details */}
          <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">
        {/* Lorry Details (Left - 33%) */}
        <div className="col-span-1">
          <LorryDetailsCard 
              gdmDetails={gdmDetails}
              lorryDetails={lorryDetails}
              setLorryDetails={setLorryDetails}
              vehicleOptions={vehicleOptions}
              handleVehicleChange={handleVehicleChange}
              dlDetails={dlDetails}
              setDlDetails={setDlDetails}
              fetchingDl={fetchingDl}
              handleFetchDL={handleFetchDL}
              dlData={dlData}
            />
        </div>

        {/* Delivery Memo (Right - 66%) */}
        <div className="lg:col-span-2 relative z-20">
          <GdmDocumentDetails 
              gdmNumberDisplay={gdmNumberDisplay}
              gdmDetails={gdmDetails}
              setGdmDetails={setGdmDetails}
              consigneeMode={consigneeMode}
              setConsigneeMode={setConsigneeMode}
              selectedConsigneeData={selectedConsigneeData}
              setSelectedConsigneeData={setSelectedConsigneeData}
              fetchConsigneesAsync={fetchConsigneesAsync}
              handleConsigneeChange={handleConsigneeChange}
            />
        </div>
      </div>

      {/* BOTTOM ROW: Despatch List */}
      <div className="mt-4">
        <DespatchListTable 
            gcs={gcs}
            gdmCompanyMode={gdmCompanyMode}
            freightMode={freightMode}
            setFreightMode={setFreightMode}
            overallRate={overallRate}
            setOverallRate={setOverallRate}
            searchGcText={searchGcText}
            setSearchGcText={setSearchGcText}
            handleSearchGc={handleSearchGc}
            removeGc={removeGc}
            totals={totals}
            allUnitOptions={allUnitOptions}
            loading={loading}
            success={success}
            error={error}
            handleSaveGDM={handleSaveGDM}
            setIsDispatchDrawerOpen={setIsDispatchDrawerOpen}
            page={page}
            totalPages={totalPages}
            setPage={setPage}
          />
      </div>

      {/* HISTORY DRAWER */}
      <div className={`fixed inset-y-0 right-0 w-80 bg-white shadow-2xl border-l border-slate-200 transform transition-transform duration-300 z-50 flex flex-col ${isHistoryOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="p-4 border-b border-slate-200 flex justify-between items-center bg-slate-50/50">
           <h2 className="font-bold flex items-center gap-2 text-slate-800"><Clock size={18} className="text-indigo-500" /> Recent History</h2>
           <button onClick={() => setIsHistoryOpen(false)} className="p-1 hover:bg-slate-200 rounded-md text-slate-500"><X size={16} /></button>
        </div>
        <div className="p-4 space-y-3 overflow-y-auto flex-1 custom-scrollbar">
           {recentGdms.map(gdm => (
             <div key={gdm.id} className="p-3 bg-white border border-slate-200 rounded-xl shadow-sm hover:border-indigo-300 transition-colors">
               <div className="flex justify-between items-start mb-2">
                 <span className="font-black text-indigo-700 text-sm">{gdm.gdmNumber}</span>
                 <span className="text-[10px] font-bold text-slate-400">{gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : '-'}</span>
               </div>
               <div className="text-xs font-semibold text-slate-600 mb-2 truncate" title={`${gdm.fromLocation} → ${gdm.toName}`}>
                 {gdm.fromLocation} &rarr; {gdm.toName === 'AS PER BILLS' ? 'Multiple' : gdm.toName}
               </div>
               <div className="flex justify-between items-center">
                 <span className={`px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider border ${gdm.status === 'Created' ? 'bg-amber-100 text-amber-700 border-amber-200' : 'bg-emerald-100 text-emerald-700 border-emerald-200'}`}>
                   {gdm.status === 'Created' ? 'Draft' : gdm.status}
                 </span>
                 <div className="flex justify-end gap-2">
                   {/* <button onClick={() => { setIsHistoryOpen(false); window.open(`/print/gdm/${gdm.id}`, '_blank'); }} className="px-2.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-600 rounded-md text-[11px] font-bold transition-colors flex items-center gap-1 shadow-sm"><Printer size={12}/> Print</button> */}
                   <Button variant="secondary" onClick={() => { setIsHistoryOpen(false); loadGdmForEdit(gdm.id); }} className="h-7 px-2.5 py-0 text-[11px] flex items-center gap-1 shadow-sm border-indigo-200 text-indigo-700 bg-indigo-50 hover:bg-indigo-100"><Edit2 size={12}/> Edit</Button>
                 </div>
               </div>
             </div>
           ))}
           {recentGdms.length === 0 && <p className="text-sm text-slate-400 text-center mt-10 font-medium">No recent GDMs found.</p>}
        </div>
      </div>

      {/* OVERLAY */}
      {(isHistoryOpen || isDispatchDrawerOpen) && <div className="fixed inset-0 bg-slate-900/30 z-40 transition-opacity" onClick={() => { setIsHistoryOpen(false); setIsDispatchDrawerOpen(false); }} />}

      {/* DISPATCH DRAWER */}
      <div className={`fixed inset-y-0 right-0 w-full sm:w-[450px] bg-white shadow-2xl border-l border-slate-200 transform transition-transform duration-300 z-50 flex flex-col ${isDispatchDrawerOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="p-6 border-b border-slate-200 flex justify-between items-center bg-slate-50/80">
           <div>
             <h2 className="text-2xl font-black flex items-center gap-2 text-slate-800">Dispatch Operations</h2>
             <p className="text-xs font-bold text-slate-500 mt-1">Complete the checklist to finalize dispatch.</p>
           </div>
           <button onClick={() => setIsDispatchDrawerOpen(false)} className="p-2 hover:bg-slate-200 rounded-xl text-slate-500 transition-colors"><X size={20} /></button>
        </div>
        
        <div className="p-6 space-y-6 overflow-y-auto flex-1 custom-scrollbar">
           
           {/* Step 1: Execution */}
           <div className="flex flex-col gap-4 p-5 bg-white rounded-2xl shadow-sm border border-slate-200">
             <div className="flex items-center gap-3 text-slate-700 font-black text-lg border-b border-slate-100 pb-3">
               <Truck size={20} className="text-indigo-600" />
               <h3>Step 1: Final Dispatch</h3>
             </div>
             <p className="text-xs font-semibold text-slate-500">Save your progress as a draft, or submit the final GDM to complete dispatch.</p>
             <div className="flex flex-col gap-3 mt-2">
               <Button 
                 variant="primary"
                 onClick={() => { setIsDispatchDrawerOpen(false); handleSaveGDM('Submitted'); }} 
                 disabled={loading || gcs.length === 0} 
                 className="w-full h-12 rounded-xl text-sm shadow-md flex items-center justify-center gap-2"
               >
                 <Truck size={16} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Saving...' : 'Submit Final GDM'}
               </Button>
               <Button 
                 variant="secondary"
                 onClick={() => { setIsDispatchDrawerOpen(false); handleSaveGDM('Created'); }} 
                 disabled={loading || gcs.length === 0} 
                 className="w-full h-10 rounded-xl text-xs shadow-sm flex items-center justify-center gap-2"
               >
                 <Save size={14} className={loading ? 'animate-pulse' : ''} /> Save as Draft
               </Button>
             </div>
           </div>

        </div>
      </div>



        </div>
      </div>

    </div>
  );
}
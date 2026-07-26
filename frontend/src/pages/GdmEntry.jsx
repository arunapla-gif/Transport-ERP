import { useState, useEffect, useMemo, useCallback } from 'react';
import { useLocation } from 'react-router-dom';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { DenseInput, SearchableSelect, GlassCard } from '../components/ui/DensePrimitives';
import { AsyncSearchableSelect } from '../components/ui/AsyncSearchableSelect';
import { Button } from '../components/ui/Button';
import { Save, Trash2, Truck, PackageCheck, FileText, Search, ShieldAlert, ChevronDown, ChevronUp, Loader2, RefreshCw, Clock, X, Printer, Edit2, AlertCircle } from 'lucide-react';
import toast from 'react-hot-toast';

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
    <div className={`relative z-10 ${className.includes('h-full') ? 'h-full flex flex-col' : ''}`}>{children}</div>
  </div>
);

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
          <GlassCard className="h-full flex flex-col">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <div className="bg-emerald-50 text-emerald-600 p-2 rounded-lg shadow-inner border border-emerald-100/50"><Truck size={18} /></div>
                <h3 className="font-bold text-lg text-slate-800 tracking-tight">Lorry Details</h3>
              </div>
              
              <div className="flex items-center gap-2">
                {gdmDetails.cewbNumber && (
                  <div className="px-2.5 py-1 bg-amber-100 text-amber-800 text-[11px] font-black tracking-wider uppercase rounded-md border border-amber-300 shadow-sm">
                    CEWB: {gdmDetails.cewbNumber}
                  </div>
                )}
              </div>
            </div>

            <div className="flex-1 flex flex-col gap-4 justify-between">
              <SearchableSelect 
                id="vehicle-select"
                nextFocusId="gdm-gc-search"
                label="Search Lorry *"
                options={vehicleOptions}
                value={lorryDetails.vehicleId?.toString()}
                onChange={handleVehicleChange}
                placeholder=""
                className="[&>div>button]:h-10 [&>div>button]:bg-slate-50/50 [&>div>button]:border-slate-200"
              />
              
                <div className="space-y-4 pt-1 mt-1 flex-1 flex flex-col justify-between">
                   <div className="flex flex-col gap-3 p-4 bg-slate-50/50 rounded-xl border border-slate-200 shadow-inner">
                     <div className="flex items-center gap-2 mb-1">
                       <ShieldAlert size={16} className="text-blue-500" />
                       <span className="text-[11px] font-bold uppercase tracking-wider text-slate-500">License Verification</span>
                     </div>
                     <div className="flex items-end gap-3">
                       <DenseInput label="DL No." value={dlDetails.license} onChange={e => setDlDetails({...dlDetails, license: e.target.value.toUpperCase()})} className="flex-1 [&>input]:uppercase [&>input]:h-10" />
                       <DenseInput label="DOB" type="date" value={dlDetails.dob} onChange={e => setDlDetails({...dlDetails, dob: e.target.value})} className="w-[120px] [&>input]:h-10" />
                     </div>
                     <Button 
                       variant="primary"
                       type="button"
                       onClick={handleFetchDL} 
                       disabled={fetchingDl || !dlDetails.license || !dlDetails.dob}
                       className="h-10 mt-1 px-4 text-sm w-full shadow-sm hover:shadow"
                     >
                       {fetchingDl ? 'Verifying...' : 'Verify & Check Eligibility'}
                     </Button>
                     
                     {/* DL Verified Badge */}
                     {dlData && (
                       <div className="mt-2 flex flex-col gap-1.5 p-2 bg-blue-50 border border-blue-100 rounded-md">
                         <div className="flex items-center justify-between">
                           <span className={`text-[10px] font-black tracking-wider uppercase px-2 py-0.5 rounded-sm ${dlData.status === 'ACTIVE' ? 'bg-emerald-100 text-emerald-700' : 'bg-rose-100 text-rose-700'}`}>
                             {dlData.status}
                           </span>
                           {/* Eligibility */}
                           {(() => {
                              const validClasses = ['TRANS', 'HTV', 'HMV', 'HGMV', 'MGV', 'MGMV'];
                              const hasValidClass = dlData.vehicle_classes?.some(c => validClasses.includes(c?.toUpperCase()));
                              let isExpired = false;
                              if (dlData.validity_tr && dlData.validity_tr !== '-' && dlData.validity_tr !== 'NA') {
                                const parts = dlData.validity_tr.split('-');
                                if (parts.length === 3) {
                                  const [day, month, year] = parts;
                                  const expiryDate = new Date(`${year}-${month}-${day}`);
                                  if (expiryDate < new Date()) isExpired = true;
                                } else isExpired = true;
                              } else isExpired = true;
 
                              if (!hasValidClass) {
                                return <span className="text-[10px] font-black tracking-wider text-rose-700 uppercase bg-rose-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-rose-200">Missing Heavy Class</span>;
                              } else if (isExpired) {
                                return <span className="text-[10px] font-black tracking-wider text-rose-700 uppercase bg-rose-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-rose-200">TR Expired</span>;
                              } else {
                                return <span className="text-[10px] font-black tracking-wider text-emerald-700 uppercase bg-emerald-100 px-2 py-0.5 rounded-sm flex items-center gap-1 border border-emerald-200">Transport Eligible</span>;
                              }
                           })()}
                         </div>
                         <div className="text-xs font-bold text-slate-800 flex items-center gap-1">
                           {dlData.owner_name} {dlData.owner_name?.includes('*') && <span className="text-[9px] font-black tracking-wider text-rose-500 bg-rose-50 px-1 py-0.5 rounded uppercase">Masked</span>}
                         </div>
                         <div className="flex justify-between text-[10px] font-bold text-slate-500">
                           <span>TR Val: {dlData.validity_tr}</span>
                           <span>Class: {dlData.vehicle_classes?.join(', ')}</span>
                         </div>
                       </div>
                     )}
                   </div>

                    <div className="flex gap-3">
                     <DenseInput label="Driver Name" value={lorryDetails.driverName} onChange={e => setLorryDetails({...lorryDetails, driverName: e.target.value})} className="w-1/2 [&>input]:h-10" />
                     <DenseInput label="Driver Phone" value={lorryDetails.driverPhone} onChange={e => setLorryDetails({...lorryDetails, driverPhone: e.target.value})} className="w-1/2 [&>input]:h-10" />
                   </div>
                </div>
            </div>
          </GlassCard>
        </div>

        {/* Delivery Memo (Right - 66%) */}
        <div className="lg:col-span-2 relative z-20">
          <GlassCard className="relative z-20 h-full flex flex-col">
            <div className="flex items-center justify-between mb-4 border-b border-slate-100 pb-2">
              <div className="flex items-center gap-2">
                <div className="bg-indigo-50 text-indigo-600 p-2 rounded-lg shadow-inner border border-indigo-100/50"><PackageCheck size={18} /></div>
                <h3 className="font-bold text-lg text-slate-800 tracking-tight">Delivery Memo</h3>
              </div>
            </div>
            
            <div className="space-y-3">
              <div className="flex gap-2">
                <DenseInput label="GDM No" value={gdmNumberDisplay} readOnly className="w-1/3 [&>input]:font-black [&>input]:text-indigo-900 [&>input]:bg-indigo-50/50" />
                <DenseInput label="Date" type="date" value={gdmDetails.date} onChange={e => setGdmDetails({...gdmDetails, date: e.target.value})} className="w-1/3" />
                <DenseInput label="Time" type="time" value={gdmDetails.time || ''} onChange={e => setGdmDetails({...gdmDetails, time: e.target.value})} className="w-1/3" />
              </div>
              <div className="flex gap-2">
                <DenseInput label="From" value={gdmDetails.fromLocation} onChange={e => setGdmDetails({...gdmDetails, fromLocation: e.target.value})} className="w-1/3" />
                <DenseInput label="To (Name)" value={gdmDetails.toName} onChange={e => setGdmDetails({...gdmDetails, toName: e.target.value})} className="w-1/3" />
                <DenseInput label="Delivery At" value={gdmDetails.deliveryAt} onChange={e => setGdmDetails({...gdmDetails, deliveryAt: e.target.value})} className="w-1/3 [&>input]:border-amber-300 [&>input]:bg-amber-50 focus-within:[&>input]:border-amber-500" />
              </div>
              <div className="p-3 bg-slate-50/50 rounded-xl border border-slate-200 shadow-inner mt-2 relative z-20">
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
                          setSelectedConsigneeData(null);
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
                      <AsyncSearchableSelect 
                        id="consignee-select"
                        nextFocusId="gdm-gc-search"
                        label="Select Consignee"
                        fetchOptions={fetchConsigneesAsync}
                        value={selectedConsigneeData?.id?.toString() || ''}
                        onChange={handleConsigneeChange}
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
      </div>

      {/* HISTORY DRAWER */}
      <div className={`fixed inset-y-0 right-0 w-80 bg-white/95 backdrop-blur-xl shadow-2xl border-l border-slate-200 transform transition-transform duration-300 z-50 flex flex-col ${isHistoryOpen ? 'translate-x-0' : 'translate-x-full'}`}>
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
      {(isHistoryOpen || isDispatchDrawerOpen) && <div className="fixed inset-0 bg-slate-900/20 backdrop-blur-sm z-40 transition-opacity" onClick={() => { setIsHistoryOpen(false); setIsDispatchDrawerOpen(false); }} />}

      {/* DISPATCH DRAWER */}
      <div className={`fixed inset-y-0 right-0 w-full sm:w-[450px] bg-white/95 backdrop-blur-xl shadow-2xl border-l border-slate-200 transform transition-transform duration-300 z-50 flex flex-col ${isDispatchDrawerOpen ? 'translate-x-0' : 'translate-x-full'}`}>
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
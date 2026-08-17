import React, { useState, useEffect, useMemo, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useForm, FormProvider } from 'react-hook-form';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { usePermissions } from '../hooks/usePermissions';
import { useEwayBillProcessor } from '../hooks/useEwayBillProcessor';
import { AsyncSearchableSelect } from '../components/ui/AsyncSearchableSelect';
import PrintCopiesModal from '../components/ui/PrintCopiesModal';
import ScannerModal from '../components/ui/ScannerModal';
import { Save, Plus, Trash2, MapPin, Building2, Receipt, Package, Wallet, FileText, Camera, AlertCircle, Clock, X, Edit2, Printer, Loader2, Search } from 'lucide-react';
import { z } from 'zod';

import { DenseInput, DenseSelect, denseSearchableSelectClass, GlassCard } from '../components/ui/DensePrimitives';
import { Button } from '../components/ui/Button';

import { useLocation } from 'react-router-dom';
import { GcDocumentDetails } from '../components/entry/GcDocumentDetails';
import { PartyDetailsCard } from '../components/entry/PartyDetailsCard';
import { GoodsEntryTable } from '../components/entry/GoodsEntryTable';

export default function NewGcEntry() {
  const { canEdit } = usePermissions();
  const location = useLocation();
  const query = new URLSearchParams(location.search);
  const branch = localStorage.getItem('activeBranch') || query.get('branch') || 'MAIN';
  const [vehicles, setVehicles] = useState([]);

  const [godowns, setGodowns] = useState([]);
  
  const [unitHierarchy, setUnitHierarchy] = useState({
    'Cases': [{ label: 'Cases of Fireworks', code: 'C/S', colorClass: 'bg-emerald-100 text-emerald-700 border-emerald-200' }]
  });
  const [allUnitOptions, setAllUnitOptions] = useState([
    { label: 'Cases of Fireworks', code: 'C/S', colorClass: 'bg-emerald-100 text-emerald-700 border-emerald-200' }
  ]);

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState({});
  const [success, setSuccess] = useState('');

  // Edit Mode States
  const [activeGcId, setActiveGcId] = useState(null);
  const [searchEditGc, setSearchEditGc] = useState('');
  const [recentGcs, setRecentGcs] = useState([]);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const loadDraft = (key, defaultVal) => {
    try {
      const draftStr = localStorage.getItem('gcDraft');
      if (draftStr) {
        const draft = JSON.parse(draftStr);
        if (draft[key] !== undefined) return draft[key];
      }
    } catch(e) {}
    return defaultVal;
  };

  const getInitialDraftStatus = () => {
    try {
      const draftStr = localStorage.getItem('gcDraft');
      if (draftStr) {
        const draft = JSON.parse(draftStr);
        if (draft.timestamp) {
          const time = new Date(draft.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          return `Draft restored (from ${time})`;
        }
      }
    } catch(e) {}
    return '';
  };

  const [draftStatus, setDraftStatus] = useState(getInitialDraftStatus);
  const [ewayBillNo, setEwayBillNo] = useState(() => loadDraft('ewayBillNo', ''));
  const { fetchEwayBill, isFetchingEwb } = useEwayBillProcessor({ branch });
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [fetchedEwbDetails, setFetchedEwbDetails] = useState(() => loadDraft('fetchedEwbDetails', null));
  const [isReassigning, setIsReassigning] = useState(false);

  const [gcDetails, setGcDetails] = useState(() => loadDraft('gcDetails', {
    financialYear: '2026-2027',
    gcNumber: '',
    type: 'Regular',
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    companyMode: 'A', // 'A' for Transport GSTIN, 'B' for Crackers GSTIN
    godown: '',
  }));

  const [partyDetails, setPartyDetails] = useState(() => loadDraft('partyDetails', {
    consignorId: '',
    consignorGstin: '',
    consignorAddressPreview: '',
    isNewConsignor: false,
    consigneeId: '',
    consigneeGstin: '',
    consigneeAddressPreview: '',
    isNewConsignee: false,
    invoiceDate: new Date().toISOString().split('T')[0],
    invoiceNumber: '',
    privateMark: '',
    invoiceValue: '',
    actualWeight: 'FIXED',
    consignorData: null,
    consigneeData: null
  }));

  const methods = useForm({
    defaultValues: {
      goods: loadDraft('goods', [
        { id: Date.now(), articles: '', unitCategory: 'Cases', units: 'Cases of Fireworks', hsn: '', description: '', weight: '', rate: '', amount: 0 }
      ])
    }
  });
  const currentGoods = methods.watch('goods');

  const [freight, setFreight] = useState(() => loadDraft('freight', {
    type: 'To Pay',
    freightNote: '',
  }));

  // Auto-Save Draft (Debounced)
  useEffect(() => {
    if (activeGcId) return;

    const timeoutId = setTimeout(() => {
      // Create a clean copy of party details without massive nested JSON objects
      const { consignorData, consigneeData, ...cleanPartyDetails } = partyDetails;
      
      const now = Date.now();
      const draft = {
        ewayBillNo,
        // intentionally omitting `fetchedEwbDetails` as it can be >5MB and breaks localStorage
        gcDetails,
        partyDetails: cleanPartyDetails,
        goods: currentGoods,
        freight,
        timestamp: now
      };
      localStorage.setItem('gcDraft', JSON.stringify(draft));
      
      // Update status if it's not the initial mount
      if (draftStatus !== '') {
        const time = new Date(now).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        setDraftStatus(`Auto-saved at ${time}`);
      } else if (localStorage.getItem('gcDraft')) {
         // This catches the first autosave after they start typing
         const time = new Date(now).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
         setDraftStatus(`Auto-saved at ${time}`);
      }
    }, 500);

    return () => clearTimeout(timeoutId);
  }, [ewayBillNo, fetchedEwbDetails, gcDetails, partyDetails, currentGoods, freight, activeGcId]);

  // Unsaved Changes Warning (Tab Close/Refresh)
  useEffect(() => {
    const handleBeforeUnload = (e) => {
      // If we are not editing an existing GC, and a draft exists, warn them.
      if (!activeGcId && localStorage.getItem('gcDraft')) {
        e.preventDefault();
        e.returnValue = '';
      }
    };
    window.addEventListener('beforeunload', handleBeforeUnload);
    return () => window.removeEventListener('beforeunload', handleBeforeUnload);
  }, [activeGcId]);

  useKeyboardFlow({ onSave: () => handleSaveGC() });

  // React Query for Caching Masters
  const { data: godownsData = [] } = useQuery({
    queryKey: ['godowns'],
    queryFn: () => api.get('/godowns').then(res => res || [])
  });
  
  useEffect(() => {
    setGodowns(godownsData);
  }, [godownsData]);

  const { data: unitsData = [] } = useQuery({
    queryKey: ['units'],
    queryFn: () => api.get('/units').then(res => res || [])
  });

  useEffect(() => {
    if (unitsData && unitsData.length > 0) {
      const hierarchy = {};
      unitsData.forEach(u => {
        if (!hierarchy[u.category]) hierarchy[u.category] = [];
        hierarchy[u.category].push({
          label: u.description || u.name,
          code: u.code || '',
          colorClass: u.color ? `bg-${u.color}-100 text-${u.color}-700 border-${u.color}-200` : '',
          hsn: u.hsn || u.hsnCode || '',
          goodsDesc: u.goodsDesc || ''
        });
      });
      setUnitHierarchy(hierarchy);
      setAllUnitOptions(Object.values(hierarchy).flat());

      if (branch !== 'BNG') {
        const defaultItem = hierarchy['Cases'] ? hierarchy['Cases'][0] : null;
        if (defaultItem) {
          const currentValues = methods.getValues('goods');
          if (currentValues.length === 1 && currentValues[0].articles === '' && (!currentValues[0].description || currentValues[0].description === '')) {
            methods.setValue('goods.0', {
              ...currentValues[0],
              units: defaultItem.label,
              hsn: defaultItem.hsn || '',
              description: defaultItem.goodsDesc || ''
            });
          }
        }
      }
    }
  }, [unitsData, branch]);

  const fetchDynamicData = useCallback(async () => {
    try {
      const nextNumRes = await api.get(`/gcs/next-number?mode=${gcDetails.companyMode}&branch=${branch}`).catch(() => ({ nextNumber: '5001' }));
      setGcDetails(prev => ({ 
        ...prev, 
        gcNumber: nextNumRes.nextNumber || '5001'
      }));

      const recentRes = await api.get(`/gcs?branch=${branch}&limit=10`).catch(() => null);
      if (recentRes) {
        setRecentGcs(recentRes.gcs || recentRes.data || (Array.isArray(recentRes) ? recentRes : []));
      }
    } catch (err) {
      console.error('Failed to fetch dynamic data', err);
    }
  }, [branch, gcDetails.companyMode]);

  useEffect(() => {
    fetchDynamicData();
  }, [fetchDynamicData]);

  const handleCompanyToggle = async (mode) => {
    if (mode === gcDetails.companyMode) return;
    
    // Optimistic UI update for instant toggle feedback
    setGcDetails(prev => ({ 
      ...prev, 
      companyMode: mode,
      gcNumber: '...' 
    }));
    
    try {
      const res = await api.get(`/gcs/next-number?mode=${mode}&branch=${branch}`);
      setGcDetails(prev => ({ 
        ...prev, 
        companyMode: mode,
        gcNumber: res.nextNumber
      }));
    } catch (err) {
      console.error('Failed to get next number', err);
      setGcDetails(prev => ({ ...prev, gcNumber: 'ERROR' }));
    }
  };

  const handleEwayBillSearch = async () => {
    const result = await fetchEwayBill(ewayBillNo, gcDetails.companyMode);
    if (!result || !result.success) return;

    if (result.detectedCompany && result.detectedCompany !== gcDetails.companyMode) {
      handleCompanyToggle(result.detectedCompany);
    }
    
    setFetchedEwbDetails({ 
      ewbNo: result.cleanEwbNo, 
      rawData: result.ewbData, 
      company: result.detectedCompany || gcDetails.companyMode 
    });

    setPartyDetails(prev => ({
      ...prev,
      ...result.partyUpdates,
      invoiceDate: result.partyUpdates.invoiceDate || prev.invoiceDate,
      invoiceNumber: result.partyUpdates.invoiceNumber || prev.invoiceNumber,
      invoiceValue: result.partyUpdates.invoiceValue || prev.invoiceValue
    }));
  };

  const handleReassignTransporter = async () => {
    if (!fetchedEwbDetails) return;
    const targetCompany = fetchedEwbDetails.company === 'BELL' ? 'AP' : 'BELL';
    if (!window.confirm(`Are you sure you want to officially reassign this E-Way Bill from ${fetchedEwbDetails.company} to ${targetCompany}?`)) return;
    
    try {
      setIsReassigning(true);
      await api.post('/ewaybill/reassign', {
        ewbNo: fetchedEwbDetails.ewbNo,
        currentCompany: fetchedEwbDetails.company,
        targetCompany: targetCompany
      });
      setSuccess(`Successfully reassigned E-Way Bill to ${targetCompany}!`);
      setFetchedEwbDetails(prev => ({ ...prev, company: targetCompany }));
      handleCompanyToggle(targetCompany === 'BELL' ? 'B' : 'A');
    } catch (err) {
      setError(err.response?.data?.error || err.message || 'Failed to reassign transporter');
    } finally {
      setIsReassigning(false);
    }
  };

  const loadGcForEdit = async (e = null, overrideNum = null) => {
    // If e is a synthetic event, prevent default
    if (e && typeof e.preventDefault === 'function') e.preventDefault();
    
    let searchTerm = '';
    if (typeof overrideNum === 'string') searchTerm = overrideNum.trim();
    else if (typeof e === 'string') searchTerm = e.trim(); // Just in case
    else searchTerm = searchEditGc.trim();

    if (!searchTerm) return;

    let originalSearchTerm = searchTerm;
    let tryAlternatives = false;

    // Auto-prepend company prefix if user just typed the number
    if (/^\d+$/.test(searchTerm)) {
      searchTerm = `${gcDetails.companyMode === 'A' ? 'AP' : 'BELL'}-${searchTerm}`;
      tryAlternatives = true;
    }

    try {
      setLoading(true);
      
      let gc;
      try {
        gc = await api.get(`/gcs/${searchTerm}`);
      } catch (err) {
        if (tryAlternatives) {
          // If the default prefix failed, try the other one
          const altPrefix = gcDetails.companyMode === 'A' ? 'BELL' : 'AP';
          gc = await api.get(`/gcs/${altPrefix}-${originalSearchTerm}`);
        } else {
          throw err;
        }
      }
      
      setActiveGcId(gc.id);
      
      let cMode = 'A';
      let rawNum = gc.gcNumber;
      if (rawNum?.startsWith('AP-')) {
         cMode = 'A';
         rawNum = rawNum.substring(3);
      } else if (rawNum?.startsWith('BELL-')) {
         cMode = 'B';
         rawNum = rawNum.substring(5);
      }
      
      setGcDetails({
        companyMode: cMode,
        financialYear: gc.financialYear || '2026-2027',
        gcNumber: rawNum,
        type: gc.type || 'Regular',
        date: gc.date ? new Date(gc.date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
        time: gc.time || '',
        godown: gc.godown || '',
      });

      setPartyDetails({
        consignorId: gc.consignorId || '',
        consignorGstin: gc.consignor?.gstin || '',
        consignorAddressPreview: gc.consignor?.city || '',
        consigneeId: gc.consigneeId || '',
        consigneeGstin: gc.consignee?.gstin || '',
        consigneeAddressPreview: gc.consignee?.city || '',
        invoiceDate: gc.invoiceDate ? new Date(gc.invoiceDate).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
        invoiceNumber: gc.invoiceNumber || '',
        privateMark: gc.privateMark || '',
        invoiceValue: gc.invoiceValue?.toString() || '',
        actualWeight: gc.actualWeight || 'FIXED',
        consignorData: gc.consignor || null,
        consigneeData: gc.consignee || null,
      });

      if (gc.goods && gc.goods.length > 0) {
        methods.setValue('goods', gc.goods.map(g => {
          let legacyCat = 'Cases';
          const legacyDesc = g.units || '';
          for (const [cat, opts] of Object.entries(unitHierarchy)) {
            if (opts.find(o => o.label.toLowerCase() === legacyDesc.toLowerCase())) {
              legacyCat = cat;
              break;
            }
          }
          if (legacyCat === 'Cases' && !unitHierarchy['Cases']?.find(o => o.label.toLowerCase() === legacyDesc.toLowerCase())) {
            legacyCat = 'Other';
          }
          
          return {
            id: g.id || Date.now() + Math.random(),
            articles: g.articleCount?.toString() || '',
            unitCategory: legacyCat,
            units: g.units || '',
            hsn: g.hsn || '',
            description: g.description || '',
            weight: g.weight || '',
            rate: g.rate || '',
            amount: g.amount || 0
          };
        }));
      } else {
        methods.setValue('goods', [{ id: Date.now(), articles: '', unitCategory: 'Cases', units: 'Cases of Fireworks', hsn: '', description: '', weight: '', rate: '', amount: 0 }]);
      }

      setFreight({
        type: gc.freightType || 'To Pay',
        freightNote: gc.freightNote || '',
      });
      
      setSuccess('GC loaded for editing.');
      setTimeout(() => setSuccess(''), 2000);
    } catch (err) {
      if (err.status === 404) {
        setError('GC not found.');
      } else {
        setError('Failed to load GC.');
      }
      setActiveGcId(null);
    } finally {
      setLoading(false);
    }
  };

  const fetchConsignorsAsync = useCallback(async (q) => {
    try {
      const res = await api.get(`/consignors/search?branch=${branch}&q=${encodeURIComponent(q)}`);
      return res.map(c => ({ value: c.id.toString(), label: c.name, raw: c }));
    } catch (err) { console.error(err); return []; }
  }, [branch]);

  const fetchConsigneesAsync = useCallback(async (q) => {
    try {
      const res = await api.get(`/consignees/search?branch=${branch}&q=${encodeURIComponent(q)}`);
      return res.map(c => ({ value: c.id.toString(), label: c.name, raw: c }));
    } catch (err) { console.error(err); return []; }
  }, [branch]);

  const handleConsignorChange = useCallback((id, opt) => {
    const cons = opt?.raw;
    setPartyDetails(prev => ({
      ...prev,
      consignorId: id,
      consignorData: cons,
      consignorGstin: cons?.gstin || '',
      consignorAddressPreview: cons ? `${cons.city || ''} ${cons.state ? `(${cons.state})` : ''}` : ''
    }));
  }, []);

  const handleConsigneeChange = useCallback((id, opt) => {
    const cons = opt?.raw;
    setPartyDetails(prev => ({
      ...prev,
      consigneeId: id,
      consigneeData: cons,
      consigneeGstin: cons?.gstin || '',
      consigneeAddressPreview: cons ? `${cons.city || ''} ${cons.state ? `(${cons.state})` : ''}` : ''
    }));
  }, []);

  const getUnitBadge = useCallback((unitValue) => {
    const match = allUnitOptions.find(o => o.label.toLowerCase() === (unitValue || '').toLowerCase());
    if (!match) return null;
    return (
      <span className={`${match.colorClass} px-1.5 py-0.5 rounded border text-[9px] font-black tracking-wider flex items-center shrink-0 shadow-sm ml-2`}>
        <span className="text-current opacity-80 mr-1">✓</span> {match.code}
      </span>
    );
  }, [allUnitOptions]);

  const tally = useMemo(() => {
    let cases = 0, cartons = 0, bundles = 0, total = 0;
    (currentGoods || []).forEach(g => {
      const qty = parseInt(g.articles) || 0;
      total += qty;
      const match = allUnitOptions.find(o => o.label.toLowerCase() === (g.units || '').toLowerCase());
      const code = match ? match.code : null;
      if (code === 'C/S') cases += qty;
      else if (code === 'C/N') cartons += qty;
      else if (code === 'BD/S') bundles += qty;
    });
    return { cases, cartons, bundles, total };
  }, [currentGoods, allUnitOptions]);

  const handleSaveGC = async () => {
    // ANTI-REJECTION DEFENSE
    if (fetchedEwbDetails && fetchedEwbDetails.rawData) {
      if (fetchedEwbDetails.rawData.status === 'REJ') {
        setError('CRITICAL: This E-Way Bill has been REJECTED by the Consignee. You cannot generate a GC for it.');
        return;
      }
      if (fetchedEwbDetails.rawData.status === 'CNL') {
        setError('CRITICAL: This E-Way Bill has been CANCELLED. You cannot generate a GC for it.');
        return;
      }
    }

    try {
      setLoading(true);
      setError('');
      setFieldErrors({});

      let currentErrors = {};
      if (!gcDetails.godown) currentErrors.godown = true;
      if (!partyDetails.consignorId && !partyDetails.isNewConsignor) currentErrors.consignor = true;
      if (!partyDetails.consigneeId && !partyDetails.isNewConsignee) currentErrors.consignee = true;

      if (Object.keys(currentErrors).length > 0) {
        setFieldErrors(currentErrors);
        throw new Error("Please fill in all highlighted required fields.");
      }
      
      const formGoods = methods.getValues('goods');

      // Calculate total amount for BNG
      const totalAmount = branch === 'BNG' ? formGoods.reduce((sum, item) => sum + ((parseFloat(item.weight) || 0) * (parseFloat(item.rate) || 0)), 0) : 0;

      const { companyMode, ...safeGcDetails } = gcDetails;
      const { consignorData, consigneeData, isNewConsignor, isNewConsignee, ...safePartyDetails } = partyDetails;
      const finalGcNumber = `${companyMode === 'A' ? 'AP' : 'BELL'}-${safeGcDetails.gcNumber}`;

      const payload = {
        ...safeGcDetails,
        gcNumber: finalGcNumber,
        ...safePartyDetails,
        consignorId: parseInt(partyDetails.consignorId) || null,
        consigneeId: parseInt(partyDetails.consigneeId) || null,
        invoiceValue: parseFloat(partyDetails.invoiceValue) || 0,
        actualWeight: partyDetails.actualWeight,
        freightType: freight.type,
        freightRate: 0,
        freightTotal: branch === 'BNG' ? totalAmount : 0,
        advancePaid: 0,
        balanceFreight: branch === 'BNG' ? totalAmount : 0,
        freightFixed: 'Yes',
        freightNote: freight.freightNote,
        goods: formGoods.map(g => ({
          articles: parseInt(g.articles) || null,
          units: g.units,
          hsn: g.hsn,
          description: g.description,
          weight: branch === 'BNG' ? parseFloat(g.weight) || null : null,
          rate: branch === 'BNG' ? parseFloat(g.rate) || null : null,
          amount: branch === 'BNG' ? (parseFloat(g.weight) || 0) * (parseFloat(g.rate) || 0) || null : null
        })),
        ewbNumber: fetchedEwbDetails?.ewbNo || null,
        ewbRawData: fetchedEwbDetails?.rawData || null,
        branch
      };

      if (activeGcId) {
        await api.put(`/gcs/${activeGcId}`, payload);
        setSuccess(`GC ${gcDetails.gcNumber} updated successfully!`);
      } else {
        await api.post('/gcs', payload);
        setSuccess('GC created successfully!');
      }
      
      handleReset();
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to save');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    localStorage.removeItem('gcDraft');
    setActiveGcId(null);
    setSearchEditGc('');
    setEwayBillNo('');
    setFetchedEwbDetails(null);
    setIsReassigning(false);
    setGcDetails(prev => ({
      ...prev,
      date: new Date().toISOString().split('T')[0],
      time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    }));
    setPartyDetails({
      consignorId: '', consignorGstin: '', consignorAddressPreview: '',
      consigneeId: '', consigneeGstin: '', consigneeAddressPreview: '',
      invoiceDate: new Date().toISOString().split('T')[0],
      invoiceNumber: '', privateMark: '', invoiceValue: '', actualWeight: 'FIXED',
    });
    const defaultItem = unitHierarchy['Cases'] ? unitHierarchy['Cases'][0] : null;
    methods.reset({
      goods: [{ 
        id: Date.now(), 
        articles: '', 
        unitCategory: branch === 'BNG' ? '' : 'Cases', 
        units: branch === 'BNG' ? '' : (defaultItem ? defaultItem.label : 'Cases of Fireworks'), 
        hsn: branch === 'BNG' ? '' : (defaultItem?.hsn || ''), 
        description: branch === 'BNG' ? '' : (defaultItem?.goodsDesc || ''), 
        weight: '', 
        rate: '', 
        amount: 0 
      }]
    });
    setFreight({ type: 'To Pay', freightNote: '' });
    setDraftStatus('');
  };

  return (
    <FormProvider {...methods}>
      <div className="flex flex-col flex-1 w-full max-w-[1600px] mx-auto overflow-hidden bg-slate-50/50 relative" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
        
        {/* AMBIENT MESH BACKGROUND */}
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-indigo-300/20 rounded-full blur-[120px] pointer-events-none z-0" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] bg-violet-300/20 rounded-full blur-[120px] pointer-events-none z-0" />
      
        {/* HEADER RIBBON */}
        <div className="bg-white/80 backdrop-blur-md border-b border-slate-200/80 p-3 flex justify-between items-center shrink-0 z-20 shadow-sm relative">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <span className="font-extrabold text-2xl bg-clip-text text-transparent bg-gradient-to-r from-indigo-600 to-violet-500 tracking-tight">New GC</span>
              {!activeGcId && draftStatus && <span className="text-[10px] font-semibold text-slate-400 bg-slate-100 px-2 py-0.5 rounded-md border border-slate-200">{draftStatus}</span>}
              <div className="flex bg-slate-100 p-0.5 rounded-lg border border-slate-200 shadow-inner ml-2">
                 <button type="button" onClick={() => handleCompanyToggle('A')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>AP</button>
                 <button type="button" onClick={() => handleCompanyToggle('B')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>BELL</button>
              </div>
            </div>
          
          <div className="flex items-center gap-2 bg-indigo-50/50 p-1 rounded-lg border border-indigo-100">
             <DenseInput placeholder="Enter E-Way Bill" value={ewayBillNo} onChange={e => { setEwayBillNo(e.target.value); setFetchedEwbDetails(null); }} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleEwayBillSearch(); } }} className="w-48 [&>input]:h-8" />
             <Button variant="primary" type="button" onClick={handleEwayBillSearch} disabled={isFetchingEwb} className="h-8 px-3 py-0 text-xs shadow-sm flex items-center gap-1">{isFetchingEwb ? '...' : 'Fetch EWB'}</Button>
             <Button variant="custom" type="button" onClick={() => setIsScannerOpen(true)} className="h-8 w-8 p-0 flex items-center justify-center rounded-lg bg-emerald-600 text-white hover:bg-emerald-500 shadow-sm mr-2 transition-colors"><Camera size={14}/></Button>
             
             {fetchedEwbDetails && (
               <>
                 <Button 
                   variant="secondary"
                   type="button" 
                   onClick={handleReassignTransporter} 
                   disabled={isReassigning}
                   className="h-8 px-3 py-0 text-xs shadow-sm flex items-center gap-1 border-amber-300 text-amber-700 bg-amber-50 hover:bg-amber-100 transition-all"
                 >
                   {isReassigning ? 'Reassigning...' : `Reassign to ${fetchedEwbDetails.company === 'BELL' ? 'AP' : 'BELL'}`}
                 </Button>
                 {fetchedEwbDetails.rawData?.status === 'DIS' && (
                   <span className="bg-rose-100 text-rose-700 text-[10px] font-black px-2 py-0.5 rounded border border-rose-200 uppercase flex items-center h-8">
                     ⚠️ EXPIRED (Part-A Lapsed)
                   </span>
                 )}
                 {fetchedEwbDetails.rawData?.status === 'CNL' && (
                   <span className="bg-red-100 text-red-700 text-[10px] font-black px-2 py-0.5 rounded border border-red-300 uppercase flex items-center h-8 animate-pulse shadow-sm">
                     🚨 CANCELED EWB
                   </span>
                 )}
                 {fetchedEwbDetails.rawData?.status === 'REJ' && (
                   <div className="flex flex-col ml-2">
                     <span className="bg-red-600 text-white text-[10px] font-black px-2 py-0.5 rounded border border-red-700 uppercase flex items-center h-8 animate-pulse shadow-md">
                       🚨 REJECTED BY CONSIGNEE!
                     </span>
                   </div>
                 )}
                 {fetchedEwbDetails.rawData?.status === 'ACT' && (
                   <span className="bg-emerald-100 text-emerald-700 text-[10px] font-black px-2 py-0.5 rounded border border-emerald-200 uppercase flex items-center h-8">
                     ✅ ACTIVE EWB
                   </span>
                 )}
               </>
             )}
          </div>
        </div>

        <div className="flex items-center gap-3">
          {error && <div className="text-rose-600 font-bold text-sm flex items-center gap-1 animate-pulse"><AlertCircle size={14}/> {error}</div>}
          {success && <div className="text-emerald-600 font-bold text-sm flex items-center gap-1">✓ {success}</div>}
          
          <div className="bg-indigo-50 px-3 py-1.5 rounded-lg border border-indigo-100 text-indigo-700 font-bold text-sm flex items-center gap-2 ml-4">
            {gcDetails.companyMode === 'A' ? 'AP' : 'BELL'} - {gcDetails.gcNumber}
          </div>
          
          <Button variant="secondary" onClick={() => setIsHistoryOpen(true)} className="ml-2 flex items-center gap-2 h-9 px-4 py-0 text-xs shadow-sm bg-white border-slate-300 text-slate-700 hover:bg-slate-50 transition-colors">
            <Search size={14} className="text-indigo-500" /> Manage GCs
          </Button>
        </div>
      </div>

      <div className="flex flex-col flex-1 overflow-hidden">
        
        {/* LEFT COLUMN - DATA ENTRY (NOW FULL WIDTH) */}
        <div className="flex-1 flex flex-col overflow-hidden bg-slate-50/50">
          <div className="flex-1 overflow-y-auto p-6 custom-scrollbar">
            <div className="max-w-6xl mx-auto space-y-6 flex flex-col min-h-full">
            
            {/* DOC DETAILS */}
            <GcDocumentDetails 
              gcDetails={gcDetails} 
              setGcDetails={setGcDetails} 
              branch={branch} 
              godowns={godowns}
              fieldErrors={fieldErrors}
            />

            {/* PARTIES */}
            <PartyDetailsCard 
              partyDetails={partyDetails}
              setPartyDetails={setPartyDetails}
              fetchConsignorsAsync={fetchConsignorsAsync}
              handleConsignorChange={handleConsignorChange}
              fetchConsigneesAsync={fetchConsigneesAsync}
              handleConsigneeChange={handleConsigneeChange}
              fieldErrors={fieldErrors}
            />

            {/* GOODS & INVOICE */}
            <GoodsEntryTable 
              branch={branch}
              partyDetails={partyDetails}
              setPartyDetails={setPartyDetails}
              fetchedEwbDetails={fetchedEwbDetails}
              unitHierarchy={unitHierarchy}
              allUnitOptions={allUnitOptions}
              getUnitBadge={getUnitBadge}
            />

            </div>
          </div>
        </div>

        {/* ACTION FOOTER STICKY (FROSTED GLASS) */}
        <div className="p-4 bg-white/70 backdrop-blur-xl border-t border-slate-200/60 shrink-0 shadow-[0_-8px_30px_-5px_rgba(0,0,0,0.05)] z-30 relative">
           <div className="max-w-6xl mx-auto flex items-end justify-between gap-6">
             
             {/* Left: Remarks */}
             <div className="flex-1 max-w-[40%]">
               <DenseInput id="freight-remarks" label="Remarks" value={freight.freightNote} onChange={e => setFreight({...freight, freightNote: e.target.value})} className="w-full" />
             </div>

             {/* Center: Totals */}
             {branch !== 'BNG' && (
               <div className="flex-1 flex justify-center gap-8 pb-1">
                 <div className="flex flex-col items-center">
                   <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">Total</span>
                   <span className="text-xl font-black text-slate-800 leading-none">{tally.total}</span>
                 </div>
                 <div className="flex flex-col items-center">
                   <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">C/S</span>
                   <span className="text-xl font-black text-emerald-600 leading-none">{tally.cases}</span>
                 </div>
                 <div className="flex flex-col items-center">
                   <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">C/N</span>
                   <span className="text-xl font-black text-amber-600 leading-none">{tally.cartons}</span>
                 </div>
                 <div className="flex flex-col items-center">
                   <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1">BD/S</span>
                   <span className="text-xl font-black text-rose-600 leading-none">{tally.bundles}</span>
                 </div>
               </div>
             )}

             {/* Right: Actions */}
             <div className="flex-1 flex gap-3 justify-end max-w-[35%]">
               <Button variant="secondary" type="button" onClick={handleReset} className="w-28 h-12 text-sm shadow-sm hover:bg-white border-slate-300 hover:text-rose-600">Reset</Button>
               <Button variant="primary" type="button" onClick={handleSaveGC} disabled={loading || (activeGcId && !canEdit)} className="w-48 h-12 text-sm flex items-center justify-center gap-2 bg-gradient-to-r from-indigo-600 to-violet-600 hover:brightness-110 shadow-lg shadow-indigo-500/30 border-0 transition-all duration-300">
                 {loading ? <Loader2 size={18} className="animate-spin" /> : <Save size={18} />} {loading ? 'Saving...' : (activeGcId ? 'Update GC' : 'Save GC')}
               </Button>
             </div>

           </div>
        </div>

      </div>

      <PrintCopiesModal isOpen={showPrintModal} onClose={() => setShowPrintModal(false)} onConfirm={(copies) => { setShowPrintModal(false); window.open(`/print/gc/${searchEditGc}?copies=${copies.join(',')}`, '_blank'); }} />
      <ScannerModal isOpen={isScannerOpen} onClose={() => setIsScannerOpen(false)} onScan={(txt) => { setEwayBillNo(txt); setIsScannerOpen(false); }} />

      {/* HISTORY DRAWER */}
      <div className={`fixed inset-y-0 right-0 w-80 bg-white/95 backdrop-blur-xl shadow-2xl border-l border-slate-200 transform transition-transform duration-300 z-50 flex flex-col ${isHistoryOpen ? 'translate-x-0' : 'translate-x-full'}`}>
        <div className="p-4 border-b border-slate-200 bg-slate-50/50 flex flex-col gap-3 sticky top-0 z-10">
           <div className="flex justify-between items-center">
             <h2 className="font-bold flex items-center gap-2 text-slate-800"><Search size={16} className="text-indigo-500" /> Manage GCs</h2>
             <button onClick={() => setIsHistoryOpen(false)} className="p-1 hover:bg-slate-200 rounded-md text-slate-500 transition-colors"><X size={16} /></button>
           </div>
           
           <div className="flex gap-2">
             <div className="flex-1">
               <DenseInput 
                 placeholder="Search or Load GC #..." 
                 value={searchEditGc} 
                 onChange={e => setSearchEditGc(e.target.value)} 
                 onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); loadGcForEdit(); setIsHistoryOpen(false); } }} 
                 className="w-full [&>input]:bg-white [&>input]:h-9" 
               />
             </div>
             <div className="flex gap-1.5">
               <Button variant="custom" type="button" onClick={() => { loadGcForEdit(); setIsHistoryOpen(false); }} disabled={loading || !searchEditGc} className="h-9 px-3 rounded-lg text-xs font-bold text-indigo-700 bg-indigo-100 hover:bg-indigo-200 transition-colors disabled:opacity-50 flex items-center gap-1 shadow-sm"><Edit2 size={14}/> Edit</Button>
               <Button variant="custom" type="button" onClick={(e) => { e.preventDefault(); if (searchEditGc) { setShowPrintModal(true); setIsHistoryOpen(false); } }} disabled={!searchEditGc} className="h-9 px-3 rounded-lg text-xs font-bold text-slate-700 bg-white border border-slate-200 hover:bg-slate-50 transition-colors disabled:opacity-50 flex items-center gap-1 shadow-sm"><Printer size={14}/> Print</Button>
             </div>
           </div>
        </div>
        <div className="p-4 space-y-3 overflow-y-auto flex-1 custom-scrollbar">
           {recentGcs.map(gc => (
             <div key={gc.id} className="p-3 bg-white border border-slate-200 rounded-xl shadow-sm hover:border-indigo-300 transition-colors">
               <div className="flex justify-between items-start mb-2">
                 <span className="font-black text-indigo-700 text-sm">{gc.gcNumber}</span>
                 <span className="text-[10px] font-bold text-slate-400">{new Date(gc.date).toLocaleDateString('en-GB')}</span>
               </div>
               <div className="text-xs font-semibold text-slate-600 mb-2 truncate" title={`${gc.consignor?.name || 'Unknown'} → ${gc.consignee?.name || 'Unknown'}`}>
                 {gc.consignor?.name || 'Unknown'} &rarr; {gc.consignee?.name || 'Unknown'}
               </div>
               <div className="flex justify-end gap-2 mt-2">
                  <Button variant="secondary" onClick={() => { setIsHistoryOpen(false); setSearchEditGc(gc.gcNumber); setShowPrintModal(true); }} className="h-7 px-2.5 py-0 text-[11px] flex items-center gap-1 shadow-sm"><Printer size={12}/> Print</Button>
                  <Button variant="secondary" onClick={() => { setIsHistoryOpen(false); setSearchEditGc(gc.gcNumber); loadGcForEdit(null, gc.gcNumber); }} className="h-7 px-2.5 py-0 text-[11px] flex items-center gap-1 shadow-sm border-indigo-200 text-indigo-700 bg-indigo-50 hover:bg-indigo-100"><Edit2 size={12}/> Edit</Button>
               </div>
             </div>
           ))}
           {recentGcs.length === 0 && <p className="text-sm text-slate-400 text-center mt-10 font-medium">No recent GCs found.</p>}
        </div>
      </div>

      {/* OVERLAY */}
      {isHistoryOpen && <div className="fixed inset-0 bg-slate-900/20 backdrop-blur-sm z-40 transition-opacity" onClick={() => setIsHistoryOpen(false)} />}
    </div>
    </FormProvider>
  );
}

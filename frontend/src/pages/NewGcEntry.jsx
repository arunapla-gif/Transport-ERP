import React, { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import PrintCopiesModal from '../components/ui/PrintCopiesModal';
import ScannerModal from '../components/ui/ScannerModal';
import { Save, Plus, Trash2, MapPin, Building2, Receipt, Package, Wallet, FileText, Camera, AlertCircle } from 'lucide-react';

// Specialized compact input primitives for the Premium layout
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <select 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value || opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

// Overriding SearchableSelect classes for premium dense layout
const denseSearchableSelectClass = "[&>label]:!text-[10px] [&>label]:!font-bold [&>label]:!text-slate-500 [&>label]:!mb-0.5 [&>div:nth-of-type(1)]:!h-9 [&>div:nth-of-type(1)]:!min-h-0 [&>div:nth-of-type(1)]:!py-0 [&>div:nth-of-type(1)]:!rounded-lg [&>div:nth-of-type(1)]:!border-slate-200 [&>div:nth-of-type(1)]:!bg-white/50 [&>div:nth-of-type(1)]:!shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] [&>div:nth-of-type(1):focus-within]:!border-indigo-500 [&>div:nth-of-type(1):focus-within]:!ring-2 [&>div:nth-of-type(1):focus-within]:!ring-indigo-500/20 [&>div:nth-of-type(1)>input]:!text-sm [&>div:nth-of-type(1)>input]:!font-medium [&>div:nth-of-type(1)>input]:!text-slate-800 [&>div:nth-of-type(1)>div]:!text-sm [&>div:nth-of-type(1)>div]:!font-medium [&>div:nth-of-type(1)>svg]:!w-4 [&>div:nth-of-type(1)>svg]:!h-4 [&:hover>div:nth-of-type(1)]:!border-slate-300 [&:focus-within>label]:!text-indigo-600 [&>label]:transition-colors";

// Glassmorphic Card Wrapper Component (Tighter Padding)
const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-visible transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function NewGcEntry() {
  const [consignors, setConsignors] = useState([]);
  const [consignees, setConsignees] = useState([]);
  const [godowns, setGodowns] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Edit Mode States
  const [activeGcId, setActiveGcId] = useState(null);
  const [searchEditGc, setSearchEditGc] = useState('');
  const [recentGcs, setRecentGcs] = useState([]);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [ewayBillNo, setEwayBillNo] = useState('');
  const [isFetchingEwb, setIsFetchingEwb] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  const [fetchedEwbDetails, setFetchedEwbDetails] = useState(null);
  const [isReassigning, setIsReassigning] = useState(false);

  const [gcDetails, setGcDetails] = useState({
    financialYear: '2026-2027',
    gcNumber: '',
    type: 'Regular',
    date: new Date().toISOString().split('T')[0],
    time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    companyMode: 'A', // 'A' for Transport GSTIN, 'B' for Crackers GSTIN
    godown: '',
  });

  const [partyDetails, setPartyDetails] = useState({
    consignorId: '',
    consignorGstin: '',
    consignorAddressPreview: '',
    consigneeId: '',
    consigneeGstin: '',
    consigneeAddressPreview: '',
    invoiceDate: new Date().toISOString().split('T')[0],
    invoiceNumber: '',
    privateMark: '',
    invoiceValue: '',
  });

  const [goods, setGoods] = useState([
    { id: Date.now(), articles: '', units: 'Boxes', hsn: '', description: '' }
  ]);

  const [freight, setFreight] = useState({
    type: 'To Pay',
    freightNote: '',
  });

  useKeyboardFlow({ onSave: () => handleSaveGC() });

  useEffect(() => {
    fetchMasters();
  }, []);

  const fetchMasters = async () => {
    try {
      // Fetch sequentially to prevent overloading Neon DB connection pool on cold start.
      // Thanks to the new backend cache, sequential fetching takes less than 10ms once cached.
      const cons = await api.get('/consignors').catch(() => []);
      setConsignors(cons);
      
      const recs = await api.get('/consignees').catch(() => []);
      setConsignees(recs);
      
      const gods = await api.get('/godowns').catch(() => []);
      setGodowns(gods || []);

      const nextNumRes = await api.get(`/gcs/next-number?mode=${gcDetails.companyMode}`).catch(() => ({ nextNumber: '5001' }));
      setGcDetails(prev => ({ 
        ...prev, 
        gcNumber: nextNumRes.nextNumber || '5001'
      }));
    } catch (err) {
      console.error('Failed to fetch initial data', err);
    }
  };

  // Switch Company logic
  const handleCompanyToggle = async (mode) => {
    try {
      const res = await api.get(`/gcs/next-number?mode=${mode}`);
      setGcDetails(prev => ({ 
        ...prev, 
        companyMode: mode,
        gcNumber: res.nextNumber
      }));
    } catch (err) {
      console.error('Failed to get next number', err);
    }
  };

  const handleEwayBillSearch = async () => {
    if (!ewayBillNo.trim()) return;
    try {
      setIsFetchingEwb(true);
      setError('');
      setSuccess('');
      
      const cleanEwbNo = ewayBillNo.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}?company=${gcDetails.companyMode === 'B' ? 'BELL' : 'AP'}`);
      
      // Auto-Toggle Company
      if (ewbData.detectedCompany && ewbData.detectedCompany !== gcDetails.companyMode) {
        handleCompanyToggle(ewbData.detectedCompany);
      }
      
      // Auto-populate Party Details
      let cnorId = '';
      let cnorPreview = [ewbData.fromAddr1, ewbData.fromAddr2, ewbData.fromPlace].filter(Boolean).join(', ') + (ewbData.fromPincode ? ` - ${ewbData.fromPincode}` : '') + (ewbData.fromStateCode ? ` (State: ${ewbData.fromStateCode})` : '');
      
      let matchedConsignor = consignors.find(c => c.gstin && ewbData.fromGstin && c.gstin.trim().toLowerCase() === ewbData.fromGstin.trim().toLowerCase());
      if (!matchedConsignor && ewbData.fromTrdName) {
        matchedConsignor = consignors.find(c => c.name.trim().toLowerCase() === ewbData.fromTrdName.trim().toLowerCase());
      }

      if (matchedConsignor) {
        cnorId = matchedConsignor.id.toString();
        cnorPreview = [matchedConsignor.address, matchedConsignor.city, matchedConsignor.pincode].filter(Boolean).join(', ') + (matchedConsignor.state ? ` (State: ${matchedConsignor.state})` : '');
      } else if (ewbData.fromTrdName) {
        try {
          const newCnor = await api.post('/consignors', {
            name: ewbData.fromTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.fromGstin || '',
            address: [ewbData.fromAddr1, ewbData.fromAddr2].filter(Boolean).join(', '),
            city: ewbData.fromPlace || ewbData.fromAddr2 || '',
            state: ewbData.fromStateCode ? ewbData.fromStateCode.toString() : '',
            pincode: ewbData.fromPincode ? ewbData.fromPincode.toString() : ''
          });
          setConsignors(prev => [...prev, newCnor]);
          cnorId = newCnor.id.toString();
          cnorPreview = [newCnor.address, newCnor.city, newCnor.pincode].filter(Boolean).join(', ') + (newCnor.state ? ` (State: ${newCnor.state})` : '');
        } catch (e) {
          console.error("Auto-create consignor failed", e);
        }
      }

      let cneeId = '';
      let cneePreview = [ewbData.toAddr1, ewbData.toAddr2, ewbData.toPlace].filter(Boolean).join(', ') + (ewbData.toPincode ? ` - ${ewbData.toPincode}` : '') + (ewbData.toStateCode ? ` (State: ${ewbData.toStateCode})` : '');
      
      let matchedConsignee = consignees.find(c => c.gstin && ewbData.toGstin && c.gstin.trim().toLowerCase() === ewbData.toGstin.trim().toLowerCase());
      if (!matchedConsignee && ewbData.toTrdName) {
        matchedConsignee = consignees.find(c => c.name.trim().toLowerCase() === ewbData.toTrdName.trim().toLowerCase());
      }

      if (matchedConsignee) {
        cneeId = matchedConsignee.id.toString();
        cneePreview = [matchedConsignee.address, matchedConsignee.city, matchedConsignee.pincode].filter(Boolean).join(', ') + (matchedConsignee.state ? ` (State: ${matchedConsignee.state})` : '');
      } else if (ewbData.toTrdName) {
        try {
          const newCnee = await api.post('/consignees', {
            name: ewbData.toTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.toGstin || '',
            address: [ewbData.toAddr1, ewbData.toAddr2].filter(Boolean).join(', '),
            city: ewbData.toPlace || ewbData.toAddr2 || '',
            state: ewbData.toStateCode ? ewbData.toStateCode.toString() : '',
            pincode: ewbData.toPincode ? ewbData.toPincode.toString() : ''
          });
          setConsignees(prev => [...prev, newCnee]);
          cneeId = newCnee.id.toString();
          cneePreview = [newCnee.address, newCnee.city, newCnee.pincode].filter(Boolean).join(', ') + (newCnee.state ? ` (State: ${newCnee.state})` : '');
        } catch (e) {
          console.error("Auto-create consignee failed", e);
        }
      }
      
      // Parse DD/MM/YYYY to YYYY-MM-DD
      let parsedDate = partyDetails.invoiceDate;
      const rawDate = ewbData.docDate || ewbData.documentDate;
      if (rawDate) {
        if (rawDate.includes('/')) {
          const parts = rawDate.split('/');
          if (parts.length === 3) {
            parsedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
          }
        } else if (rawDate.includes('-') && rawDate.split('-')[0].length === 2) {
          const parts = rawDate.split('-');
          parsedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
        } else {
          parsedDate = rawDate;
        }
      }

      setPartyDetails(prev => ({
        ...prev,
        consignorId: cnorId,
        consignorGstin: ewbData.fromGstin,
        consignorAddressPreview: cnorPreview,
        consigneeId: cneeId,
        consigneeGstin: ewbData.toGstin,
        consigneeAddressPreview: cneePreview,
        invoiceDate: parsedDate,
        invoiceNumber: ewbData.docNo || ewbData.documentNo || prev.invoiceNumber,
        invoiceValue: ewbData.totInvValue ? ewbData.totInvValue.toString() : prev.invoiceValue,
      }));

      // Auto-populate Goods
      if (ewbData.itemList && ewbData.itemList.length > 0) {
        setGoods(ewbData.itemList.map((item, index) => ({
          id: Date.now() + index,
          articles: item.quantity?.toString() || '',
          units: item.qtyUnit || 'Boxes',
          hsn: item.hsnCode?.toString() || '',
          description: item.productName || ''
        })));
      }

      setSuccess('E-Way Bill details fetched successfully.');
      setFetchedEwbDetails({ 
        ewbNo: cleanEwbNo, 
        company: ewbData.detectedCompany === 'B' ? 'BELL' : 'AP' 
      });
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to fetch E-Way Bill');
      setFetchedEwbDetails(null);
    } finally {
      setIsFetchingEwb(false);
    }
  };

  const handleReassignTransporter = async () => {
    if (!fetchedEwbDetails) return;
    const targetCompany = fetchedEwbDetails.company === 'BELL' ? 'AP' : 'BELL';
    if (!window.confirm(`Are you sure you want to officially reassign this E-Way Bill from ${fetchedEwbDetails.company} to ${targetCompany}?`)) return;
    
    try {
      setIsReassigning(true);
      setError('');
      setSuccess('');
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

  const loadGcForEdit = async () => {
    if (!searchEditGc.trim()) return;
    try {
      setLoading(true);
      setError('');
      setSuccess('');
      
      const gc = await api.get(`/gcs/${searchEditGc.trim()}`);
      
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
      });

      if (gc.goods && gc.goods.length > 0) {
        setGoods(gc.goods.map(g => ({
          id: g.id || Date.now() + Math.random(),
          articles: g.articleCount?.toString() || '',
          units: g.units || '',
          hsn: g.hsn || '',
          description: g.description || ''
        })));
      } else {
        setGoods([{ id: Date.now(), articles: '', units: 'Boxes', hsn: '', description: '' }]);
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

  const handleConsignorChange = (id) => {
    const cons = consignors.find(c => c.id.toString() === id);
    setPartyDetails(prev => ({
      ...prev,
      consignorId: id,
      consignorGstin: cons?.gstin || '',
      consignorAddressPreview: cons ? `${cons.city || ''} ${cons.state ? `(${cons.state})` : ''}` : ''
    }));
  };

  const handleConsigneeChange = (id) => {
    const cons = consignees.find(c => c.id.toString() === id);
    setPartyDetails(prev => ({
      ...prev,
      consigneeId: id,
      consigneeGstin: cons?.gstin || '',
      consigneeAddressPreview: cons ? `${cons.city || ''} ${cons.state ? `(${cons.state})` : ''}` : ''
    }));
  };

  const addRow = () => {
    setGoods([...goods, { id: Date.now(), articles: '', units: 'Boxes', hsn: '', description: '', isNew: true }]);
  };

  const removeRow = (id) => {
    if (goods.length > 1) {
      setGoods(goods.filter(g => g.id !== id));
    }
  };



  const totalArticles = useMemo(() => {
    return goods.reduce((sum, item) => sum + (parseInt(item.articles) || 0), 0);
  }, [goods]);

  const handleSaveGC = async () => {
    try {
      setLoading(true);
      setError('');
      
      if (!partyDetails.consignorId || !partyDetails.consigneeId) {
        throw new Error('Please select both Consignor and Consignee');
      }
      
      if (!gcDetails.godown) {
        throw new Error('Godown is mandatory. Please select a Godown.');
      }

      const { companyMode, ...safeGcDetails } = gcDetails;
      const finalGcNumber = `${companyMode === 'A' ? 'AP' : 'BELL'}-${safeGcDetails.gcNumber}`;

      const payload = {
        ...safeGcDetails,
        gcNumber: finalGcNumber,
        ...partyDetails,
        consignorId: parseInt(partyDetails.consignorId),
        consigneeId: parseInt(partyDetails.consigneeId),
        invoiceValue: parseFloat(partyDetails.invoiceValue) || 0,
        freightType: freight.type,
        freightRate: 0,
        freightTotal: 0,
        advancePaid: 0,
        balanceFreight: 0,
        freightFixed: 'Yes',
        freightNote: freight.freightNote,
        goods: goods.map(g => ({
          articles: parseInt(g.articles) || null,
          units: g.units,
          hsn: g.hsn,
          description: g.description
        }))
      };

      if (activeGcId) {
        await api.put(`/gcs/${activeGcId}`, payload);
        setSuccess(`GC ${gcDetails.gcNumber} updated successfully!`);
      } else {
        await api.post('/gcs', payload);
        setSuccess('GC created successfully!');
      }
      
      handleReset();
      fetchMasters();
      
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to save');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setActiveGcId(null);
    setSearchEditGc('');
    setEwayBillNo('');
    setGcDetails(prev => ({
      ...prev,
      date: new Date().toISOString().split('T')[0],
      time: new Date().toTimeString().split(' ')[0].substring(0, 5),
    }));
    setPartyDetails({
      consignorId: '', consignorGstin: '', consignorAddressPreview: '',
      consigneeId: '', consigneeGstin: '', consigneeAddressPreview: '',
      invoiceDate: new Date().toISOString().split('T')[0],
      invoiceNumber: '', privateMark: '', invoiceValue: '',
    });
    setGoods([{ id: Date.now(), articles: '', units: 'Boxes', hsn: '', description: '' }]);
    setFreight({ type: 'To Pay', freightNote: '' });
  };

  return (
    <div className="flex flex-col h-[calc(100vh-60px)] max-w-[1600px] mx-auto overflow-hidden bg-slate-100/50" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER RIBBON */}
      <div className="bg-white border-b border-slate-200 p-3 flex justify-between items-center shrink-0 z-20 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800 text-lg">New GC</span>
            <div className="flex bg-slate-100 p-0.5 rounded-lg border border-slate-200">
               <button type="button" onClick={() => handleCompanyToggle('A')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>AP</button>
               <button type="button" onClick={() => handleCompanyToggle('B')} className={`px-3 py-1 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>BELL</button>
            </div>
          </div>
          
          <div className="flex items-center gap-2 bg-indigo-50/50 p-1 rounded-lg border border-indigo-100">
             <DenseInput placeholder="Enter E-Way Bill" value={ewayBillNo} onChange={e => { setEwayBillNo(e.target.value); setFetchedEwbDetails(null); }} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleEwayBillSearch(); } }} className="w-48 [&>input]:h-8" />
             <button type="button" onClick={handleEwayBillSearch} disabled={isFetchingEwb} className="h-8 px-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-md font-bold text-xs shadow-sm flex items-center gap-1">{isFetchingEwb ? '...' : 'Fetch EWB'}</button>
             <button type="button" onClick={() => setIsScannerOpen(true)} className="h-8 w-8 flex items-center justify-center bg-emerald-600 hover:bg-emerald-500 text-white rounded-md shadow-sm mr-2"><Camera size={14}/></button>
             
             {fetchedEwbDetails && (
               <button 
                 type="button" 
                 onClick={handleReassignTransporter} 
                 disabled={isReassigning}
                 className="h-8 px-3 bg-amber-500 hover:bg-amber-400 text-white rounded-md font-bold text-xs shadow-sm flex items-center gap-1 border border-amber-600 transition-all"
               >
                 {isReassigning ? 'Reassigning...' : `Reassign to ${fetchedEwbDetails.company === 'BELL' ? 'AP' : 'BELL'}`}
               </button>
             )}
          </div>
        </div>

        <div className="flex items-center gap-3">
          {error && <div className="text-rose-600 font-bold text-sm flex items-center gap-1 animate-pulse"><AlertCircle size={14}/> {error}</div>}
          {success && <div className="text-emerald-600 font-bold text-sm flex items-center gap-1">✓ {success}</div>}
          
          <div className="flex items-center gap-2 bg-amber-50/50 p-1 rounded-lg border border-amber-200 ml-4">
             <DenseInput placeholder="GC Number" value={searchEditGc} onChange={e => setSearchEditGc(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); loadGcForEdit(); } }} className="w-32 [&>input]:h-8 [&>input]:bg-white" />
             <button type="button" onClick={loadGcForEdit} disabled={loading} className="h-8 px-3 bg-amber-500 hover:bg-amber-400 text-white rounded-md font-bold text-xs shadow-sm">Load</button>
             <button type="button" onClick={(e) => { e.preventDefault(); if (searchEditGc) setShowPrintModal(true); }} className={`h-8 px-3 bg-indigo-100 text-indigo-700 hover:bg-indigo-200 rounded-md font-bold text-xs shadow-sm transition-all ${!searchEditGc ? 'opacity-50 pointer-events-none' : ''}`}>Print</button>
          </div>

          <div className="bg-indigo-50 px-3 py-1.5 rounded-lg border border-indigo-100 text-indigo-700 font-bold text-sm flex items-center gap-2 ml-2">
            {gcDetails.companyMode === 'A' ? 'AP' : 'BELL'} - {gcDetails.gcNumber}
          </div>
        </div>
      </div>

      <div className="flex flex-col flex-1 overflow-hidden">
        
        {/* LEFT COLUMN - DATA ENTRY (NOW FULL WIDTH) */}
        <div className="flex-1 flex flex-col overflow-hidden bg-slate-50/50">
          <div className="flex-1 overflow-y-auto p-6 custom-scrollbar">
            <div className="max-w-6xl mx-auto space-y-6">
            
            {/* DOC DETAILS */}
            <GlassCard>
              <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2"><FileText size={16} className="text-indigo-500"/> Document Details</h3>
              <div className="grid grid-cols-4 gap-3">
                <DenseSelect label="Fin. Year" options={['2026-2027', '2025-2026']} value={gcDetails.financialYear} onChange={e => setGcDetails({...gcDetails, financialYear: e.target.value})} />
                <DenseInput label="Booking Date" type="date" value={gcDetails.date} onChange={e => setGcDetails({...gcDetails, date: e.target.value})} />
                <DenseInput label="Time" type="time" value={gcDetails.time} onChange={e => setGcDetails({...gcDetails, time: e.target.value})} />
                <DenseSelect label="Godown *" options={[{value: '', label: 'Select Godown'}, ...godowns.map(g => ({value: g.name, label: g.name}))]} value={gcDetails.godown || ''} onChange={e => setGcDetails({...gcDetails, godown: e.target.value})} />
              </div>
            </GlassCard>

            {/* PARTIES */}
            <div className="grid grid-cols-2 gap-4">
              <GlassCard>
                 <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2"><Building2 size={16} className="text-blue-500"/> Consignor</h3>
                 <SearchableSelect id="consignor-select" label="Search Consignor *" options={consignors.map(c => ({ value: c.id.toString(), label: c.name }))} value={partyDetails.consignorId?.toString()} onChange={handleConsignorChange} autoFocus className={denseSearchableSelectClass} />
                 <div className="text-xs text-slate-500 mt-2 bg-slate-50 p-2 rounded border border-slate-100 min-h-[40px]">{partyDetails.consignorAddressPreview || 'No Address Selected'}</div>
                 <div className="text-xs font-mono font-bold text-indigo-700 mt-1 uppercase flex items-center gap-2">
                    {partyDetails.consignorGstin || 'No GSTIN'}
                    {partyDetails.consignorGstin && <span className="bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded border border-emerald-200 text-[9px] font-black tracking-wider flex items-center gap-1 shrink-0"><span className="text-emerald-500">✓</span> VERIFIED</span>}
                 </div>
              </GlassCard>
              <GlassCard>
                 <h3 className="font-bold text-sm text-slate-800 mb-3 flex items-center gap-2 border-b border-slate-100 pb-2"><MapPin size={16} className="text-emerald-500"/> Consignee</h3>
                 <SearchableSelect id="consignee-select" label="Search Consignee *" options={consignees.map(c => ({ value: c.id.toString(), label: c.name }))} value={partyDetails.consigneeId?.toString()} onChange={handleConsigneeChange} className={denseSearchableSelectClass} />
                 <div className="text-xs text-slate-500 mt-2 bg-slate-50 p-2 rounded border border-slate-100 min-h-[40px]">{partyDetails.consigneeAddressPreview || 'No Address Selected'}</div>
                 <div className="text-xs font-mono font-bold text-emerald-700 mt-1 uppercase flex items-center gap-2">
                    {partyDetails.consigneeGstin || 'No GSTIN'}
                    {partyDetails.consigneeGstin && <span className="bg-emerald-100 text-emerald-700 px-1.5 py-0.5 rounded border border-emerald-200 text-[9px] font-black tracking-wider flex items-center gap-1 shrink-0"><span className="text-emerald-500">✓</span> VERIFIED</span>}
                 </div>
              </GlassCard>
            </div>

            {/* GOODS & INVOICE */}
            <GlassCard>
               <div className="flex justify-between items-center mb-3 border-b border-slate-100 pb-2">
                 <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Package size={16} className="text-amber-500"/> Goods & Invoice Details</h3>
                 <div className="flex gap-4 items-center">
                    <DenseInput label="Inv No" value={partyDetails.invoiceNumber} onChange={e => setPartyDetails({...partyDetails, invoiceNumber: e.target.value})} className="w-24 [&>input]:h-7" />
                    <DenseInput label="Inv Date" type="date" value={partyDetails.invoiceDate} onChange={e => setPartyDetails({...partyDetails, invoiceDate: e.target.value})} className="w-32 [&>input]:h-7" />
                    <DenseInput label="Value ₹" type="number" value={partyDetails.invoiceValue} onChange={e => setPartyDetails({...partyDetails, invoiceValue: e.target.value})} className="w-28 [&>input]:h-7 [&>input]:bg-amber-50" />
                 </div>
               </div>
               
               <div className="grid grid-cols-[80px_100px_120px_1fr_80px] gap-2 mb-1 px-2 py-1 bg-slate-100/50 rounded-lg text-center border border-slate-200/50">
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Qty</div>
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit</div>
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">HSN</div>
                 <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Description of Goods</div>
                 <div></div>
              </div>
              
              <div className="space-y-1">
                {goods.map((item, index) => (
                  <div key={item.id} className="grid grid-cols-[80px_100px_120px_1fr_80px] gap-2 p-1 rounded-lg focus-within:bg-indigo-50/50 focus-within:ring-1 focus-within:ring-indigo-500 transition-all border border-transparent">
                    <DenseInput type="number" autoFocus={item.isNew} value={item.articles} onChange={(e) => setGoods(goods.map(g => g.id === item.id ? {...g, articles: e.target.value} : g))} />
                    <DenseInput value={item.units} onChange={(e) => setGoods(goods.map(g => g.id === item.id ? {...g, units: e.target.value} : g))} />
                    <DenseInput value={item.hsn} onChange={(e) => setGoods(goods.map(g => g.id === item.id ? {...g, hsn: e.target.value} : g))} />
                    <DenseInput value={item.description} onChange={(e) => setGoods(goods.map(g => g.id === item.id ? {...g, description: e.target.value} : g))} 
                      onKeyDown={(e) => {
                        if ((e.key === 'Enter' || e.key === 'Tab') && index === goods.length - 1) {
                          if (item.description.trim() !== '' || item.articles !== '') {
                            e.preventDefault();
                            addRow();
                          } else if (e.key === 'Enter') {
                            e.preventDefault();
                            document.getElementById('freight-remarks')?.focus();
                          }
                        }
                      }}/>
                    <div className="flex gap-1 justify-center items-center">
                      <button type="button" tabIndex="-1" onClick={addRow} className="h-9 w-9 flex items-center justify-center bg-white hover:bg-indigo-50 rounded-lg border border-slate-200 text-slate-600 shadow-sm"><Plus size={16} /></button>
                      <button type="button" tabIndex="-1" onClick={() => removeRow(item.id)} disabled={goods.length === 1} className="h-9 w-9 flex items-center justify-center bg-white hover:bg-rose-50 text-slate-400 disabled:opacity-50 border border-slate-200 rounded-lg shadow-sm"><Trash2 size={16} /></button>
                    </div>
                  </div>
                ))}
              </div>
            </GlassCard>

            </div>
          </div>
        </div>

        {/* ACTION FOOTER STICKY (MOVED FROM RIGHT COLUMN) */}
        <div className="p-4 bg-white border-t border-slate-200 shrink-0 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)] z-10">
           <div className="max-w-6xl mx-auto flex items-end justify-between gap-6">
             <div className="flex-1">
               <DenseInput id="freight-remarks" label="Remarks" value={freight.freightNote} onChange={e => setFreight({...freight, freightNote: e.target.value})} className="max-w-lg" />
             </div>
             <div className="flex gap-3 w-[400px]">
               <button type="button" onClick={handleReset} className="flex-1 h-12 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg font-bold text-sm transition-all border border-slate-300">Reset</button>
               <button type="button" onClick={handleSaveGC} disabled={loading} className="flex-[2] h-12 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold text-sm shadow-md transition-all flex items-center justify-center gap-2">
                 <Save size={18} /> {loading ? 'Saving...' : (activeGcId ? 'Update GC' : 'Save GC')}
               </button>
             </div>
           </div>
        </div>

      </div>

      <PrintCopiesModal isOpen={showPrintModal} onClose={() => setShowPrintModal(false)} onConfirm={(copies) => { setShowPrintModal(false); window.open(`/print/gc/${searchEditGc}?copies=${copies.join(',')}`, '_blank'); }} />
      <ScannerModal isOpen={isScannerOpen} onClose={() => setIsScannerOpen(false)} onScan={(txt) => { setEwayBillNo(txt); setIsScannerOpen(false); }} />
    </div>
  );
}

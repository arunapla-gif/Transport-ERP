import React, { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import PrintCopiesModal from '../components/ui/PrintCopiesModal';
import ScannerModal from '../components/ui/ScannerModal';
import { Save, Plus, Trash2, MapPin, Building2, Receipt, Package, Wallet, FileText, Camera } from 'lucide-react';

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

export default function GcEntry() {
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

  const getNextGcNumber = (mode, gcsArray) => {
    const prefix = mode === 'A' ? 'AP-' : 'BELL-';
    const startingPoint = 5001; 
    
    const filtered = gcsArray.filter(g => 
       g.gcNumber?.startsWith(prefix) || 
       (mode === 'A' && !g.gcNumber?.startsWith('AP-') && !g.gcNumber?.startsWith('BELL-'))
    );

    if (filtered.length === 0) return startingPoint.toString();

    const maxNum = Math.max(...filtered.map(g => {
       const numStr = g.gcNumber?.replace(prefix, '');
       const parsed = parseInt(numStr);
       return isNaN(parsed) ? 0 : parsed;
    }));

    return maxNum >= startingPoint ? (maxNum + 1).toString() : startingPoint.toString();
  };

  const fetchMasters = async () => {
    try {
      const cons = await api.get('/consignors');
      const recs = await api.get('/consignees');
      const gods = await api.get('/godowns');
      const gcs = await api.get('/gcs');
      
      setConsignors(cons);
      setConsignees(recs);
      setGodowns(gods || []);
      setRecentGcs(gcs || []);

      setGcDetails(prev => ({ 
        ...prev, 
        gcNumber: getNextGcNumber(prev.companyMode, gcs || []) 
      }));
    } catch (err) {
      console.error('Failed to fetch initial data', err);
    }
  };

  // Switch Company logic
  const handleCompanyToggle = (mode) => {
    setGcDetails(prev => ({ 
      ...prev, 
      companyMode: mode,
      gcNumber: getNextGcNumber(mode, recentGcs)
    }));
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
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to fetch E-Way Bill');
    } finally {
      setIsFetchingEwb(false);
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
    <div className="space-y-3 max-w-[1300px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      

      {/* 1. TOP RIBBON (GC Details) */}
      <GlassCard>
        <div className="flex flex-wrap gap-3 items-end justify-between">
          <div className="flex gap-3 items-end">
            
            {/* Multi-GSTIN Company Toggle */}
            <div className="flex flex-col gap-0.5">
              <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Billing Entity *</label>
              <div className="flex bg-slate-100/80 p-0.5 rounded-lg border border-slate-200 shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] h-9">
                <button 
                  type="button"
                  onClick={() => handleCompanyToggle('A')}
                  className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'A' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
                >
                  AP
                </button>
                <button 
                  type="button"
                  onClick={() => handleCompanyToggle('B')}
                  className={`px-3 flex items-center justify-center text-xs font-bold rounded-md transition-all ${gcDetails.companyMode === 'B' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/50' : 'text-slate-500 hover:text-slate-700'}`}
                >
                  BELL
                </button>
              </div>
            </div>

            <DenseSelect label="Fin. Year" options={['2026-2027', '2025-2026']} value={gcDetails.financialYear} onChange={e => setGcDetails({...gcDetails, financialYear: e.target.value})} className="w-24" />
            <div className="flex flex-col group w-32">
              <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Document No</label>
              <div className="flex h-9 rounded-lg overflow-hidden border border-indigo-200 bg-indigo-50/50 focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-500/20 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]">
                <span className="flex items-center justify-center px-2 bg-indigo-100/50 text-indigo-800 font-bold text-xs border-r border-indigo-200">
                  {gcDetails.companyMode === 'A' ? 'AP' : 'BELL'}-
                </span>
                <input 
                  className="w-full px-2 text-sm font-black text-indigo-900 bg-transparent outline-none" 
                  value={gcDetails.gcNumber} 
                  onChange={e => setGcDetails({...gcDetails, gcNumber: e.target.value})}
                  tabIndex="-1"
                />
              </div>
            </div>
            <DenseInput label="Booking Date" type="date" value={gcDetails.date} onChange={e => setGcDetails({...gcDetails, date: e.target.value})} className="w-32" />
            <DenseInput label="Time" type="time" value={gcDetails.time} onChange={e => setGcDetails({...gcDetails, time: e.target.value})} className="w-24" />
            <DenseSelect label="Service Type" options={['Regular', 'Retail', 'Express']} value={gcDetails.type} onChange={e => setGcDetails({...gcDetails, type: e.target.value})} className="w-28" />
            
            <div className="flex flex-col group w-36">
              <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Godown *</label>
              <select 
                className="h-9 px-2 bg-slate-50/50 border border-slate-200 text-sm font-semibold rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500/20 focus:border-indigo-500 focus:bg-white transition-all text-slate-800"
                value={gcDetails.godown || ''} 
                onChange={e => setGcDetails({...gcDetails, godown: e.target.value})}
              >
                <option value="">Select Godown</option>
                {godowns.map(g => (
                  <option key={g.id} value={g.name}>{g.name}</option>
                ))}
              </select>
            </div>
            
            {/* E-Way Bill Search */}
            <div className="flex items-end gap-1.5 ml-2 bg-indigo-50/50 p-1 rounded-lg border border-indigo-100">
              <DenseInput 
                label="E-Way Bill No." 
                placeholder="Enter EWB"
                value={ewayBillNo} 
                onChange={e => setEwayBillNo(e.target.value)} 
                onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleEwayBillSearch(); } }}
                className="w-36 [&>input]:h-8 [&>input]:text-xs [&>label]:text-indigo-700" 
              />
              <button 
                type="button"
                onClick={handleEwayBillSearch} 
                disabled={isFetchingEwb} 
                className="h-8 px-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-md font-bold text-[10px] shadow-sm transition-all"
              >
                {isFetchingEwb ? '...' : 'Fetch'}
              </button>
              <button 
                type="button"
                onClick={() => setIsScannerOpen(true)}
                title="Scan QR or E-Way Bill"
                className="h-8 w-8 flex items-center justify-center bg-emerald-600 hover:bg-emerald-500 text-white rounded-md shadow-sm transition-all ml-1"
              >
                <Camera size={14} />
              </button>
            </div>
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50/80 rounded-lg border border-indigo-100/50">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Status:</span>
            <div className="flex items-center gap-1 text-xs font-bold text-indigo-600">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 animate-pulse"></span>
              Draft
            </div>
          </div>
        </div>
      </GlassCard>

      {error && <div className="px-5 py-3 bg-rose-50/90 backdrop-blur-sm text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">⚠️</span> {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 backdrop-blur-sm text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">✓</span> {success}</div>}

      {/* 2. THE 3-PILLAR MIDDLE SECTION */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-3">
        
        {/* Consignor */}
        <GlassCard className="z-30">
          <div className="flex items-center gap-2 mb-3">
            <div className="bg-blue-50 text-blue-600 p-1.5 rounded-lg shadow-inner border border-blue-100/50"><Building2 size={16} /></div>
            <h3 className="font-bold text-sm text-slate-800 tracking-tight">Consignor</h3>
          </div>
          <SearchableSelect 
            id="consignor-select"
            nextFocusId="consignee-select"
            label="Search Party *"
            options={consignors.map(c => ({ value: c.id.toString(), label: c.name }))}
            value={partyDetails.consignorId?.toString()}
            onChange={handleConsignorChange}
            placeholder=""
            autoFocus
            className={denseSearchableSelectClass}
          />
          <div className="grid grid-cols-2 gap-2 mt-2">
             <DenseInput label="GSTIN" value={partyDetails.consignorGstin} readOnly tabIndex="-1" className="[&>input]:bg-slate-100/50 [&>input]:text-slate-500 [&>input]:uppercase" />
             <DenseInput label="City/Address" value={partyDetails.consignorAddressPreview} readOnly tabIndex="-1" className="[&>input]:bg-slate-100/50 [&>input]:text-slate-500" />
          </div>
        </GlassCard>

        {/* Consignee */}
        <GlassCard className="z-20">
          <div className="flex items-center gap-2 mb-3">
            <div className="bg-emerald-50 text-emerald-600 p-1.5 rounded-lg shadow-inner border border-emerald-100/50"><MapPin size={16} /></div>
            <h3 className="font-bold text-sm text-slate-800 tracking-tight">Consignee</h3>
          </div>
          <SearchableSelect 
            id="consignee-select"
            nextFocusId="invoice-no"
            label="Search Party *"
            options={consignees.map(c => ({ value: c.id.toString(), label: c.name }))}
            value={partyDetails.consigneeId?.toString()}
            onChange={handleConsigneeChange}
            placeholder=""
            className={denseSearchableSelectClass}
          />
          <div className="grid grid-cols-2 gap-2 mt-2">
             <DenseInput label="GSTIN" value={partyDetails.consigneeGstin} readOnly tabIndex="-1" className="[&>input]:bg-slate-100/50 [&>input]:text-slate-500 [&>input]:uppercase" />
             <DenseInput label="City/Address" value={partyDetails.consigneeAddressPreview} readOnly tabIndex="-1" className="[&>input]:bg-slate-100/50 [&>input]:text-slate-500" />
          </div>
        </GlassCard>

        {/* Invoice & Values */}
        <GlassCard className="z-10">
          <div className="flex items-center gap-2 mb-3">
            <div className="bg-amber-50 text-amber-600 p-1.5 rounded-lg shadow-inner border border-amber-100/50"><Receipt size={16} /></div>
            <h3 className="font-bold text-sm text-slate-800 tracking-tight">Invoice Details</h3>
          </div>
          <div className="grid grid-cols-2 gap-2">
            <DenseInput id="invoice-no" label="Invoice No" value={partyDetails.invoiceNumber} onChange={e => setPartyDetails({...partyDetails, invoiceNumber: e.target.value})} />
            <DenseInput label="Invoice Date" type="date" value={partyDetails.invoiceDate} onChange={e => setPartyDetails({...partyDetails, invoiceDate: e.target.value})} />
            <DenseInput label="Private Mark" value={partyDetails.privateMark} onChange={e => setPartyDetails({...partyDetails, privateMark: e.target.value})} />
            <DenseInput label="Invoice Value ₹" type="number" value={partyDetails.invoiceValue} onChange={e => setPartyDetails({...partyDetails, invoiceValue: e.target.value})} className="[&>input]:font-black [&>input]:text-slate-800 [&>input]:bg-amber-50/30" />
          </div>
        </GlassCard>
      </div>

      {/* 3. COMPRESSED GOODS TABLE */}
      <GlassCard>
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <div className="bg-indigo-50 text-indigo-600 p-1.5 rounded-lg shadow-inner border border-indigo-100/50"><Package size={16} /></div>
            <h3 className="font-bold text-sm text-slate-800 tracking-tight">Goods Particulars</h3>
          </div>
          <div className="px-3 py-1 bg-indigo-50/50 rounded-md border border-indigo-100/50 text-[11px] font-medium text-slate-600">
             Total Quantity: <span className="text-indigo-900 font-black text-sm ml-1">{totalArticles}</span>
          </div>
        </div>
        
        <div className="grid grid-cols-[80px_100px_120px_1fr_80px] gap-2 mb-1 px-2 py-1.5 bg-slate-100/50 rounded-lg text-center border border-slate-200/50 backdrop-blur-sm">
           <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Qty</div>
           <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit</div>
           <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">HSN</div>
           <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Description of Goods</div>
           <div></div>
        </div>
        
        <div className="space-y-1 max-h-[160px] overflow-y-auto pr-1 custom-scrollbar">
          {goods.map((item, index) => (
            <div key={item.id} className="grid grid-cols-[80px_100px_120px_1fr_80px] gap-2 p-1 rounded-lg hover:bg-slate-50 hover:shadow-sm transition-all duration-200 border border-transparent hover:border-slate-100">
              <DenseInput type="number" autoFocus={item.isNew} value={item.articles} onChange={(e) => {
                setGoods(goods.map(g => g.id === item.id ? {...g, articles: e.target.value} : g));
              }} />
              <DenseInput value={item.units} onChange={(e) => {
                setGoods(goods.map(g => g.id === item.id ? {...g, units: e.target.value} : g));
              }} />
              <DenseInput value={item.hsn} onChange={(e) => {
                setGoods(goods.map(g => g.id === item.id ? {...g, hsn: e.target.value} : g));
              }} />
              <DenseInput value={item.description} onChange={(e) => {
                setGoods(goods.map(g => g.id === item.id ? {...g, description: e.target.value} : g));
              }} 
              onKeyDown={(e) => {
                if ((e.key === 'Enter' || e.key === 'Tab') && index === goods.length - 1) {
                  if (item.description.trim() !== '' || item.articles !== '') {
                    e.preventDefault();
                    addRow();
                  } else if (e.key === 'Enter') {
                    // If row is empty and user presses Enter, exit grid and jump to Remarks
                    e.preventDefault();
                    const remarks = document.getElementById('freight-remarks');
                    if (remarks) remarks.focus();
                  }
                }
              }}/>
              <div className="flex gap-1 justify-center items-center">
                <button type="button" tabIndex="-1" onClick={addRow} className="h-9 w-9 flex items-center justify-center bg-white hover:bg-indigo-50 rounded-lg border border-slate-200 text-slate-600 hover:text-indigo-600 shadow-[0_1px_2px_rgba(0,0,0,0.02)] hover:-translate-y-[1px] active:scale-95 transition-all"><Plus size={16} /></button>
                <button type="button" tabIndex="-1" onClick={() => removeRow(item.id)} disabled={goods.length === 1} className="h-9 w-9 flex items-center justify-center bg-white hover:bg-rose-50 hover:text-rose-600 rounded-lg border border-slate-200 text-slate-400 disabled:opacity-50 shadow-[0_1px_2px_rgba(0,0,0,0.02)] hover:-translate-y-[1px] active:scale-95 transition-all"><Trash2 size={16} /></button>
              </div>
            </div>
          ))}
        </div>
      </GlassCard>

      {/* 4. HORIZONTAL FREIGHT & ACTION FOOTER */}
      <GlassCard>
        <div className="flex flex-col lg:flex-row gap-4 items-end justify-between">
           
           <div className="flex flex-wrap gap-3 items-end flex-1">
              
              {/* COMPACT EDIT & PRINT GC */}
              <div className="flex items-center gap-2 mr-4 bg-amber-50/80 p-1.5 pr-1.5 rounded-lg border border-amber-200/60 shadow-sm">
                <div className="bg-amber-100 text-amber-700 p-1 rounded-md shadow-inner"><Receipt size={14} /></div>
                <DenseInput 
                  placeholder="GC Number" 
                  value={searchEditGc} 
                  onChange={e => setSearchEditGc(e.target.value)} 
                  onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); loadGcForEdit(); } }}
                  tabIndex="-1"
                  className="w-28 [&>input]:font-black [&>input]:text-amber-900 [&>input]:bg-white [&>input]:h-7 [&>input]:text-xs" 
                />
                <button onClick={loadGcForEdit} tabIndex="-1" disabled={loading} className="h-7 px-2.5 bg-amber-500 hover:bg-amber-400 text-white rounded-md font-bold text-[10px] shadow-sm transition-all">Load</button>
                <button 
                  onClick={(e) => { e.preventDefault(); if (searchEditGc) setShowPrintModal(true); }}
                  className={`h-7 px-2 flex items-center justify-center bg-indigo-100 hover:bg-indigo-200 text-indigo-700 rounded-md shadow-sm transition-all ${!searchEditGc ? 'opacity-50 pointer-events-none' : ''}`}
                  title="Print this GC"
                >
                  <FileText size={14} />
                </button>
              </div>

              {/* PAYMENT DETAILS */}
              <div className="flex items-center gap-2 mb-2 lg:mb-0 lg:mr-2">
                <div className="bg-slate-100 text-slate-600 p-1.5 rounded-lg shadow-inner border border-slate-200/50"><Wallet size={16} /></div>
                <h3 className="font-bold text-sm text-slate-800 tracking-tight">Payment</h3>
              </div>
              <DenseSelect id="payment-type" label="Type" options={['To Pay']} value="To Pay" onChange={() => {}} className="w-24 [&>select]:bg-slate-100/50 [&>select]:pointer-events-none" tabIndex="-1" />
              <DenseInput label="Freight Logic" value="Fixed" readOnly className="w-20 [&>input]:bg-slate-100/50 [&>input]:text-slate-500" tabIndex="-1" />
              <DenseInput id="freight-remarks" label="Remarks" value={freight.freightNote} onChange={e => setFreight({...freight, freightNote: e.target.value})} className="w-32 lg:flex-1" />
           </div>

           <div className="flex gap-2">
             <button type="button" tabIndex="-1" onClick={handleReset} className="h-9 px-4 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 hover:border-slate-300 shadow-sm hover:shadow transition-all duration-200 hover:-translate-y-[1px] active:translate-y-[1px] active:scale-95 flex items-center">
               Reset
             </button>
             <button type="button" onClick={handleSaveGC} disabled={loading} className="h-9 px-5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold text-xs shadow-[0_2px_8px_rgba(79,70,229,0.3)] hover:shadow-[0_4px_12px_rgba(79,70,229,0.4)] transition-all duration-200 hover:-translate-y-[1px] active:translate-y-[1px] active:scale-95 flex items-center gap-1.5">
               <FileText size={14} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Wait...' : (activeGcId ? 'Update GC' : 'Submit')}
             </button>
           </div>

         </div>
      </GlassCard>

      <PrintCopiesModal 
        isOpen={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        onConfirm={(copies) => {
          setShowPrintModal(false);
          const copiesQuery = copies.join(',');
          window.open(`/print/gc/${searchEditGc}?copies=${copiesQuery}`, '_blank');
        }}
      />

      <ScannerModal 
        isOpen={isScannerOpen} 
        onClose={() => setIsScannerOpen(false)} 
        onScan={(scannedText) => {
          setEwayBillNo(scannedText);
          setIsScannerOpen(false);
        }} 
      />
    </div>
  );
}

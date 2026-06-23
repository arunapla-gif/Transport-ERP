import React, { useState, useEffect, useRef, useCallback } from 'react';
import { api } from '../api';
import { AsyncSearchableSelect } from '../components/ui/AsyncSearchableSelect';
import { Save, CheckCircle2, Zap, ArrowRight, Database, Trash2 } from 'lucide-react';

const DenseInput = ({ className = "", ...props }) => (
  <input 
    className={`w-full h-8 px-2 border border-slate-200 rounded text-sm font-semibold text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 bg-white transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] read-only:bg-slate-50 read-only:text-slate-500 ${className}`} 
    {...props}
  />
);

const denseSearchableSelectClass = "[&>label]:hidden [&>div:nth-of-type(1)]:!h-8 [&>div:nth-of-type(1)]:!min-h-0 [&>div:nth-of-type(1)]:!py-0 [&>div:nth-of-type(1)]:!rounded [&>div:nth-of-type(1)]:!border-slate-200 [&>div:nth-of-type(1)]:!bg-white [&>div:nth-of-type(1)]:!shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] [&>div:nth-of-type(1):focus-within]:!border-indigo-500 [&>div:nth-of-type(1):focus-within]:!ring-1 [&>div:nth-of-type(1):focus-within]:!ring-indigo-500 [&>div:nth-of-type(1)>input]:!text-xs [&>div:nth-of-type(1)>input]:!font-semibold [&>div:nth-of-type(1)>input]:!text-slate-800 [&>div:nth-of-type(1)>div]:!text-xs [&>div:nth-of-type(1)>div]:!font-semibold [&>div:nth-of-type(1)>div]:!truncate [&>div:nth-of-type(1)>svg]:!w-3 [&>div:nth-of-type(1)>svg]:!h-3 [&:hover>div:nth-of-type(1)]:!border-slate-300";

export default function LegacyRapidEntry() {
  const [consignors, setConsignors] = useState([]);
  const [consignees, setConsignees] = useState([]);
  const [godowns, setGodowns] = useState([]);
  
  const [unitHierarchy, setUnitHierarchy] = useState({
    'Cases': [{ label: 'Cases of Fireworks', code: 'C/S', colorClass: 'bg-emerald-100 text-emerald-700 border-emerald-200' }]
  });
  const [allUnitOptions, setAllUnitOptions] = useState([
    { label: 'Cases of Fireworks', code: 'C/S', colorClass: 'bg-emerald-100 text-emerald-700 border-emerald-200' }
  ]);

  
  const [loading, setLoading] = useState(false);
  const [isFetchingEwb, setIsFetchingEwb] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [reassignSuccess, setReassignSuccess] = useState('');
  const [isReassigning, setIsReassigning] = useState(false);
  
  const [savedRecords, setSavedRecords] = useState([]);
  const [editingId, setEditingId] = useState(null);
  
  const initialRowState = {
    date: new Date().toISOString().split('T')[0],
    companyMode: 'A', // A or B
    gcNumber: '',
    ewbNumber: '',
    consignorId: '',
    consignorData: null,
    consigneeId: '',
    consigneeData: null,
    isNewConsignor: false,
    isNewConsignee: false,
    invoiceNumber: '',
    invoiceValue: '',
    godown: 'Main Branch',
    goods: [{ id: Date.now(), articles: '', unitCategory: 'Cases', units: 'Cases of Fireworks', hsn: '3604', description: 'Legacy Goods', weight: '', rate: '', amount: 0, isNew: true }]
  };

  const [row, setRow] = useState(initialRowState);

  // References for keyboard flow
  const ewbRef = useRef(null);
  const gcRef = useRef(null);
  
  useEffect(() => {
    fetchMasters();
    fetchRecentRecords();
  }, []);

  const fetchConsignorsAsync = useCallback(async (q) => {
    try {
      const res = await api.get(`/consignors/search?branch=MAIN&q=${encodeURIComponent(q)}`);
      return res.map(c => ({ value: c.id.toString(), label: c.name, raw: c }));
    } catch (err) { console.error(err); return []; }
  }, []);

  const fetchConsigneesAsync = useCallback(async (q) => {
    try {
      const res = await api.get(`/consignees/search?branch=MAIN&q=${encodeURIComponent(q)}`);
      return res.map(c => ({ value: c.id.toString(), label: c.name, raw: c }));
    } catch (err) { console.error(err); return []; }
  }, []);

  const fetchRecentRecords = async () => {
    try {
      const gcs = await api.get('/gcs?limit=10');
      // Format them exactly how the local payload maps them to the table
      const formatted = gcs.map(gc => ({
        id: gc.id,
        gcNumber: gc.gcNumber,
        date: gc.date ? new Date(gc.date).toISOString().split('T')[0] : '',
        ewbNumber: gc.ewbNumber,
        invoiceNumber: gc.invoiceNumber,
        invoiceValue: gc.invoiceValue,
        consignorName: gc.consignor?.name || 'Unknown',
        consigneeName: gc.consignee?.name || 'Unknown',
        godown: gc.godown || '-',
        goods: gc.goods?.map(g => ({ ...g, articles: g.articleCount })) || [],
        // Preserve raw db object for editing
        raw: gc 
      }));
      setSavedRecords(formatted);
    } catch (e) {
      console.error("Failed to load recent GCs", e);
    }
  };

  const fetchMasters = async () => {
    try {
      const [godownRes, unitsRes] = await Promise.all([
        api.get('/godowns'),
        api.get('/units').catch(() => [])
      ]);
      if (godownRes && godownRes.length > 0) {
        setGodowns(godownRes);
        setRow(prev => ({ ...prev, godown: godownRes[0].name }));
      }
      if (unitsRes && unitsRes.length > 0) {
        const hierarchy = {};
        unitsRes.forEach(u => {
          if (!hierarchy[u.category]) hierarchy[u.category] = [];
          hierarchy[u.category].push({
            label: u.description,
            code: u.code,
            colorClass: `bg-${u.color}-100 text-${u.color}-700 border-${u.color}-200`,
            hsn: u.hsn || '',
            goodsDesc: u.goodsDesc || ''
          });
        });
        setUnitHierarchy(hierarchy);
        setAllUnitOptions(Object.values(hierarchy).flat());
        
        const defaultItem = hierarchy['Cases'] ? hierarchy['Cases'][0] : null;
        if (defaultItem) {
          setRow(prev => ({
            ...prev,
            goods: [{ ...prev.goods[0], units: defaultItem.label, hsn: defaultItem.hsn || '', description: defaultItem.goodsDesc || 'Legacy Goods' }]
          }));
        }
      }
    } catch (err) {
      console.error("Failed to load masters", err);
    }
  };

  const handleEwbBlur = async (e) => {
    const ewbNo = e.target.value.replace(/[^0-9]/g, '');
    if (!ewbNo) {
      setRow(prev => ({
        ...prev,
        ewbRawData: null,
        consignorId: '',
        consigneeId: '',
        invoiceNumber: '',
        invoiceValue: '',
        isNewConsignor: false,
        isNewConsignee: false
      }));
      return;
    }
    
    if (ewbNo.length !== 12 || isFetchingEwb) return;
    if (ewbNo === row.ewbRawData?.ewbNo) return; // Prevent double fetching
    
    try {
      setIsFetchingEwb(true);
      setError('');
      
      const companyQuery = row.companyMode === 'A' ? 'AP' : 'BELL';
      const ewbData = await api.get(`/ewaybill/${ewbNo}?company=${companyQuery}`);
      
      let cnorId = '';
      let isNewCnor = false;
      let matchedCnor = null;
      if (ewbData.fromGstin || ewbData.fromTrdName) {
         const cnorRes = await api.get(`/consignors/search?branch=MAIN&q=${encodeURIComponent(ewbData.fromGstin || ewbData.fromTrdName)}`);
         matchedCnor = cnorRes.find(c => (c.gstin && ewbData.fromGstin && c.gstin.toLowerCase() === ewbData.fromGstin.toLowerCase()) || c.name.toLowerCase() === ewbData.fromTrdName?.toLowerCase());
      }
      
      if (matchedCnor) {
        cnorId = matchedCnor.id.toString();
      } else if (ewbData.fromTrdName) {
        try {
          const newCnor = await api.post('/consignors', {
            name: ewbData.fromTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.fromGstin ? ewbData.fromGstin.toUpperCase() : '',
            address: [ewbData.fromAddr1, ewbData.fromAddr2].filter(Boolean).join(', '),
            city: ewbData.fromPlace || ewbData.fromAddr2 || '',
            state: ewbData.fromStateCode ? ewbData.fromStateCode.toString() : '',
            pincode: ewbData.fromPincode ? ewbData.fromPincode.toString() : ''
          });
          matchedCnor = newCnor;
          cnorId = newCnor.id.toString();
          isNewCnor = true;
        } catch (e) {
          console.error("Auto-create consignor failed", e);
        }
      }
      
      let cneeId = '';
      let isNewCnee = false;
      let matchedCnee = null;
      if (ewbData.toGstin || ewbData.toTrdName) {
         const cneeRes = await api.get(`/consignees/search?branch=MAIN&q=${encodeURIComponent(ewbData.toGstin || ewbData.toTrdName)}`);
         matchedCnee = cneeRes.find(c => (c.gstin && ewbData.toGstin && c.gstin.toLowerCase() === ewbData.toGstin.toLowerCase()) || c.name.toLowerCase() === ewbData.toTrdName?.toLowerCase());
      }
      
      if (matchedCnee) {
        cneeId = matchedCnee.id.toString();
      } else if (ewbData.toTrdName) {
        try {
          const newCnee = await api.post('/consignees', {
            name: ewbData.toTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.toGstin ? ewbData.toGstin.toUpperCase() : '',
            address: [ewbData.toAddr1, ewbData.toAddr2].filter(Boolean).join(', '),
            city: ewbData.toPlace || ewbData.toAddr2 || '',
            state: ewbData.toStateCode ? ewbData.toStateCode.toString() : '',
            pincode: ewbData.toPincode ? ewbData.toPincode.toString() : ''
          });
          matchedCnee = newCnee;
          cneeId = newCnee.id.toString();
          isNewCnee = true;
        } catch (e) {
          console.error("Auto-create consignee failed", e);
        }
      }

      setRow(prev => ({
        ...prev,
        ewbNumber: ewbNo,
        ewbRawData: ewbData.rawData || ewbData,
        companyMode: ewbData.detectedCompany ? ewbData.detectedCompany : prev.companyMode,
        consignorId: cnorId,
        consignorData: matchedCnor,
        isNewConsignor: isNewCnor,
        consigneeId: cneeId,
        consigneeData: matchedCnee,
        isNewConsignee: isNewCnee,
        invoiceNumber: ewbData.docNo || ewbData.documentNo || prev.invoiceNumber,
        invoiceValue: ewbData.totInvValue ? ewbData.totInvValue.toString() : prev.invoiceValue,
        date: parseEwbDate(ewbData.docDate || ewbData.documentDate) || prev.date,
        goods: prev.goods
      }));

    } catch (err) {
      setError(`Failed to fetch EWB ${ewbNo}. Proceed manually.`);
    } finally {
      setIsFetchingEwb(false);
    }
  };

  const parseEwbDate = (rawDate) => {
    if (!rawDate) return null;
    try {
      if (rawDate.includes('/')) {
        const parts = rawDate.split('/');
        return `${parts[2]}-${parts[1]}-${parts[0]}`;
      }
      return rawDate;
    } catch {
      return null;
    }
  };

  const handleSaveRow = async (e) => {
    if (e) e.preventDefault();
    if (!row.gcNumber || !row.consignorId || !row.consigneeId || !row.godown) {
      setError('Missing mandatory fields (GC No, Consignor, Consignee, Godown)');
      return;
    }
    
    const hasGoods = row.goods.some(g => g.articles && parseInt(g.articles) > 0);
    if (!hasGoods) {
      setError('Missing Articles count in Goods Details');
      return;
    }

    try {
      setLoading(true);
      setError('');
      
      const finalGcNumber = `${row.companyMode === 'A' ? 'AP' : 'BELL'}-${row.gcNumber}`;
      
      const payload = {
        financialYear: '2026-2027',
        gcNumber: finalGcNumber,
        type: 'Regular',
        date: row.date,
        time: '12:00 PM',
        godown: row.godown,
        status: 'Created',
        consignorId: parseInt(row.consignorId),
        consigneeId: parseInt(row.consigneeId),
        invoiceDate: row.date,
        invoiceNumber: row.invoiceNumber,
        invoiceValue: parseFloat(row.invoiceValue) || 0,
        ewbNumber: row.ewbNumber || null,
        ewbRawData: row.ewbRawData || null,
        
        freightType: 'To Pay',
        freightFixed: 'Yes',
        freightRate: 0,
        freightTotal: 0,
        advancePaid: 0,
        balanceFreight: 0,
        
        goods: row.goods.map(g => ({
          articles: parseInt(g.articles) || null,
          units: g.units,
          hsn: g.hsn || '3604',
          description: g.description || 'Legacy Goods'
        }))
      };

      let res;
      if (editingId) {
        res = await api.put(`/gcs/${editingId}`, payload);
        setEditingId(null);
      } else {
        res = await api.post('/gcs', payload);
      }
      
      await fetchRecentRecords();
      
      setRow({
        ...initialRowState,
        date: row.date,
        companyMode: row.companyMode,
        godown: row.godown,
        gcNumber: ''
      });
      
      if (gcRef.current) gcRef.current.focus();

    } catch (err) {
      setError(err.error || err.message || 'Failed to save GC');
    } finally {
      setLoading(false);
    }
  };

  const handleReassignTransporter = async () => {
    if (!row.ewbRawData || !row.ewbNumber) return;
    const currentCompany = row.companyMode === 'A' ? 'AP' : 'BELL';
    const targetCompany = currentCompany === 'BELL' ? 'AP' : 'BELL';
    if (!window.confirm(`Are you sure you want to officially reassign this E-Way Bill from ${currentCompany} to ${targetCompany}?`)) return;
    
    try {
      setIsReassigning(true);
      await api.post('/ewaybill/reassign', {
        ewbNo: row.ewbNumber,
        currentCompany: currentCompany,
        targetCompany: targetCompany
      });
      setReassignSuccess(`Reassigned to ${targetCompany}!`);
      setTimeout(() => setReassignSuccess(''), 3000);
      
      setRow(prev => ({ ...prev, companyMode: targetCompany === 'BELL' ? 'B' : 'A' }));
    } catch (err) {
      setError(err.response?.data?.error || err.message || 'Failed to reassign transporter');
    } finally {
      setIsReassigning(false);
    }
  };

  const handleEditRecord = (rec) => {
    let prefix = 'A';
    let rawNumber = rec.gcNumber;
    if (rec.gcNumber.startsWith('AP-')) {
      prefix = 'A';
      rawNumber = rec.gcNumber.replace('AP-', '');
    } else if (rec.gcNumber.startsWith('BELL-')) {
      prefix = 'B';
      rawNumber = rec.gcNumber.replace('BELL-', '');
    }

    const raw = rec.raw || rec;
    
    setRow({
      date: rec.date || new Date().toISOString().split('T')[0],
      companyMode: prefix,
      gcNumber: rawNumber,
      ewbNumber: rec.ewbNumber || '',
      consignorId: raw.consignorId?.toString() || '',
      consigneeId: raw.consigneeId?.toString() || '',
      invoiceNumber: rec.invoiceNumber || '',
      invoiceValue: rec.invoiceValue?.toString() || '',
      goods: rec.goods?.length > 0 ? rec.goods.map(g => ({
        id: g.id || Date.now() + Math.random(),
        articles: g.articles?.toString() || g.articleCount?.toString() || '',
        unitCategory: Object.keys(unitHierarchy).find(cat => unitHierarchy[cat]?.some(u => u.label === g.units)) || 'Cases',
        units: g.units || '',
        hsn: g.hsn || '',
        description: g.description || '',
        weight: '', rate: '', amount: 0
      })) : [{ id: Date.now(), articles: '', unitCategory: 'Cases', units: 'Cases of Fireworks', hsn: '3604', description: 'Legacy Goods', weight: '', rate: '', amount: 0, isNew: true }],
      godown: raw.godown || 'Main Branch',
      ewbRawData: raw.ewbRawData || null
    });
    setEditingId(rec.id);
    
    window.scrollTo({ top: 0, behavior: 'smooth' });
    if (gcRef.current) gcRef.current.focus();
  };

  const handleKeyDown = (e, nextFieldId, isSubmit = false) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      if (isSubmit) {
        handleSaveRow();
      } else {
        const nextEl = document.getElementById(nextFieldId);
        if (nextEl) nextEl.focus();
      }
    }
  };

  const addRow = () => {
    const defaultItem = unitHierarchy['Cases'] ? unitHierarchy['Cases'][0] : null;
    setRow(prev => ({
      ...prev,
      goods: [...prev.goods, { 
        id: Date.now(), 
        articles: '', 
        unitCategory: 'Cases', 
        units: defaultItem ? defaultItem.label : 'Cases of Fireworks', 
        hsn: defaultItem?.hsn || '', 
        description: defaultItem?.goodsDesc || 'Legacy Goods', 
        weight: '', rate: '', amount: 0, isNew: true 
      }]
    }));
  };

  const removeRow = (id) => {
    if (row.goods.length > 1) {
      setRow(prev => ({
        ...prev,
        goods: prev.goods.filter(g => g.id !== id)
      }));
    }
  };

  const getUnitBadge = (unitValue) => {
    const match = allUnitOptions.find(o => o.label.toLowerCase() === (unitValue || '').toLowerCase());
    if (!match) return null;
    return (
      <span className={`${match.colorClass} px-1.5 py-0.5 rounded border text-[9px] font-black tracking-wider flex items-center shrink-0 shadow-sm ml-2`}>
        <span className="text-current opacity-80 mr-1">✓</span> {match.code}
      </span>
    );
  };

  return (
    <div className="space-y-4 max-w-[1400px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="flex items-center gap-3 bg-gradient-to-r from-stone-900 to-stone-800 p-4 rounded-xl shadow-lg text-white">
        <div className="bg-amber-500/20 text-amber-300 p-2 rounded-lg border border-amber-500/30">
          <Zap size={20} className="fill-amber-400" />
        </div>
        <div>
          <h2 className="text-xl font-black tracking-tight flex items-center gap-2">
            Legacy Rapid Entry Grid
          </h2>
          <p className="text-stone-400 text-xs font-medium mt-0.5">High-speed spreadsheet interface designed specifically for pending historical data</p>
        </div>
        {editingId && (
          <div className="ml-auto bg-amber-500 text-white px-3 py-1 rounded text-xs font-bold animate-pulse">
            Editing Mode Active
          </div>
        )}
      </div>

      {error && <div className="px-5 py-3 bg-rose-50/90 text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm animate-in fade-in">⚠️ {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm animate-in fade-in">✅ {success}</div>}

      <div className="bg-white rounded-xl shadow-[0_4px_20px_rgb(0,0,0,0.04)] border border-slate-200 overflow-hidden">
        <div className="bg-slate-50 border-b border-slate-200 px-4 py-2 flex items-center gap-2 text-xs font-bold text-slate-500 uppercase tracking-wider">
          <Database size={14} /> Active Entry Form
        </div>
        
        <div className={`p-4 bg-amber-50/20 ${isFetchingEwb ? 'opacity-50 pointer-events-none' : ''}`}>
          
          <div className="grid grid-cols-12 gap-3 mb-3">
            <div className="col-span-2">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">Date</label>
              <DenseInput type="date" id="cell-date" value={row.date} onChange={e => setRow({...row, date: e.target.value})} onKeyDown={(e) => handleKeyDown(e, 'cell-gc')} />
            </div>
            <div className="col-span-1">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">Prefix</label>
              <select className="w-full h-8 px-1 border border-slate-200 rounded text-xs font-bold text-slate-700 bg-white shadow-sm" value={row.companyMode} onChange={e => setRow({...row, companyMode: e.target.value})}>
                <option value="A">AP</option>
                <option value="B">BELL</option>
              </select>
            </div>
            <div className="col-span-2">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">GC No.</label>
              <DenseInput id="cell-gc" ref={gcRef} className="font-black text-indigo-700" value={row.gcNumber} onChange={e => setRow({...row, gcNumber: e.target.value})} onKeyDown={(e) => handleKeyDown(e, 'cell-ewb')} placeholder="1205" autoFocus />
            </div>
            <div className="col-span-4 flex flex-col">
              <div className="flex justify-between items-center mb-1">
                <label className="text-[10px] font-bold text-slate-500 uppercase flex items-center gap-1">
                  Smart EWB <span className="text-emerald-500 lowercase">(auto-fetches)</span>
                </label>
                {reassignSuccess ? (
                  <span className="text-emerald-600 text-[9px] font-bold animate-in fade-in">✅ {reassignSuccess}</span>
                ) : row.ewbRawData ? (
                  <button 
                    type="button"
                    tabIndex="-1"
                    onClick={handleReassignTransporter}
                    disabled={isReassigning}
                    className="bg-amber-500 hover:bg-amber-400 text-white text-[9px] font-bold px-1.5 py-0.5 rounded shadow-sm transition-all"
                  >
                    {isReassigning ? '...' : `Reassign to ${row.companyMode === 'A' ? 'BELL' : 'AP'}`}
                  </button>
                ) : null}
              </div>
              <DenseInput id="cell-ewb" ref={ewbRef} className="font-mono text-xs border-amber-300 bg-amber-50" value={row.ewbNumber} onChange={e => setRow({...row, ewbNumber: e.target.value})} onBlur={handleEwbBlur} onKeyDown={(e) => handleKeyDown(e, 'rapid-consignor')} placeholder="12 digits..." />
            </div>
          </div>

          <div className="grid grid-cols-12 gap-3 mb-3 bg-white/50 p-2 rounded-lg border border-slate-100">
            <div className="col-span-3">
              <div className="flex items-center gap-2 mb-1">
                <label className="text-[10px] font-bold text-slate-500 uppercase">Consignor</label>
                {row.isNewConsignor && <span className="bg-emerald-500 text-white text-[8px] px-1.5 py-0.5 rounded shadow-sm animate-pulse">NEWLY SAVED</span>}
              </div>
              <AsyncSearchableSelect 
                id="rapid-consignor"
                fetchOptions={fetchConsignorsAsync}
                value={row.consignorId?.toString()}
                initialOption={row.consignorData ? { value: row.consignorId.toString(), label: row.consignorData.name, raw: row.consignorData } : null}
                onChange={(id, opt) => setRow(prev => ({ ...prev, consignorId: id, consignorData: opt?.raw }))}
                placeholder="Consignor..."
                className={denseSearchableSelectClass}
              />
            </div>
            <div className="col-span-2">
              <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">GSTIN (Auto)</label>
              <DenseInput readOnly value={row.consignorData?.gstin?.toUpperCase() || ''} className="text-[11px] font-mono !bg-slate-50 !text-slate-500 uppercase" tabIndex="-1" />
            </div>
            <div className="col-span-1">
              <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">City</label>
              <DenseInput readOnly value={row.consignorData?.city || ''} className="text-[11px] !bg-slate-50 !text-slate-500" tabIndex="-1" />
            </div>

            <div className="col-span-3">
              <div className="flex items-center gap-2 mb-1">
                <label className="text-[10px] font-bold text-slate-500 uppercase">Consignee</label>
                {row.isNewConsignee && <span className="bg-emerald-500 text-white text-[8px] px-1.5 py-0.5 rounded shadow-sm animate-pulse">NEWLY SAVED</span>}
              </div>
              <AsyncSearchableSelect 
                id="rapid-consignee"
                fetchOptions={fetchConsigneesAsync}
                value={row.consigneeId?.toString()}
                initialOption={row.consigneeData ? { value: row.consigneeId.toString(), label: row.consigneeData.name, raw: row.consigneeData } : null}
                onChange={(id, opt) => setRow(prev => ({ ...prev, consigneeId: id, consigneeData: opt?.raw }))}
                placeholder="Consignee..."
                className={denseSearchableSelectClass}
              />
            </div>
            <div className="col-span-2">
              <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">GSTIN (Auto)</label>
              <DenseInput readOnly value={row.consigneeData?.gstin?.toUpperCase() || ''} className="text-[11px] font-mono !bg-slate-50 !text-slate-500 uppercase" tabIndex="-1" />
            </div>
            <div className="col-span-1">
              <label className="block text-[10px] font-bold text-slate-400 uppercase mb-1">City</label>
              <DenseInput readOnly value={row.consigneeData?.city || ''} className="text-[11px] !bg-slate-50 !text-slate-500" tabIndex="-1" />
            </div>
          </div>

          {/* LINE 3: Godown & Invoice Details */}
          <div className="grid grid-cols-12 gap-3 mb-4">
            <div className="col-span-3">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">Invoice No.</label>
              <DenseInput id="cell-invno" value={row.invoiceNumber} onChange={e => setRow({...row, invoiceNumber: e.target.value})} onKeyDown={(e) => handleKeyDown(e, 'cell-invval')} />
            </div>
            <div className="col-span-3">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">Inv Value</label>
              <DenseInput id="cell-invval" type="number" value={row.invoiceValue} onChange={e => setRow({...row, invoiceValue: e.target.value})} onKeyDown={(e) => handleKeyDown(e, 'cell-godown')} />
            </div>
            <div className="col-span-6">
              <label className="block text-[10px] font-bold text-slate-500 uppercase mb-1">Godown</label>
              <select id="cell-godown" className="w-full h-8 px-1 border border-slate-200 rounded text-xs font-semibold bg-white shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" value={row.godown} onChange={e => setRow({...row, godown: e.target.value})} onKeyDown={(e) => handleKeyDown(e, 'cell-arts-0')}>
                {godowns.map(g => <option key={g.id} value={g.name}>{g.name}</option>)}
              </select>
            </div>
          </div>

          {/* EWB PREVIEW HINT (Shows what government EWB says, without forcing rows) */}
          {row.ewbRawData?.itemList && row.ewbRawData.itemList.length > 0 && (
            <div className="mb-4 bg-indigo-50/80 border border-indigo-200/60 rounded-xl p-3 shadow-sm mx-4">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 mb-2">
                <div className="flex items-center gap-2">
                  <span className="bg-indigo-600 text-white text-[9px] font-black tracking-wider px-2 py-0.5 rounded uppercase">EWB Raw Data Preserved</span>
                  <span className="text-xs font-bold text-indigo-900">Enter total physical packages below.</span>
                </div>
                {row.ewbRawData.status === 'DIS' && (
                  <span className="bg-rose-100 text-rose-700 text-[10px] font-black px-2 py-0.5 rounded border border-rose-200 uppercase flex items-center gap-1">
                    ⚠️ EXPIRED / DISCARDED (Part-A Lapsed)
                  </span>
                )}
                {row.ewbRawData.status === 'CNL' && (
                  <span className="bg-rose-100 text-rose-700 text-[10px] font-black px-2 py-0.5 rounded border border-rose-200 uppercase flex items-center gap-1">
                    ⚠️ CANCELED E-WAY BILL
                  </span>
                )}
                {row.ewbRawData.status === 'ACT' && (
                  <span className="bg-emerald-100 text-emerald-700 text-[10px] font-black px-2 py-0.5 rounded border border-emerald-200 uppercase flex items-center gap-1">
                    ✅ ACTIVE E-WAY BILL
                  </span>
                )}
              </div>
              <div className="space-y-1.5 max-h-24 overflow-y-auto">
                {row.ewbRawData.itemList.map((item, idx) => (
                  <div key={idx} className="flex flex-wrap gap-2 text-xs font-medium text-indigo-800/80 items-center">
                    <span className="font-bold text-indigo-900">• EWB Item {idx + 1}:</span> 
                    <span className="bg-white/60 px-1.5 rounded border border-indigo-100">{item.quantity} {item.qtyUnit}</span>
                    <span>{item.productName}</span>
                    <span className="text-indigo-600/70 text-[10px] ml-auto">(HSN: {item.hsnCode})</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* GOODS ENTRY GRID */}
          <div className="border border-slate-200 rounded-lg bg-white overflow-hidden shadow-sm">
            <div className={`grid grid-cols-[60px_100px_180px_100px_1fr_80px] gap-2 px-2 py-1 bg-slate-100/50 text-center border-b border-slate-200/50`}>
              <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Qty</div>
              <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit</div>
              <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit Desc</div>
              <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">HSN</div>
              <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Description of Goods</div>
              <div></div>
            </div>
            
            <div className="p-1 space-y-1">
              {row.goods.map((item, index) => (
                <div key={item.id} className={`grid grid-cols-[60px_100px_180px_100px_1fr_80px] gap-2 p-1 rounded-lg focus-within:bg-indigo-50/50 focus-within:ring-1 focus-within:ring-indigo-500 transition-all border border-transparent`}>
                  <DenseInput id={`cell-arts-${index}`} type="number" autoFocus={item.isNew} value={item.articles} onChange={(e) => setRow(prev => ({...prev, goods: prev.goods.map(g => g.id === item.id ? {...g, articles: e.target.value} : g)}))} />
                  
                  <div className="flex flex-col group">
                    <select className="w-full h-8 px-1 border border-slate-200 rounded bg-white/50 text-xs font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all appearance-none cursor-pointer"
                      value={item.unitCategory} 
                      onChange={(e) => {
                        const newCat = e.target.value;
                        const defaultItem = unitHierarchy[newCat] ? unitHierarchy[newCat][0] : null;
                        setRow(prev => ({...prev, goods: prev.goods.map(g => g.id === item.id ? {
                          ...g, unitCategory: newCat, units: defaultItem ? defaultItem.label : '',
                          hsn: (!g.hsn || g.hsn.trim() === '') ? (defaultItem?.hsn || '') : g.hsn,
                          description: (!g.description || g.description.trim() === '') ? (defaultItem?.goodsDesc || '') : g.description
                        } : g)}));
                      }}
                    >
                      {Object.keys(unitHierarchy).map(k => <option key={k} value={k}>{k}</option>)}
                    </select>
                  </div>

                  <div className="flex flex-col group">
                    <select className="w-full h-8 px-1 border border-slate-200 rounded bg-white/50 text-xs font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-all appearance-none cursor-pointer"
                      value={item.units} 
                      onChange={(e) => {
                        const newUnitDesc = e.target.value;
                        const match = allUnitOptions.find(o => o.label === newUnitDesc);
                        setRow(prev => ({...prev, goods: prev.goods.map(g => g.id === item.id ? {
                          ...g, units: newUnitDesc,
                          hsn: (!g.hsn || g.hsn.trim() === '') ? (match?.hsn || '') : g.hsn,
                          description: (!g.description || g.description.trim() === '') ? (match?.goodsDesc || '') : g.description
                        } : g)}));
                      }}
                    >
                      {(unitHierarchy[item.unitCategory || 'Cases'] || []).map(u => <option key={u.label} value={u.label}>{u.label}</option>)}
                    </select>
                  </div>

                  <DenseInput value={item.hsn} onChange={(e) => setRow(prev => ({...prev, goods: prev.goods.map(g => g.id === item.id ? {...g, hsn: e.target.value} : g)}))} />
                  
                  <div className="flex items-center gap-1 w-full">
                    <DenseInput className="flex-1" value={item.description} onChange={(e) => setRow(prev => ({...prev, goods: prev.goods.map(g => g.id === item.id ? {...g, description: e.target.value} : g)}))} 
                      onKeyDown={(e) => {
                        if ((e.key === 'Enter' || e.key === 'Tab') && index === row.goods.length - 1) {
                          if (item.description.trim() !== '' || item.articles !== '') {
                            e.preventDefault();
                            addRow();
                          } else if (e.key === 'Enter') {
                            e.preventDefault();
                            handleSaveRow();
                          }
                        }
                      }}/>
                    {getUnitBadge(item.units)}
                  </div>
                  
                  <div className="flex gap-1 justify-center items-center">
                    <button type="button" tabIndex="-1" onClick={() => removeRow(item.id)} disabled={row.goods.length === 1} className="h-8 w-8 flex items-center justify-center bg-white hover:bg-rose-50 text-slate-400 disabled:opacity-50 border border-slate-200 rounded shadow-sm"><Trash2 size={14} /></button>
                  </div>
                </div>
              ))}
            </div>
          </div>
          
          <div className="mt-4 flex justify-end">
            <button onClick={handleSaveRow} disabled={loading || isFetchingEwb} className="w-48 h-10 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-sm font-bold flex items-center justify-center shadow-md disabled:opacity-50">
              {loading ? 'Saving...' : <span className="flex items-center gap-2">Save Entry <ArrowRight size={16} /></span>}
            </button>
          </div>

          
        </div>
      </div>

      {savedRecords.length > 0 && (
        <div className="mt-8">
          <h3 className="font-bold text-sm text-slate-700 uppercase tracking-tight mb-3">Saved Session Records</h3>
          <div className="bg-white/80 rounded-xl border border-slate-200 shadow-sm overflow-hidden">
            <table className="w-full text-left">
              <thead>
                <tr className="bg-slate-50 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-100">
                  <th className="p-3">GC No</th>
                  <th className="p-3">Date</th>
                  <th className="p-3">Consignor</th>
                  <th className="p-3">Consignee</th>
                  <th className="p-3">Godown</th>
                  <th className="p-3">EWB</th>
                  <th className="p-3">Invoice</th>
                  <th className="p-3 text-right">Articles</th>
                  <th className="p-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 text-sm font-semibold text-slate-700">
                {savedRecords.map((rec) => (
                  <tr key={rec.id} className="animate-in slide-in-from-top-2">
                    <td className="p-3 text-indigo-700 font-bold">{rec.gcNumber}</td>
                    <td className="p-3">{rec.date}</td>
                    <td className="p-3 truncate max-w-[120px]" title={rec.consignorName}>{rec.consignorName}</td>
                    <td className="p-3 truncate max-w-[120px]" title={rec.consigneeName}>{rec.consigneeName}</td>
                    <td className="p-3 text-[11px] font-bold text-slate-500">{rec.godown}</td>
                    <td className="p-3 font-mono text-xs">{rec.ewbNumber || '-'}</td>
                    <td className="p-3">{rec.invoiceNumber || '-'} <span className="text-slate-400 font-normal">({rec.invoiceValue})</span></td>
                    <td className="p-3 text-right text-emerald-600 font-bold">{rec.goods?.[0]?.articles || '-'}</td>
                    <td className="p-3 text-right">
                      <button 
                        onClick={() => handleEditRecord(rec)}
                        className="text-xs font-bold text-indigo-600 hover:text-indigo-800 bg-indigo-50 hover:bg-indigo-100 px-3 py-1 rounded transition-colors"
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

    </div>
  );
}

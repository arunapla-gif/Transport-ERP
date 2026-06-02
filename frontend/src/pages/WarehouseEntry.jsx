import React, { useState, useEffect, useRef } from 'react';
import { api } from '../api';
import ScannerModal from '../components/ui/ScannerModal';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import { Building2, Camera, PackageCheck, CheckCircle2, Save, Printer, Edit3, Smartphone, X } from 'lucide-react';

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/90 backdrop-blur-2xl border border-white/60 rounded-xl p-4 md:p-5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-12 md:h-10 px-3 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-semibold md:font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-sm" 
      {...props} 
    />
  </div>
);

export default function WarehouseEntry() {
  const [ewayBillNo, setEwayBillNo] = useState('');
  const [isFetchingEwb, setIsFetchingEwb] = useState(false);
  const [isScannerOpen, setIsScannerOpen] = useState(false);
  
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);
  const [godowns, setGodowns] = useState([]);
  const [consignors, setConsignors] = useState([]);
  const [consignees, setConsignees] = useState([]);
  
  const [recentEntry, setRecentEntry] = useState(null);
  const [editingId, setEditingId] = useState(null);

  // Form Fields
  const [consignorName, setConsignorName] = useState('');
  const [consigneeName, setConsigneeName] = useState('');
  const [consigneeCity, setConsigneeCity] = useState('');
  const [articles, setArticles] = useState('');
  const [godownNo, setGodownNo] = useState('');
  const [remarks, setRemarks] = useState('');

  // Remote Pairing
  const [pairingCode, setPairingCode] = useState(null);
  const [isPairing, setIsPairing] = useState(false);
  const pollInterval = useRef(null);

  useEffect(() => {
    // Fetch masters
    api.get('/godowns').then(res => setGodowns(res || [])).catch(console.error);
    api.get('/consignors').then(res => setConsignors(res || [])).catch(console.error);
    api.get('/consignees').then(res => setConsignees(res || [])).catch(console.error);
    
    // Fetch last entry
    fetchLastEntry();
  }, []);

  const fetchLastEntry = async () => {
    try {
      const data = await api.get('/warehouse-inward?limit=1');
      if (data && data.length > 0) {
        setRecentEntry(data[0]);
      }
    } catch (err) {
      console.error('Failed to fetch recent entry', err);
    }
  };

  const handleEwayBillSearch = async () => {
    if (!ewayBillNo.trim()) return;
    try {
      setIsFetchingEwb(true);
      setError('');
      setSuccess('');
      
      const cleanEwbNo = ewayBillNo.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}`);
      
      // Auto-fill fields based on fetched E-Way Bill
      if (ewbData.fromTrdName) setConsignorName(ewbData.fromTrdName);
      if (ewbData.toTrdName) setConsigneeName(ewbData.toTrdName);
      if (ewbData.toPlace) setConsigneeCity(ewbData.toPlace);
      
      if (ewbData.itemList && ewbData.itemList.length > 0) {
        const totalQty = ewbData.itemList.reduce((sum, item) => sum + (parseInt(item.quantity) || 0), 0);
        setArticles(totalQty.toString());
      }
      
      setSuccess('E-Way Bill details fetched and filled successfully.');
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to fetch E-Way Bill');
    } finally {
      setIsFetchingEwb(false);
    }
  };

  const handleEwayBillSearchDirect = async (scannedCode) => {
    if (!scannedCode.trim()) return;
    try {
      setIsFetchingEwb(true);
      setError('');
      setSuccess('');
      
      const cleanEwbNo = scannedCode.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}`);
      
      if (ewbData.fromTrdName) setConsignorName(ewbData.fromTrdName);
      if (ewbData.toTrdName) setConsigneeName(ewbData.toTrdName);
      if (ewbData.toPlace) setConsigneeCity(ewbData.toPlace);
      
      if (ewbData.itemList && ewbData.itemList.length > 0) {
        const totalQty = ewbData.itemList.reduce((sum, item) => sum + (parseInt(item.quantity) || 0), 0);
        setArticles(totalQty.toString());
      }
      
      setSuccess('E-Way Bill details fetched from Phone scanner!');
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to fetch E-Way Bill from Phone scan');
    } finally {
      setIsFetchingEwb(false);
    }
  };

  const startPairing = () => {
    const code = Math.floor(1000 + Math.random() * 9000).toString();
    setPairingCode(code);
    setIsPairing(true);
    
    if (pollInterval.current) clearInterval(pollInterval.current);
    pollInterval.current = setInterval(async () => {
      try {
        const res = await api.get(`/scanner/poll?code=${code}`);
        if (res && res.status === 'success' && res.data) {
          setEwayBillNo(res.data);
          clearInterval(pollInterval.current);
          setIsPairing(false);
          // Auto fetch
          handleEwayBillSearchDirect(res.data);
        }
      } catch (e) {
        console.error(e);
      }
    }, 2000);
  };

  const stopPairing = () => {
    setIsPairing(false);
    if (pollInterval.current) clearInterval(pollInterval.current);
  };

  const handleInward = async () => {
    if (!consignorName || !consigneeName || !articles || !godownNo) {
      setError('Please fill all mandatory fields (Consignor, Consignee, Articles, Godown No)');
      return;
    }

    try {
      setLoading(true);
      setError('');
      
      const payload = {
        ewayBillNo,
        consignorName,
        consigneeName,
        consigneeCity,
        articles: parseInt(articles) || 0,
        godownNo,
        remarks
      };

      let savedEntry;
      if (editingId) {
        savedEntry = await api.put(`/warehouse-inward/${editingId}`, payload);
        setSuccess('Entry updated successfully!');
        setEditingId(null);
      } else {
        savedEntry = await api.post('/warehouse-inward', payload);
        setSuccess('Goods successfully inwarded to Warehouse!');
      }
      
      setRecentEntry(savedEntry);
      
      // Reset Form
      setTimeout(() => {
        setSuccess('');
        setEwayBillNo('');
        setConsignorName('');
        setConsigneeName('');
        setConsigneeCity('');
        setArticles('');
        setGodownNo('');
        setRemarks('');
      }, 2000);
    } catch (err) {
      setError(err.message || 'Failed to inward goods');
    } finally {
      setLoading(false);
    }
  };

  const handleEditRecent = () => {
    if (!recentEntry) return;
    setEditingId(recentEntry.id);
    setEwayBillNo(recentEntry.ewayBillNo || '');
    setConsignorName(recentEntry.consignorName || '');
    setConsigneeName(recentEntry.consigneeName || '');
    setConsigneeCity(recentEntry.consigneeCity || '');
    setArticles(recentEntry.articles?.toString() || '');
    setGodownNo(recentEntry.godownNo || '');
    setRemarks(recentEntry.remarks || '');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handlePrintRecent = () => {
    window.print();
  };

  return (
    <div className="space-y-4 max-w-4xl mx-auto pt-2 md:pt-4 pb-20 md:pb-10 px-2 md:px-0 print:p-0 print:m-0 print:max-w-none" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      <div className="flex items-center gap-3 mb-4 md:mb-6 px-1 md:px-2 print:hidden">
        <div className="bg-emerald-100 text-emerald-600 p-2.5 rounded-xl shadow-inner border border-emerald-200/50">
          <Building2 size={24} />
        </div>
        <div>
          <h2 className="text-xl md:text-2xl font-black text-slate-800 tracking-tight leading-none">Daily Inward Entry</h2>
          <p className="text-xs font-bold text-slate-500 mt-1">Scan E-Way Bill or Enter manually</p>
        </div>
      </div>

      {error && <div className="px-5 py-3 bg-rose-50/90 text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm flex items-center gap-2 print:hidden"><span className="text-xl leading-none">⚠️</span> {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm flex items-center gap-2 print:hidden"><CheckCircle2 size={18} className="text-emerald-500" /> {success}</div>}

      {/* EWB Scanner / Fetcher */}
      <GlassCard className="flex flex-col sm:flex-row gap-3 md:gap-4 items-end bg-gradient-to-br from-indigo-50/50 to-white print:hidden">
        <div className="flex-1 w-full">
          <label className="text-[11px] md:text-[10px] font-bold text-indigo-900/60 uppercase tracking-wider mb-1.5 block">Scan or Enter E-Way Bill No.</label>
          <div className="relative group">
            <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none">
              <PackageCheck size={20} className="text-indigo-400 group-focus-within:text-indigo-600 transition-colors" />
            </div>
            <input 
              className="w-full h-14 md:h-12 pl-11 pr-4 border border-indigo-200 rounded-xl bg-white text-lg md:text-lg font-black text-indigo-900 placeholder-indigo-300 focus:outline-none focus:border-indigo-500 focus:ring-4 focus:ring-indigo-500/20 transition-all shadow-sm"
              placeholder="e.g. 1234 5678 9012"
              value={ewayBillNo} 
              onChange={e => setEwayBillNo(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); handleEwayBillSearch(); } }}
              type="tel"
            />
          </div>
        </div>

        <div className="flex gap-2 w-full sm:w-auto">
          <button 
            type="button"
            onClick={handleEwayBillSearch} 
            disabled={isFetchingEwb} 
            className="flex-1 sm:flex-none h-14 md:h-12 px-6 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl font-black text-[15px] md:text-sm shadow-[0_4px_12px_rgba(79,70,229,0.3)] hover:shadow-[0_6px_16px_rgba(79,70,229,0.4)] transition-all active:scale-95 flex items-center justify-center gap-2"
          >
            {isFetchingEwb ? 'Fetching...' : 'Fetch EWB'}
          </button>
          
          <button 
            type="button"
            onClick={startPairing}
            title="Use Phone as Scanner"
            className="h-14 w-14 md:h-12 md:w-12 flex-shrink-0 flex items-center justify-center bg-indigo-100 hover:bg-indigo-200 text-indigo-600 rounded-xl transition-all active:scale-95"
          >
            <Smartphone size={24} className="md:w-5 md:h-5" />
          </button>
          
          <button 
            type="button"
            onClick={() => setIsScannerOpen(true)}
            title="Scan QR or E-Way Bill"
            className="h-14 w-14 md:h-12 md:w-12 flex-shrink-0 flex items-center justify-center bg-emerald-500 hover:bg-emerald-400 text-white rounded-xl shadow-[0_4px_12px_rgba(16,185,129,0.3)] hover:shadow-[0_6px_16px_rgba(16,185,129,0.4)] transition-all active:scale-95"
          >
            <Camera size={24} className="md:w-5 md:h-5" />
          </button>
        </div>
      </GlassCard>

      {/* Inward Form Fields */}
      <GlassCard className="animate-in fade-in slide-in-from-bottom-4 duration-500 print:hidden">
        <h3 className="font-black text-slate-800 uppercase text-sm tracking-wider mb-4 md:mb-5 border-b border-slate-100 pb-2">
          {editingId ? 'Edit Entry Details' : 'Entry Details'}
        </h3>
        
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 md:gap-5">
          <SearchableSelect 
            label="Consignor Name *" 
            options={consignors.map(c => ({ value: c.name, label: c.name }))}
            value={consignorName} 
            onChange={val => setConsignorName(val)} 
            placeholder="Search Consignor..."
            className="[&>div:nth-of-type(1)]:h-12 [&>div:nth-of-type(1)]:md:h-10 [&>div:nth-of-type(1)]:bg-white/70 [&>div:nth-of-type(1)]:md:bg-white/50 [&>label]:text-[11px] md:[&>label]:text-[10px] [&_input]:text-base md:[&_input]:text-sm [&>div:nth-of-type(1)]:rounded-xl [&>div:nth-of-type(1)]:md:rounded-lg"
          />
          <SearchableSelect 
            label="Consignee Name *" 
            options={consignees.map(c => ({ value: c.name, label: c.name }))}
            value={consigneeName} 
            onChange={val => {
              setConsigneeName(val);
              const found = consignees.find(c => c.name === val);
              if (found && found.city) setConsigneeCity(found.city);
            }} 
            placeholder="Search Consignee..."
            className="[&>div:nth-of-type(1)]:h-12 [&>div:nth-of-type(1)]:md:h-10 [&>div:nth-of-type(1)]:bg-white/70 [&>div:nth-of-type(1)]:md:bg-white/50 [&>label]:text-[11px] md:[&>label]:text-[10px] [&_input]:text-base md:[&_input]:text-sm [&>div:nth-of-type(1)]:rounded-xl [&>div:nth-of-type(1)]:md:rounded-lg"
          />
          <DenseInput 
            label="Consignee City" 
            placeholder="Enter City" 
            value={consigneeCity} 
            onChange={e => setConsigneeCity(e.target.value)} 
          />
          <DenseInput 
            label="Articles (Qty) *" 
            type="number" 
            inputMode="numeric"
            placeholder="0" 
            value={articles} 
            onChange={e => setArticles(e.target.value)} 
          />
          
          <div className="flex flex-col group">
            <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">Godown No *</label>
            <select 
              className="w-full h-12 md:h-10 px-3 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-semibold md:font-medium text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-sm appearance-none"
              value={godownNo}
              onChange={e => setGodownNo(e.target.value)}
            >
              <option value="">Select Godown</option>
              {godowns.map(g => (
                <option key={g.id} value={g.name}>{g.name}</option>
              ))}
            </select>
          </div>
          
          <DenseInput 
            label="Remarks" 
            placeholder="Optional remarks..." 
            value={remarks} 
            onChange={e => setRemarks(e.target.value)} 
          />
        </div>
        
        <div className="mt-8 flex justify-end">
          {editingId && (
            <button 
              type="button"
              onClick={() => {
                setEditingId(null);
                setEwayBillNo(''); setConsignorName(''); setConsigneeName(''); setConsigneeCity(''); setArticles(''); setGodownNo(''); setRemarks('');
              }}
              className="w-full sm:w-auto h-14 md:h-12 px-6 mr-3 bg-slate-200 hover:bg-slate-300 text-slate-700 rounded-xl font-black text-lg md:text-base transition-all flex items-center justify-center gap-2"
            >
              Cancel Edit
            </button>
          )}
          <button 
            onClick={handleInward}
            disabled={loading}
            className={`w-full sm:w-auto h-14 md:h-12 px-10 text-white rounded-xl font-black text-lg md:text-base shadow-lg transition-all active:scale-95 flex items-center justify-center gap-2 ${editingId ? 'bg-blue-600 hover:bg-blue-500 shadow-blue-500/30' : 'bg-emerald-600 hover:bg-emerald-500 shadow-emerald-500/30'}`}
          >
            <Save size={20} /> {loading ? 'Saving...' : (editingId ? 'Update Entry' : 'Confirm Entry')}
          </button>
        </div>
      </GlassCard>

      {/* Last Saved Entry Display */}
      {recentEntry && (
        <GlassCard className="mt-2 border-l-4 border-l-indigo-500 animate-in fade-in slide-in-from-bottom-4 duration-500 print:hidden">
          <div className="flex justify-between items-start mb-3">
            <div>
              <h3 className="font-black text-slate-800 text-sm uppercase tracking-wider">
                Last Saved Entry <span className="text-indigo-600 ml-1">#{recentEntry.receiptNo}</span>
              </h3>
              <p className="text-[10px] font-bold text-slate-500">
                {new Date(recentEntry.createdAt).toLocaleString('en-IN')}
              </p>
            </div>
            <div className="flex gap-2">
              <button onClick={handleEditRecent} className="p-2 text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors" title="Edit">
                <Edit3 size={16} />
              </button>
              <button onClick={handlePrintRecent} className="p-2 text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-lg transition-colors" title="Print Slip">
                <Printer size={16} />
              </button>
            </div>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase">Consignor</p>
              <p className="font-bold text-slate-800 truncate">{recentEntry.consignorName}</p>
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase">Consignee</p>
              <p className="font-bold text-slate-800 truncate">{recentEntry.consigneeName}</p>
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase">Articles</p>
              <p className="font-black text-indigo-600">{recentEntry.articles}</p>
            </div>
            <div>
              <p className="text-[10px] font-bold text-slate-400 uppercase">Godown</p>
              <p className="font-bold text-slate-800">{recentEntry.godownNo}</p>
            </div>
          </div>
        </GlassCard>
      )}

      {/* Print Layout for Single Slip (3.5in x 5in) */}
      <div className="hidden print:block font-sans text-black" style={{ width: '3.5in', height: '4.8in', margin: '0 auto', position: 'relative' }}>
        <style>
          {`
            @media print {
              @page { size: 3.5in 5in; margin: 3mm; }
              body { -webkit-print-color-adjust: exact; margin: 0; padding: 0; }
            }
          `}
        </style>
        
        <div className="text-center border-b-[1.5px] border-black pb-1 mb-2">
          <h1 className="text-[14px] font-black uppercase tracking-wider leading-none">Warehouse Inward</h1>
        </div>
        
        {recentEntry && (
          <div className="flex flex-col gap-1.5 text-[11px]">
            <div className="flex justify-between font-bold border-b border-dashed border-gray-400 pb-1 mb-1">
              <span>Rec No: <span className="text-[13px] ml-1">#{recentEntry.receiptNo}</span></span>
              <span>{new Date(recentEntry.createdAt).toLocaleDateString('en-IN')}</span>
            </div>
            
            <div>
              <span className="text-[9px] font-bold text-gray-600 uppercase">From</span><br/>
              <span className="font-black text-[13px] leading-tight block">{recentEntry.consignorName}</span>
            </div>
            
            <div>
              <span className="text-[9px] font-bold text-gray-600 uppercase">To</span><br/>
              <span className="font-black text-[13px] leading-tight inline-block">{recentEntry.consigneeName}</span>
              {recentEntry.consigneeCity && <span className="ml-1 text-[11px] font-bold">({recentEntry.consigneeCity})</span>}
            </div>
            
            <div className="mt-1 border-t-[1.5px] border-b-[1.5px] border-black py-1.5 text-center bg-gray-50">
              <span className="text-[10px] font-bold uppercase tracking-widest">Total Articles</span><br/>
              <span className="font-black text-[24px] leading-none block mt-0.5">{recentEntry.articles}</span>
            </div>
            
            {recentEntry.ewayBillNo && (
              <div className="mt-1">
                <span className="text-[9px] font-bold text-gray-600 uppercase">E-Way Bill</span><br/>
                <span className="font-bold text-[12px]">{recentEntry.ewayBillNo}</span>
              </div>
            )}
            
            {recentEntry.remarks && (
              <div>
                <span className="text-[9px] font-bold text-gray-600 uppercase">Remarks</span><br/>
                <span className="font-bold text-[11px] leading-tight block">{recentEntry.remarks}</span>
              </div>
            )}
          </div>
        )}
        
        <div className="absolute bottom-2 left-0 right-0 flex justify-between px-2">
          <span className="text-[9px] font-bold uppercase tracking-wide border-t border-black w-20 text-center pt-1">Clerk</span>
          <span className="text-[9px] font-bold uppercase tracking-wide border-t border-black w-20 text-center pt-1">Driver</span>
        </div>
      </div>

      <ScannerModal 
        isOpen={isScannerOpen} 
        onClose={() => setIsScannerOpen(false)} 
        onScan={(scannedText) => {
          setEwayBillNo(scannedText);
          setIsScannerOpen(false);
          handleEwayBillSearchDirect(scannedText);
        }} 
      />

      {/* Pairing Modal */}
      {isPairing && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-3xl shadow-2xl max-w-sm w-full p-8 text-center relative overflow-hidden animate-in zoom-in-95 duration-300">
            <button 
              onClick={stopPairing}
              className="absolute top-4 right-4 p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-full transition-colors"
            >
              <X size={20} />
            </button>
            
            <div className="w-16 h-16 bg-indigo-100 text-indigo-600 rounded-2xl flex items-center justify-center mx-auto mb-6 shadow-inner animate-pulse">
              <Smartphone size={32} />
            </div>
            
            <h2 className="text-2xl font-black text-slate-800 mb-2">Connect Phone</h2>
            <p className="text-sm font-bold text-slate-500 mb-8">
              Open <span className="text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded">/remote-scanner</span> on your phone and enter this code:
            </p>
            
            <div className="text-6xl font-black text-indigo-600 tracking-widest bg-slate-50 border-2 border-dashed border-indigo-200 py-6 rounded-2xl">
              {pairingCode}
            </div>
            
            <p className="text-xs font-bold text-slate-400 mt-6 animate-pulse">
              Waiting for scan...
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

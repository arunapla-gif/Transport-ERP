import React, { useState, useEffect, useRef, useMemo } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import ScannerModal from '../components/ui/ScannerModal';
import { Button } from '../components/ui/Button';
import { Building2, Camera, PackageCheck, Smartphone, X } from 'lucide-react';
import WarehouseInwardForm from '../components/entry/WarehouseInwardForm';
import WarehouseRecentCard from '../components/entry/WarehouseRecentCard';

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
  
  const [loading, setLoading] = useState(false);
  const [godowns, setGodowns] = useState([]);
  const [consignors, setConsignors] = useState([]);
  const [consignees, setConsignees] = useState([]);
  
  const [recentEntry, setRecentEntry] = useState(null);
  const [editingId, setEditingId] = useState(null);

  // Memoize large dropdown options to prevent mobile lag on every keystroke
  const consignorOptions = useMemo(() => consignors.map(c => ({ value: c.name, label: c.name })), [consignors]);
  const consigneeOptions = useMemo(() => consignees.map(c => ({ value: c.name, label: c.name })), [consignees]);

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

  const processEwbData = async (ewbData) => {
    // Helper to get refined city via Pincode
    const getRefinedCity = async (pincode, fallbackCity) => {
      if (!pincode) return fallbackCity ? fallbackCity.trim().toUpperCase() : '';
      try {
        const postOffices = await api.verifyPincode(pincode);
        if (postOffices && postOffices.length > 0 && postOffices[0].District) {
          return postOffices[0].District.toUpperCase();
        }
      } catch (err) {
        console.warn("Pincode verification failed, using fallback");
      }
      return fallbackCity ? fallbackCity.trim().toUpperCase() : '';
    };

    if (ewbData.fromTrdName) {
      const cnorName = ewbData.fromTrdName.replace(/\s+/g, ' ').trim().toUpperCase();
      setConsignorName(cnorName);
      
      const existingCnor = consignors.find(c => c.name.trim().toLowerCase() === cnorName.toLowerCase());
      if (!existingCnor) {
        try {
          const refinedCity = await getRefinedCity(ewbData.fromPincode, ewbData.fromPlace || ewbData.fromAddr2);
          const newCnor = await api.post('/consignors', {
            name: cnorName,
            gstin: ewbData.fromGstin || '',
            address: [ewbData.fromAddr1, ewbData.fromAddr2].filter(Boolean).join(', '),
            city: refinedCity,
            state: ewbData.fromStateCode ? ewbData.fromStateCode.toString() : '',
            pincode: ewbData.fromPincode ? ewbData.fromPincode.toString() : ''
          });
          setConsignors(prev => [...prev, newCnor]);
        } catch(e) { console.error(e); }
      }
    }

    if (ewbData.toTrdName) {
      const cneeName = ewbData.toTrdName.replace(/\s+/g, ' ').trim().toUpperCase();
      setConsigneeName(cneeName);
      
      const existingCnee = consignees.find(c => c.name.trim().toLowerCase() === cneeName.toLowerCase());
      if (existingCnee) {
        // Party exists! Use the clean City from our Master DB.
        if (existingCnee.city) setConsigneeCity(existingCnee.city.toUpperCase());
      } else {
        // Brand new Party! Intercept and Refine before saving to Master DB.
        try {
          const refinedCity = await getRefinedCity(ewbData.toPincode, ewbData.toPlace || ewbData.toAddr2);
          const newCnee = await api.post('/consignees', {
            name: cneeName,
            gstin: ewbData.toGstin || '',
            address: [ewbData.toAddr1, ewbData.toAddr2].filter(Boolean).join(', '),
            city: refinedCity,
            state: ewbData.toStateCode ? ewbData.toStateCode.toString() : '',
            pincode: ewbData.toPincode ? ewbData.toPincode.toString() : ''
          });
          setConsignees(prev => [...prev, newCnee]);
          setConsigneeCity(refinedCity);
        } catch(e) { 
          console.error(e); 
          // Fallback if save fails
          setConsigneeCity(ewbData.toPlace ? ewbData.toPlace.toUpperCase() : '');
        }
      }
    } else if (ewbData.toPlace) {
      setConsigneeCity(ewbData.toPlace.toUpperCase());
    }
    
    if (ewbData.itemList && ewbData.itemList.length > 0) {
      const totalQty = ewbData.itemList.reduce((sum, item) => sum + (parseInt(item.quantity) || 0), 0);
      setArticles(totalQty.toString());
    }
  };

  const handleEwayBillSearch = async () => {
    if (!ewayBillNo.trim()) return;
    try {
      setIsFetchingEwb(true);
      
      const cleanEwbNo = ewayBillNo.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}`);
      
      await processEwbData(ewbData);
      
      toast.success('E-Way Bill details fetched and filled successfully.');
    } catch (err) {
      toast.error(err.error || err.message || 'Failed to fetch E-Way Bill');
    } finally {
      setIsFetchingEwb(false);
    }
  };

  const handleEwayBillSearchDirect = async (scannedCode) => {
    if (!scannedCode.trim()) return;
    try {
      setIsFetchingEwb(true);
      
      const cleanEwbNo = scannedCode.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}`);
      
      await processEwbData(ewbData);
      
      toast.success('E-Way Bill details fetched from Phone scanner!');
    } catch (err) {
      toast.error(err.error || err.message || 'Failed to fetch E-Way Bill from Phone scan');
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
      toast.error('Please fill all mandatory fields (Consignor, Consignee, Articles, Godown No)');
      return;
    }

    const payload = {
      ewayBillNo,
      consignorName,
      consigneeName,
      consigneeCity,
      articles: parseInt(articles) || 0,
      godownNo,
      remarks
    };

    if (editingId) {
      // For editing, we still wait for the server to confirm changes
      try {
        setLoading(true);
        const savedEntry = await api.put(`/warehouse-inward/${editingId}`, payload);
        toast.success('Entry updated successfully!');
        setEditingId(null);
        setRecentEntry(savedEntry);
        
        // Clear form
        setEwayBillNo('');
        setConsignorName('');
        setConsigneeName('');
        setConsigneeCity('');
        setArticles('');
        setGodownNo('');
        setRemarks('');
      } catch (err) {
        toast.error(err.message || 'Failed to update entry');
      } finally {
        setLoading(false);
      }
    } else {
      // OPTIMISTIC UPDATE: For new entries, clear form instantly to avoid lag
      const optimisticEntry = {
        id: 'temp-' + Date.now(),
        receiptNo: '...', // Temporary placeholder while saving
        createdAt: new Date().toISOString(),
        ...payload
      };
      
      // 1. Instantly update the UI box at the bottom
      setRecentEntry(optimisticEntry);
      
      // 2. Instantly clear the form for the next scan
      setEwayBillNo('');
      setConsignorName('');
      setConsigneeName('');
      setConsigneeCity('');
      setArticles('');
      setGodownNo('');
      setRemarks('');

      // 3. Save to server in the background without freezing the UI
      api.post('/warehouse-inward', payload)
        .then(savedEntry => {
          setRecentEntry(savedEntry); // Update with real ID and Receipt No
          toast.success('Saved to server!');
        })
        .catch(err => {
          toast.error(err.message || 'Background save failed! Please check connection.');
        });
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
          <Button 
            variant="primary"
            type="button"
            onClick={handleEwayBillSearch} 
            disabled={isFetchingEwb} 
            className="flex-1 sm:flex-none h-14 md:h-12 px-6 text-[15px] md:text-sm flex items-center justify-center gap-2"
          >
            {isFetchingEwb ? 'Fetching...' : 'Fetch EWB'}
          </Button>
          
          <Button 
            variant="secondary"
            type="button"
            onClick={startPairing}
            title="Use Phone as Scanner"
            className="h-14 w-14 md:h-12 md:w-12 p-0 flex-shrink-0 flex items-center justify-center text-indigo-600 bg-indigo-100 hover:bg-indigo-200"
          >
            <Smartphone size={24} className="md:w-5 md:h-5" />
          </Button>
          
          <Button 
            variant="success"
            type="button"
            onClick={() => setIsScannerOpen(true)}
            title="Scan QR or E-Way Bill"
            className="h-14 w-14 md:h-12 md:w-12 p-0 flex-shrink-0 flex items-center justify-center"
          >
            <Camera size={24} className="md:w-5 md:h-5" />
          </Button>
        </div>
      </GlassCard>

      {/* Inward Form Fields */}
      <WarehouseInwardForm
        editingId={editingId}
        loading={loading}
        consignorName={consignorName}
        setConsignorName={setConsignorName}
        consigneeName={consigneeName}
        setConsigneeName={setConsigneeName}
        consigneeCity={consigneeCity}
        setConsigneeCity={setConsigneeCity}
        articles={articles}
        setArticles={setArticles}
        godownNo={godownNo}
        setGodownNo={setGodownNo}
        remarks={remarks}
        setRemarks={setRemarks}
        consignorOptions={consignorOptions}
        consigneeOptions={consigneeOptions}
        godowns={godowns}
        consignees={consignees}
        handleInward={handleInward}
        cancelEdit={() => {
          setEditingId(null);
          setEwayBillNo(''); setConsignorName(''); setConsigneeName(''); setConsigneeCity(''); setArticles(''); setGodownNo(''); setRemarks('');
        }}
      />

      {/* Last Saved Entry Display */}
      <WarehouseRecentCard
        recentEntry={recentEntry}
        handleEditRecent={handleEditRecent}
        handlePrintRecent={handlePrintRecent}
      />

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
            <Button 
              variant="icon"
              onClick={stopPairing}
              className="absolute top-4 right-4 p-2 w-9 h-9 flex items-center justify-center bg-transparent text-slate-400 hover:text-slate-600 hover:bg-slate-100"
            >
              <X size={20} />
            </Button>
            
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

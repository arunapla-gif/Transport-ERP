import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Printer, FileText, PackageCheck, Search, CheckSquare, Download, Zap } from 'lucide-react';
import toast from 'react-hot-toast';
import { api } from '../api';
import { generateGcPdfBlob } from '../utils/pdfGenerator';
import { generateGdmPdfBlob } from '../utils/gdmPdfGenerator';

export default function PrintHub() {
  const navigate = useNavigate();
  const [gcNumber, setGcNumber] = useState('');
  const [gcPrefix, setGcPrefix] = useState('BELL');
  const [gcSearchMode, setGcSearchMode] = useState('gc'); // 'gc' or 'gdm'
  const [gdmNumber, setGdmNumber] = useState('');
  const [gdmPrefix, setGdmPrefix] = useState('AP');
  const [gdmPrintType, setGdmPrintType] = useState('gdm');
  
  const [activeTab, setActiveTab] = useState('GC'); // 'GC' or 'GDM'
  
  const [recentGcs, setRecentGcs] = useState([]);
  const [selectedGcs, setSelectedGcs] = useState([]);
  
  const [recentGdms, setRecentGdms] = useState([]);
  const [selectedGdms, setSelectedGdms] = useState([]);
  
  const [showCopiesModal, setShowCopiesModal] = useState(false);
  const [pendingPrintIds, setPendingPrintIds] = useState('');
  const [selectedCopies, setSelectedCopies] = useState(['CONSIGNOR COPY']);
  
  const [showGdmFormatModal, setShowGdmFormatModal] = useState(false);
  const [gdmPendingPrintIds, setGdmPendingPrintIds] = useState('');
  
  const [loading, setLoading] = useState(true);
  const [isPrinting, setIsPrinting] = useState(false);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [gcData, gdmData] = await Promise.all([
        api.get('/gcs'),
        api.get('/gdms')
      ]);
      
      const sortedGcs = (gcData || []).sort((a, b) => new Date(b.date) - new Date(a.date));
      const sortedGdms = (gdmData || []).sort((a, b) => new Date(b.date) - new Date(a.date));
      
      setRecentGcs(sortedGcs);
      setRecentGdms(sortedGdms);
    } catch (err) {
      console.error("Failed to load recent data for printing", err);
    } finally {
      setLoading(false);
    }
  };

  // GC Selection logic
  const toggleGcSelection = (gcId) => {
    setSelectedGcs(prev => prev.includes(gcId) ? prev.filter(id => id !== gcId) : [...prev, gcId]);
  };
  const toggleAllGcs = () => {
    if (selectedGcs.length === recentGcs.length) setSelectedGcs([]);
    else setSelectedGcs(recentGcs.map(gc => gc.gcNumber));
  };

  const handleOpenCopiesModal = (e, ids) => {
    e.preventDefault();
    if (!ids) return;
    setPendingPrintIds(ids);
    setShowCopiesModal(true);
  };

  const toggleCopy = (copy) => {
    setSelectedCopies(prev => prev.includes(copy) ? prev.filter(c => c !== copy) : [...prev, copy]);
  };

  const confirmPrint = () => {
    if (selectedCopies.length === 0) return;
    const copiesQuery = selectedCopies.join(',');
    navigate(`/print/gc/${pendingPrintIds}?copies=${copiesQuery}`);
    setShowCopiesModal(false);
  };

  const handleSilentPrintGc = async () => {
    if (selectedCopies.length === 0) return;
    setIsPrinting(true);
    const toastId = toast.loading('Generating GC PDF for silent print...');
    try {
      // Find the GC objects from recentGcs or fetch if not present
      let gcsToPrint = [];
      const ids = pendingPrintIds.split(',');
      for (const id of ids) {
        let gc = recentGcs.find(g => g.gcNumber === id);
        if (!gc) {
           gc = await api.get(`/gcs/${id}`);
        }
        if (gc) gcsToPrint.push(gc);
      }
      
      const blobUrl = await generateGcPdfBlob(gcsToPrint, selectedCopies);
      const res = await fetch(blobUrl);
      const blob = await res.blob();
      const formData = new FormData();
      formData.append('pdf', blob, 'document.pdf');
      
      toast.loading('Sending to physical printer...', { id: toastId });
      const printRes = await fetch('http://localhost:8181/print', {
        method: 'POST',
        body: formData,
      });
      if (!printRes.ok) throw new Error('Print Agent rejected request');
      toast.success('Successfully sent to printer!', { id: toastId });
      setShowCopiesModal(false);
    } catch (err) {
      console.error(err);
      toast.error('Silent print failed. Is the Local Print Agent running?', { id: toastId });
    } finally {
      setIsPrinting(false);
    }
  };

  const handleOpenGdmFormatModal = (e, ids) => {
    e.preventDefault();
    if (!ids) return;
    setGdmPendingPrintIds(ids);
    setShowGdmFormatModal(true);
  };

  const confirmGdmPrint = () => {
    navigate(`/print/${gdmPrintType}/${gdmPendingPrintIds}`);
    setShowGdmFormatModal(false);
  };

  const handleSilentPrintGdm = async () => {
    if (gdmPrintType === 'cewb' || gdmPrintType === 'combined') {
       toast.error("Silent Print only supports Standard GDM format. Use Preview for CEWB.");
       return;
    }
    
    setIsPrinting(true);
    const toastId = toast.loading('Generating GDM PDF for silent print...');
    try {
      let gdmsToPrint = [];
      const ids = gdmPendingPrintIds.split(',');
      for (const id of ids) {
        let gdm = recentGdms.find(g => g.gdmNumber === id || g.id === id);
        // GDM data for printing needs the full payload (with GCs)
        const fullGdm = await api.get(`/gdms/${gdm ? gdm.id : id}`);
        if (fullGdm) gdmsToPrint.push(fullGdm);
      }
      
      const unitsRes = await api.get('/units').catch(() => []);
      let allUnitOptions = [];
      if (unitsRes && unitsRes.length > 0) {
        allUnitOptions = unitsRes.map(u => ({ label: u.description, code: u.code, category: u.category }));
      }
      
      const blobUrl = await generateGdmPdfBlob(gdmsToPrint, allUnitOptions);
      const res = await fetch(blobUrl);
      const blob = await res.blob();
      const formData = new FormData();
      formData.append('pdf', blob, 'gdm_document.pdf');
      
      toast.loading('Sending to physical printer...', { id: toastId });
      const printRes = await fetch('http://localhost:8181/print', {
        method: 'POST',
        body: formData,
      });
      if (!printRes.ok) throw new Error('Print Agent rejected request');
      toast.success('Successfully sent to printer!', { id: toastId });
      setShowGdmFormatModal(false);
    } catch (err) {
      console.error(err);
      toast.error('Silent print failed. Is the Local Print Agent running?', { id: toastId });
    } finally {
      setIsPrinting(false);
    }
  };

  // GDM Selection logic
  const toggleGdmSelection = (gdmId) => {
    setSelectedGdms(prev => prev.includes(gdmId) ? prev.filter(id => id !== gdmId) : [...prev, gdmId]);
  };
  const toggleAllGdms = () => {
    if (selectedGdms.length === recentGdms.length) setSelectedGdms([]);
    else setSelectedGdms(recentGdms.map(gdm => gdm.gdmNumber));
  };

  return (
    <div className="max-w-6xl mx-auto space-y-6 pb-10 pt-4" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* Selection Modal */}
      {showCopiesModal && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden">
          <div className="bg-white rounded-2xl shadow-xl max-w-sm w-full p-6 m-4 animate-in fade-in zoom-in duration-200">
            <h2 className="text-xl font-black text-slate-800 mb-4 text-center">Print GC Copies</h2>
            <p className="text-sm font-semibold text-slate-500 mb-6 text-center">Select which copies you want to print.</p>
            
            <div className="space-y-3 mb-8">
              {['CONSIGNOR COPY', 'CONSIGNEE COPY', 'LORRY COPY'].map(copy => (
                <label key={copy} className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-colors ${selectedCopies.includes(copy) ? 'border-indigo-600 bg-indigo-50/50' : 'border-slate-200 hover:border-indigo-300'}`}>
                  <input 
                    type="checkbox" 
                    className="w-5 h-5 rounded text-indigo-600 border-slate-300 focus:ring-indigo-500"
                    checked={selectedCopies.includes(copy)}
                    onChange={() => toggleCopy(copy)}
                  />
                  <span className={`font-bold ${selectedCopies.includes(copy) ? 'text-indigo-900' : 'text-slate-600'}`}>{copy}</span>
                </label>
              ))}
            </div>
            
            <div className="flex justify-end gap-3 mt-6">
              <button 
                onClick={() => setShowCopiesModal(false)}
                className="px-4 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold"
              >
                Cancel
              </button>
              <button 
                onClick={confirmPrint}
                className="px-4 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold flex items-center gap-2"
              >
                <FileText size={18} />
                Preview PDF
              </button>
              <button 
                onClick={handleSilentPrintGc}
                disabled={selectedCopies.length === 0 || isPrinting}
                className="px-4 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
              >
                {isPrinting ? <div className="animate-spin h-5 w-5 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={18} />}
                ⚡ Silent Print
              </button>
            </div>
          </div>
        </div>
      )}

      {/* GDM Format Modal */}
      {showGdmFormatModal && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden">
          <div className="bg-white rounded-2xl shadow-xl max-w-sm w-full p-6 m-4 animate-in fade-in zoom-in duration-200">
            <h2 className="text-xl font-black text-slate-800 mb-4 text-center">Select Print Format</h2>
            <p className="text-sm font-semibold text-slate-500 mb-6 text-center">Choose the format for your Delivery Memo.</p>
            
            <div className="space-y-3 mb-8">
              {[
                { id: 'gdm', label: 'Standard GDM' },
                { id: 'cewb', label: 'CEWB Format' },
                { id: 'gdm-combined', label: 'Combined (Both)' }
              ].map(format => (
                <label key={format.id} className={`flex items-center gap-3 p-3 rounded-xl border-2 cursor-pointer transition-colors ${gdmPrintType === format.id ? 'border-emerald-600 bg-emerald-50/50' : 'border-slate-200 hover:border-emerald-300'}`}>
                  <input 
                    type="radio" 
                    name="gdmFormat"
                    className="w-5 h-5 text-emerald-600 border-slate-300 focus:ring-emerald-500"
                    checked={gdmPrintType === format.id}
                    onChange={() => setGdmPrintType(format.id)}
                  />
                  <span className={`font-bold ${gdmPrintType === format.id ? 'text-emerald-900' : 'text-slate-600'}`}>{format.label}</span>
                </label>
              ))}
            </div>
            
            <div className="flex justify-end gap-3 mt-6">
              <button 
                onClick={() => setShowGdmFormatModal(false)}
                className="px-4 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold"
              >
                Cancel
              </button>
              <button 
                onClick={confirmGdmPrint}
                className="px-4 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold flex items-center gap-2"
              >
                <FileText size={18} />
                Preview
              </button>
              <button 
                onClick={handleSilentPrintGdm}
                disabled={isPrinting || gdmPrintType === 'cewb' || gdmPrintType === 'gdm-combined'}
                className="px-4 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                title={gdmPrintType !== 'gdm' ? "Silent Print only supports Standard GDM format" : ""}
              >
                {isPrinting ? <div className="animate-spin h-5 w-5 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={18} />}
                ⚡ Silent Print
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="flex items-center gap-3 mb-8">
        <div className="bg-indigo-100 text-indigo-700 p-2.5 rounded-xl shadow-sm">
          <Printer size={24} />
        </div>
        <div>
          <h1 className="text-2xl font-black text-slate-800">Print Hub</h1>
          <p className="text-sm font-semibold text-slate-500">Quickly print Lorry Receipts and Delivery Memos</p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        
        {/* LORRY RECEIPT PRINT CARD */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col items-center text-center hover:shadow-md transition-shadow">
          <div className="w-16 h-16 bg-amber-100 text-amber-600 rounded-full flex items-center justify-center mb-4">
            <FileText size={32} />
          </div>
          <h2 className="text-xl font-black text-slate-800 mb-2">Lorry Receipt (GC)</h2>
          <p className="text-sm font-medium text-slate-500 mb-4">Print A5 Lorry Receipts.</p>
          
          <div className="flex gap-6 mb-4">
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="radio" name="gcSearchMode" checked={gcSearchMode === 'gc'} onChange={() => setGcSearchMode('gc')} className="text-amber-500 focus:ring-amber-500" />
              <span className="text-sm font-bold text-slate-700">By GC Number</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="radio" name="gcSearchMode" checked={gcSearchMode === 'gdm'} onChange={() => setGcSearchMode('gdm')} className="text-amber-500 focus:ring-amber-500" />
              <span className="text-sm font-bold text-slate-700">Bulk by GDM</span>
            </label>
          </div>
          
          <div className="w-full flex gap-2">
            <div className="flex items-center bg-slate-100 rounded-xl p-1 border border-slate-200 shrink-0 h-12">
              <button 
                onClick={() => setGcPrefix('AP')}
                className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gcPrefix === 'AP' ? 'bg-white shadow text-amber-600' : 'text-slate-400 hover:text-slate-600'}`}
              >
                AP
              </button>
              <button 
                onClick={() => setGcPrefix('BELL')}
                className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gcPrefix === 'BELL' ? 'bg-white shadow text-amber-600' : 'text-slate-400 hover:text-slate-600'}`}
              >
                BELL
              </button>
            </div>
            <input 
              type="text" 
              placeholder={gcSearchMode === 'gc' ? "1001" : "1001"} 
              value={gcNumber}
              onChange={(e) => setGcNumber(e.target.value.replace(/[^0-9]/g, ''))}
              className="flex-1 h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all uppercase"
            />
            <button 
              onClick={(e) => {
                const fullNumber = `${gcPrefix}-${gcNumber}`;
                if (gcSearchMode === 'gdm') {
                  window.open(`/print/gc/${fullNumber}?mode=gdm&copies=LORRY COPY`, '_blank');
                } else {
                  handleOpenCopiesModal(e, fullNumber);
                }
              }}
              disabled={!gcNumber}
              className={`h-12 px-6 flex items-center justify-center gap-2 bg-amber-500 hover:bg-amber-400 text-white font-black rounded-xl transition-all shadow-sm hover:shadow-md ${!gcNumber ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={18} /> {gcSearchMode === 'gdm' ? 'Bulk Print' : 'Print'}
            </button>
          </div>
        </div>

        {/* DELIVERY MEMO PRINT CARD */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 flex flex-col items-center text-center hover:shadow-md transition-shadow">
          <div className="w-16 h-16 bg-emerald-100 text-emerald-600 rounded-full flex items-center justify-center mb-4">
            <PackageCheck size={32} />
          </div>
          <h2 className="text-xl font-black text-slate-800 mb-2">Delivery Memo (GDM)</h2>
          <p className="text-sm font-medium text-slate-500 mb-6">Print an A4 size Goods Despatch Memo.</p>
          
          <div className="w-full flex flex-col gap-2">
            <div className="flex gap-2">
              <div className="flex items-center bg-slate-100 rounded-xl p-1 border border-slate-200 shrink-0 h-12">
                <button 
                  onClick={() => setGdmPrefix('AP')}
                  className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gdmPrefix === 'AP' ? 'bg-white shadow text-emerald-600' : 'text-slate-400 hover:text-slate-600'}`}
                >
                  AP
                </button>
                <button 
                  onClick={() => setGdmPrefix('BELL')}
                  className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gdmPrefix === 'BELL' ? 'bg-white shadow text-emerald-600' : 'text-slate-400 hover:text-slate-600'}`}
                >
                  BELL
                </button>
              </div>
              <input 
                type="text" 
                placeholder="1001" 
                value={gdmNumber}
                onChange={(e) => setGdmNumber(e.target.value.replace(/[^0-9]/g, ''))}
                className="w-full h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all uppercase"
              />
            </div>
            <button 
              onClick={(e) => handleOpenGdmFormatModal(e, `${gdmPrefix}-${gdmNumber}`)}
              disabled={!gdmNumber}
              className={`w-full h-12 px-6 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-black rounded-xl transition-all shadow-sm hover:shadow-md ${!gdmNumber ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={18} /> Choose Format & Print
            </button>
          </div>
        </div>

      </div>


      {/* BATCH PRINTING SECTION */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
        
        {/* Tabs */}
        <div className="flex border-b border-slate-200 bg-slate-50/50 pt-2 px-4 gap-2">
          <button 
            onClick={() => setActiveTab('GC')}
            className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GC' ? 'bg-white border-indigo-600 text-indigo-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
          >
            All GCs
          </button>
          <button 
            onClick={() => setActiveTab('GDM')}
            className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GDM' ? 'bg-white border-emerald-600 text-emerald-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
          >
            All GDMs
          </button>
        </div>

        {/* Tab Content Header */}
        <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-white">
          <div>
            <h2 className="text-lg font-black text-slate-800 flex items-center gap-2">
              <CheckSquare className={activeTab === 'GC' ? "text-indigo-600" : "text-emerald-600"} size={20} />
              Batch Print {activeTab === 'GC' ? 'GCs' : 'GDMs'}
            </h2>
            <p className="text-xs font-semibold text-slate-500 mt-0.5">Select multiple documents to print them all in one go.</p>
          </div>
          
          {activeTab === 'GC' ? (
            <button 
              onClick={(e) => handleOpenCopiesModal(e, selectedGcs.join(','))}
              disabled={selectedGcs.length === 0}
              className={`h-10 px-6 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGcs.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={16} /> Print Selected ({selectedGcs.length})
            </button>
          ) : (
            <button 
              onClick={(e) => handleOpenGdmFormatModal(e, selectedGdms.join(','))}
              disabled={selectedGdms.length === 0}
              className={`h-10 px-6 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGdms.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={16} /> Print Selected ({selectedGdms.length})
            </button>
          )}
        </div>

        {/* Tab Content Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              {activeTab === 'GC' ? (
                <tr className="bg-slate-50 border-b border-slate-200">
                  <th className="px-4 py-3 w-12 text-center">
                    <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" onChange={toggleAllGcs} checked={recentGcs.length > 0 && selectedGcs.length === recentGcs.length} />
                  </th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">GC No.</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Date</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Consignor</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Consignee</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-center">Bundles</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">Freight</th>
                </tr>
              ) : (
                <tr className="bg-slate-50 border-b border-slate-200">
                  <th className="px-4 py-3 w-12 text-center">
                    <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500" onChange={toggleAllGdms} checked={recentGdms.length > 0 && selectedGdms.length === recentGdms.length} />
                  </th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">GDM No.</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Date</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Vehicle</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider">Destination</th>
                  <th className="px-4 py-3 text-xs font-bold text-slate-500 uppercase tracking-wider text-right">GCs Linked</th>
                </tr>
              )}
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {loading ? (
                <tr><td colSpan="7" className="p-8 text-center text-slate-400 font-semibold animate-pulse">Loading all records...</td></tr>
              ) : activeTab === 'GC' ? (
                recentGcs.length === 0 ? (
                  <tr><td colSpan="7" className="p-8 text-center text-slate-400 font-semibold">No GCs found.</td></tr>
                ) : (
                  recentGcs.map((gc) => (
                    <tr key={gc.id} className={`hover:bg-slate-50 transition-colors cursor-pointer ${selectedGcs.includes(gc.gcNumber) ? 'bg-indigo-50/50' : ''}`} onClick={() => toggleGcSelection(gc.gcNumber)}>
                      <td className="px-4 py-3 text-center">
                        <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-indigo-600 focus:ring-indigo-500" checked={selectedGcs.includes(gc.gcNumber)} readOnly />
                      </td>
                      <td className="px-4 py-3"><span className="font-bold text-slate-800">{gc.gcNumber}</span></td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600">{gc.date ? new Date(gc.date).toLocaleDateString('en-GB') : '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gc.consignor?.name || '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gc.consignee?.name || '-'}</td>
                      <td className="px-4 py-3 text-sm font-bold text-slate-800 text-center">{gc.goods?.reduce((sum, g) => sum + (g.articleCount || 0), 0) || 0}</td>
                      <td className="px-4 py-3 text-sm font-bold text-emerald-600 text-right">₹{gc.freightTotal?.toFixed(2) || '0.00'}</td>
                    </tr>
                  ))
                )
              ) : (
                recentGdms.length === 0 ? (
                  <tr><td colSpan="6" className="p-8 text-center text-slate-400 font-semibold">No GDMs found.</td></tr>
                ) : (
                  recentGdms.map((gdm) => (
                    <tr key={gdm.id} className={`hover:bg-slate-50 transition-colors cursor-pointer ${selectedGdms.includes(gdm.gdmNumber) ? 'bg-emerald-50/50' : ''}`} onClick={() => toggleGdmSelection(gdm.gdmNumber)}>
                      <td className="px-4 py-3 text-center">
                        <input type="checkbox" className="w-4 h-4 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500" checked={selectedGdms.includes(gdm.gdmNumber)} readOnly />
                      </td>
                      <td className="px-4 py-3"><span className="font-bold text-slate-800">{gdm.gdmNumber}</span></td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600">{gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gdm.vehicle?.vehicleNumber || '-'}</td>
                      <td className="px-4 py-3 text-sm font-medium text-slate-600 truncate max-w-[200px]">{gdm.toName || '-'}</td>
                      <td className="px-4 py-3 text-sm font-bold text-slate-800 text-right">{gdm.gcs?.length || 0}</td>
                    </tr>
                  ))
                )
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* HARDWARE PRINT AGENT SECTION */}
      <div className="bg-slate-900 rounded-2xl shadow-xl border border-slate-800 overflow-hidden mt-6 p-6 md:p-8 flex flex-col md:flex-row items-center justify-between gap-6">
        <div>
          <h2 className="text-xl font-black text-white mb-2 flex items-center gap-2">
            <Printer size={24} className="text-amber-400" />
            Hardware Print Agent
          </h2>
          <p className="text-slate-400 font-medium text-sm max-w-xl">
            To use the "Silent Hardware Print" feature without browser popups, you must run this tiny background app on your computer. Download the agent below and leave it running in the background.
          </p>
        </div>
        <div className="flex gap-3 shrink-0">
          <a href="/LocalPrintAgent.zip" download className="h-11 px-6 bg-amber-500 hover:bg-amber-400 text-slate-900 rounded-xl font-bold text-sm shadow-md transition-all flex items-center gap-2">
            <Download size={16} /> Download Agent (Win/Mac)
          </a>
        </div>
      </div>

    </div>
  );
}

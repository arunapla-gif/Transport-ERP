import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Printer, FileText, PackageCheck, Search, CheckSquare, Download, Zap } from 'lucide-react';
import toast from 'react-hot-toast';
import { api } from '../api';
import { generateGcPdfBlob } from '../utils/pdfGenerator';
import { generateGdmPdfBlob } from '../utils/gdmPdfGenerator';
import { Button } from '../components/ui/Button';

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

  const [gcPage, setGcPage] = useState(1);
  const [hasMoreGcs, setHasMoreGcs] = useState(true);
  const [gcSearchTerm, setGcSearchTerm] = useState('');
  const [debouncedGcSearch, setDebouncedGcSearch] = useState('');
  const gcObserverRef = useRef(null);

  const [gdmPage, setGdmPage] = useState(1);
  const [hasMoreGdms, setHasMoreGdms] = useState(true);
  const [gdmSearchTerm, setGdmSearchTerm] = useState('');
  const [debouncedGdmSearch, setDebouncedGdmSearch] = useState('');
  const gdmObserverRef = useRef(null);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedGcSearch(gcSearchTerm), 400);
    return () => clearTimeout(timer);
  }, [gcSearchTerm]);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedGdmSearch(gdmSearchTerm), 400);
    return () => clearTimeout(timer);
  }, [gdmSearchTerm]);

  useEffect(() => {
    setGcPage(1);
    setRecentGcs([]);
    setHasMoreGcs(true);
  }, [debouncedGcSearch]);

  useEffect(() => {
    setGdmPage(1);
    setRecentGdms([]);
    setHasMoreGdms(true);
  }, [debouncedGdmSearch]);

  const fetchGcs = async (pageNum = gcPage) => {
    try {
      setLoading(true);
      const res = await api.get(`/gcs?page=${pageNum}&limit=50&searchQuery=${encodeURIComponent(debouncedGcSearch)}`);
      if (res.data) {
        setRecentGcs(prev => {
          if (pageNum === 1) return res.data;
          const existingIds = new Set(prev.map(p => p.id));
          return [...prev, ...res.data.filter(d => !existingIds.has(d.id))];
        });
        setHasMoreGcs(res.page < res.totalPages);
      } else {
        setRecentGcs(res || []);
        setHasMoreGcs(false);
      }
    } catch (err) {
      console.error(err);
      toast.error('Failed to load GCs');
    } finally {
      setLoading(false);
    }
  };

  const fetchGdms = async (pageNum = gdmPage) => {
    try {
      setLoading(true);
      const res = await api.get(`/gdms?page=${pageNum}&limit=50&searchQuery=${encodeURIComponent(debouncedGdmSearch)}`);
      if (res.data) {
        setRecentGdms(prev => {
          if (pageNum === 1) return res.data;
          const existingIds = new Set(prev.map(p => p.id));
          return [...prev, ...res.data.filter(d => !existingIds.has(d.id))];
        });
        setHasMoreGdms(res.page < res.totalPages);
      } else {
        setRecentGdms(res || []);
        setHasMoreGdms(false);
      }
    } catch (err) {
      console.error(err);
      toast.error('Failed to load GDMs');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'GC') fetchGcs(gcPage);
  }, [gcPage, debouncedGcSearch, activeTab]);

  useEffect(() => {
    if (activeTab === 'GDM') fetchGdms(gdmPage);
  }, [gdmPage, debouncedGdmSearch, activeTab]);

  useEffect(() => {
    if (activeTab !== 'GC') return;
    const observer = new IntersectionObserver(
      entries => {
        if (entries[0].isIntersecting && hasMoreGcs && !loading) {
          setGcPage(prev => prev + 1);
        }
      },
      { rootMargin: '1500px' }
    );
    if (gcObserverRef.current) observer.observe(gcObserverRef.current);
    return () => observer.disconnect();
  }, [hasMoreGcs, loading, activeTab]);

  useEffect(() => {
    if (activeTab !== 'GDM') return;
    const observer = new IntersectionObserver(
      entries => {
        if (entries[0].isIntersecting && hasMoreGdms && !loading) {
          setGdmPage(prev => prev + 1);
        }
      },
      { rootMargin: '1500px' }
    );
    if (gdmObserverRef.current) observer.observe(gdmObserverRef.current);
    return () => observer.disconnect();
  }, [hasMoreGdms, loading, activeTab]);

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

  const handleDownloadPdfGc = async () => {
    if (selectedCopies.length === 0) return;
    setIsPrinting(true);
    const toastId = toast.loading('Generating GC PDF...');
    try {
      let gcsToPrint = [];
      const ids = pendingPrintIds.split(',');
      for (const id of ids) {
        let gc = recentGcs.find(g => g.gcNumber === id);
        if (!gc) gc = await api.get(`/gcs/${id}`);
        if (gc) gcsToPrint.push(gc);
      }
      const blobUrl = await generateGcPdfBlob(gcsToPrint, selectedCopies);
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = `GC_${gcsToPrint[0]?.gcNumber || 'Print'}.pdf`;
      link.click();
      toast.success('PDF downloaded!', { id: toastId });
      setShowCopiesModal(false);
    } catch (err) {
      console.error(err);
      toast.error('Failed to generate PDF.', { id: toastId });
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
    setIsPrinting(true);
    const toastMessage = gdmPrintType === 'cewb' ? 'Generating CEWB PDF for silent print...' : 
                         gdmPrintType === 'combined' ? 'Generating Combined PDF for silent print...' :
                         'Generating GDM PDF for silent print...';
    
    const toastId = toast.loading(toastMessage);
    try {
      let gdmsToPrint = [];
      const ids = gdmPendingPrintIds.split(',');
      for (const id of ids) {
        let gdm = recentGdms.find(g => g.gdmNumber === id || g.id === id);
        // GDM data for printing needs the full payload (with GCs)
        const fullGdm = await api.get(`/gdms/${id}`);
        if (fullGdm) gdmsToPrint.push(fullGdm);
      }
      
      const unitsRes = await api.get('/units').catch(() => []);
      let allUnitOptions = [];
      if (unitsRes && unitsRes.length > 0) {
        allUnitOptions = unitsRes.map(u => ({ label: u.description, code: u.code, category: u.category }));
      }
      
      const pdfFormat = gdmPrintType === 'combined' ? 'gdm-combined' : gdmPrintType;
      const blobUrl = await generateGdmPdfBlob(gdmsToPrint, allUnitOptions, pdfFormat);
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

  const handleDownloadPdfGdm = async () => {
    setIsPrinting(true);
    const toastId = toast.loading('Generating GDM PDF...');
    try {
      let gdmsToPrint = [];
      const ids = gdmPendingPrintIds.split(',');
      for (const id of ids) {
        let gdm = recentGdms.find(g => g.gdmNumber === id || g.id === id);
        const fullGdm = await api.get(`/gdms/${id}`);
        if (fullGdm) gdmsToPrint.push(fullGdm);
      }
      const unitsRes = await api.get('/units').catch(() => []);
      let allUnitOptions = [];
      if (unitsRes && unitsRes.length > 0) {
        allUnitOptions = unitsRes.map(u => ({ label: u.description, code: u.code, category: u.category }));
      }
      const blobUrl = await generateGdmPdfBlob(gdmsToPrint, allUnitOptions, gdmPrintType);
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = `GDM_${gdmsToPrint[0]?.gdmNumber || 'Print'}.pdf`;
      link.click();
      toast.success('PDF downloaded!', { id: toastId });
      setShowGdmFormatModal(false);
    } catch (err) {
      console.error(err);
      toast.error('Failed to generate PDF.', { id: toastId });
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
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden p-4">
          <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in duration-200">
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
            
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-6">
              <Button variant="custom" 
                onClick={() => setShowCopiesModal(false)}
                className="px-3 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold text-sm flex justify-center items-center"
              >
                Cancel
              </Button>
              <Button variant="custom" 
                onClick={handleDownloadPdfGc}
                disabled={selectedCopies.length === 0 || isPrinting}
                className="px-3 py-2 bg-indigo-100 text-indigo-700 rounded-lg hover:bg-indigo-200 font-bold text-sm flex justify-center items-center gap-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Download size={16} />
                PDF
              </Button>
              <Button variant="custom" 
                onClick={confirmPrint}
                className="px-3 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold text-sm flex justify-center items-center gap-1.5"
              >
                <FileText size={16} />
                Preview
              </Button>
              <Button variant="custom" 
                onClick={handleSilentPrintGc}
                disabled={selectedCopies.length === 0 || isPrinting}
                className="px-3 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold text-sm disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-1.5"
              >
                {isPrinting ? <div className="animate-spin h-4 w-4 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={16} />}
                Print
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* GDM Format Modal */}
      {showGdmFormatModal && (
        <div className="fixed inset-0 bg-slate-900/40 backdrop-blur-sm z-50 flex items-center justify-center print:hidden p-4">
          <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-6 animate-in fade-in zoom-in duration-200">
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
            
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-6">
              <Button variant="custom" 
                onClick={() => setShowGdmFormatModal(false)}
                className="px-3 py-2 bg-slate-200 text-slate-800 rounded-lg hover:bg-slate-300 font-bold text-sm flex justify-center items-center"
              >
                Cancel
              </Button>
              <Button variant="custom" 
                onClick={handleDownloadPdfGdm}
                disabled={isPrinting}
                className="px-3 py-2 bg-emerald-100 text-emerald-700 rounded-lg hover:bg-emerald-200 font-bold text-sm flex justify-center items-center gap-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <Download size={16} />
                PDF
              </Button>
              <Button variant="custom" 
                onClick={confirmGdmPrint}
                className="px-3 py-2 bg-slate-600 text-white rounded-lg hover:bg-slate-500 font-bold text-sm flex justify-center items-center gap-1.5"
              >
                <FileText size={16} />
                Preview
              </Button>
              <Button variant="custom" 
                onClick={handleSilentPrintGdm}
                disabled={isPrinting}
                className="px-3 py-2 bg-yellow-500 text-slate-900 rounded-lg hover:bg-yellow-400 font-bold text-sm disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-1.5"
              >
                {isPrinting ? <div className="animate-spin h-4 w-4 border-b-2 border-slate-900 rounded-full"></div> : <Zap size={16} />}
                Print
              </Button>
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
              <Button variant="custom" 
                onClick={() => setGcPrefix('AP')}
                className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gcPrefix === 'AP' ? 'bg-white shadow text-amber-600' : 'text-slate-400 hover:text-slate-600'}`}
              >
                AP
              </Button>
              <Button variant="custom" 
                onClick={() => setGcPrefix('BELL')}
                className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gcPrefix === 'BELL' ? 'bg-white shadow text-amber-600' : 'text-slate-400 hover:text-slate-600'}`}
              >
                BELL
              </Button>
            </div>
            <input 
              type="text" 
              placeholder={gcSearchMode === 'gc' ? "1001" : "1001"} 
              value={gcNumber}
              onChange={(e) => setGcNumber(e.target.value.replace(/[^0-9]/g, ''))}
              className="flex-1 h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all uppercase"
            />
            <Button variant="custom" 
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
            </Button>
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
                <Button variant="custom" 
                  onClick={() => setGdmPrefix('AP')}
                  className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gdmPrefix === 'AP' ? 'bg-white shadow text-emerald-600' : 'text-slate-400 hover:text-slate-600'}`}
                >
                  AP
                </Button>
                <Button variant="custom" 
                  onClick={() => setGdmPrefix('BELL')}
                  className={`px-3 py-1.5 text-sm font-black rounded-lg transition-colors ${gdmPrefix === 'BELL' ? 'bg-white shadow text-emerald-600' : 'text-slate-400 hover:text-slate-600'}`}
                >
                  BELL
                </Button>
              </div>
              <input 
                type="text" 
                placeholder="1001" 
                value={gdmNumber}
                onChange={(e) => setGdmNumber(e.target.value.replace(/[^0-9]/g, ''))}
                className="w-full h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all uppercase"
              />
            </div>
            <Button variant="custom" 
              onClick={(e) => handleOpenGdmFormatModal(e, `${gdmPrefix}-${gdmNumber}`)}
              disabled={!gdmNumber}
              className={`w-full h-12 px-6 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-black rounded-xl transition-all shadow-sm hover:shadow-md ${!gdmNumber ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={18} /> Choose Format & Print
            </Button>
          </div>
        </div>

      </div>


      {/* BATCH PRINTING SECTION */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
        
        {/* Tabs */}
        <div className="flex border-b border-slate-200 bg-slate-50/50 pt-2 px-4 gap-2">
          <Button variant="custom" 
            onClick={() => setActiveTab('GC')}
            className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GC' ? 'bg-white border-indigo-600 text-indigo-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
          >
            All GCs
          </Button>
          <Button variant="custom" 
            onClick={() => setActiveTab('GDM')}
            className={`px-6 py-3 font-bold text-sm rounded-t-lg transition-colors border-b-2 ${activeTab === 'GDM' ? 'bg-white border-emerald-600 text-emerald-700' : 'border-transparent text-slate-500 hover:text-slate-700 hover:bg-slate-100'}`}
          >
            All GDMs
          </Button>
        </div>

        {/* Tab Content Header */}
        <div className="p-5 border-b border-slate-100 flex flex-col md:flex-row items-center justify-between bg-white gap-4">
          <div>
            <h2 className="text-lg font-black text-slate-800 flex items-center gap-2">
              <CheckSquare className={activeTab === 'GC' ? "text-indigo-600" : "text-emerald-600"} size={20} />
              Batch Print {activeTab === 'GC' ? 'GCs' : 'GDMs'}
            </h2>
            <p className="text-xs font-semibold text-slate-500 mt-0.5">Select multiple documents to print them all in one go.</p>
          </div>
          
          <div className="flex gap-4 items-center w-full md:w-auto">
             <div className="relative flex-1 md:w-64">
                <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input 
                  type="text" 
                  placeholder={`Search ${activeTab === 'GC' ? 'GCs...' : 'GDMs...'}`} 
                  value={activeTab === 'GC' ? gcSearchTerm : gdmSearchTerm}
                  onChange={(e) => activeTab === 'GC' ? setGcSearchTerm(e.target.value) : setGdmSearchTerm(e.target.value)}
                  className="w-full h-10 pl-9 pr-3 border border-slate-200 rounded-lg bg-slate-50 text-xs font-bold text-slate-700 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"
                />
             </div>
             
            {activeTab === 'GC' ? (
              <Button variant="custom" 
                onClick={(e) => handleOpenCopiesModal(e, selectedGcs.join(','))}
                disabled={selectedGcs.length === 0}
                className={`h-10 px-6 shrink-0 flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGcs.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
              >
                <Printer size={16} /> Print Selected ({selectedGcs.length})
              </Button>
            ) : (
              <Button variant="custom" 
                onClick={(e) => handleOpenGdmFormatModal(e, selectedGdms.join(','))}
                disabled={selectedGdms.length === 0}
                className={`h-10 px-6 shrink-0 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGdms.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
              >
                <Printer size={16} /> Print Selected ({selectedGdms.length})
              </Button>
            )}
          </div>
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
              {loading && recentGcs.length === 0 && recentGdms.length === 0 ? (
                <tr><td colSpan="7" className="p-8 text-center text-slate-400 font-semibold animate-pulse">Loading records...</td></tr>
              ) : activeTab === 'GC' ? (
                <>
                  {recentGcs.length === 0 ? (
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
                  )}
                  {hasMoreGcs && (
                    <tr ref={gcObserverRef}>
                      <td colSpan="7" className="p-6 text-center text-slate-500 font-medium">
                        {loading ? <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span> : 'Scroll for more'}
                      </td>
                    </tr>
                  )}
                </>
              ) : (
                <>
                  {recentGdms.length === 0 ? (
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
                  )}
                  {hasMoreGdms && (
                    <tr ref={gdmObserverRef}>
                      <td colSpan="6" className="p-6 text-center text-slate-500 font-medium">
                        {loading ? <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-emerald-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span> : 'Scroll for more'}
                      </td>
                    </tr>
                  )}
                </>
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

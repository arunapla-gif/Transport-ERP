import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Printer, FileText, PackageCheck, Search, CheckSquare, Download, Zap } from 'lucide-react';
import toast from 'react-hot-toast';
import { api } from '../api';
import { Button } from '../components/ui/Button';
import { PrintCopiesModal, PrintFormatModal } from '../components/print/PrintHubModals';
import { BatchPrintSection } from '../components/print/BatchPrintSection';

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
      <PrintCopiesModal 
        show={showCopiesModal}
        onClose={() => setShowCopiesModal(false)}
        selectedCopies={selectedCopies}
        toggleCopy={toggleCopy}
        handleDownloadPdfGc={handleDownloadPdfGc}
        confirmPrint={confirmPrint}
        handleSilentPrintGc={handleSilentPrintGc}
        isPrinting={isPrinting}
      />

      {/* GDM Format Modal */}
      <PrintFormatModal 
        show={showGdmFormatModal}
        onClose={() => setShowGdmFormatModal(false)}
        gdmPrintType={gdmPrintType}
        setGdmPrintType={setGdmPrintType}
        handleDownloadPdfGdm={handleDownloadPdfGdm}
        confirmGdmPrint={confirmGdmPrint}
        handleSilentPrintGdm={handleSilentPrintGdm}
        isPrinting={isPrinting}
      />

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
      <BatchPrintSection
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        gcSearchTerm={gcSearchTerm}
        setGcSearchTerm={setGcSearchTerm}
        gdmSearchTerm={gdmSearchTerm}
        setGdmSearchTerm={setGdmSearchTerm}
        handleOpenCopiesModal={handleOpenCopiesModal}
        handleOpenGdmFormatModal={handleOpenGdmFormatModal}
        selectedGcs={selectedGcs}
        selectedGdms={selectedGdms}
        toggleGcSelection={toggleGcSelection}
        toggleGdmSelection={toggleGdmSelection}
        toggleAllGcs={toggleAllGcs}
        toggleAllGdms={toggleAllGdms}
        recentGcs={recentGcs}
        recentGdms={recentGdms}
        hasMoreGcs={hasMoreGcs}
        hasMoreGdms={hasMoreGdms}
        loading={loading}
        gcObserverRef={gcObserverRef}
        gdmObserverRef={gdmObserverRef}
      />

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

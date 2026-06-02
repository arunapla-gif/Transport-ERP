import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Printer, FileText, PackageCheck, Search, CheckSquare } from 'lucide-react';
import { api } from '../api';

export default function PrintHub() {
  const [gcNumber, setGcNumber] = useState('');
  const [gdmNumber, setGdmNumber] = useState('');
  
  const [activeTab, setActiveTab] = useState('GC'); // 'GC' or 'GDM'
  
  const [recentGcs, setRecentGcs] = useState([]);
  const [selectedGcs, setSelectedGcs] = useState([]);
  
  const [recentGdms, setRecentGdms] = useState([]);
  const [selectedGdms, setSelectedGdms] = useState([]);
  
  const [showCopiesModal, setShowCopiesModal] = useState(false);
  const [pendingPrintIds, setPendingPrintIds] = useState('');
  const [selectedCopies, setSelectedCopies] = useState(['CONSIGNOR COPY']);
  
  const [loading, setLoading] = useState(true);

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
    window.open(`/print/gc/${pendingPrintIds}?copies=${copiesQuery}`, '_blank');
    setShowCopiesModal(false);
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
            
            <div className="flex gap-3">
              <button 
                onClick={() => setShowCopiesModal(false)}
                className="flex-1 px-4 py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl transition-colors"
              >
                Cancel
              </button>
              <button 
                onClick={confirmPrint}
                disabled={selectedCopies.length === 0}
                className="flex-1 px-4 py-3 bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-xl transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center gap-2"
              >
                🖨️ Print
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
          <h2 className="text-xl font-black text-slate-800 mb-2">Single Lorry Receipt (GC)</h2>
          <p className="text-sm font-medium text-slate-500 mb-6">Print a specific A5 size Lorry Receipt.</p>
          
          <div className="w-full flex gap-2">
            <input 
              type="text" 
              placeholder="e.g. BELL-1001" 
              value={gcNumber}
              onChange={(e) => setGcNumber(e.target.value.toUpperCase())}
              className="flex-1 h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-amber-500/20 focus:border-amber-500 transition-all uppercase"
            />
            <button 
              onClick={(e) => handleOpenCopiesModal(e, gcNumber)}
              disabled={!gcNumber}
              className={`h-12 px-6 flex items-center justify-center gap-2 bg-amber-500 hover:bg-amber-400 text-white font-black rounded-xl transition-all shadow-sm hover:shadow-md ${!gcNumber ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={18} /> Print
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
          
          <div className="w-full flex gap-2">
            <input 
              type="text" 
              placeholder="e.g. 1001" 
              value={gdmNumber}
              onChange={(e) => setGdmNumber(e.target.value)}
              className="flex-1 h-12 px-4 bg-slate-50 border border-slate-200 text-slate-800 font-bold rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all uppercase"
            />
            <Link 
              to={gdmNumber ? `/print/gdm/${gdmNumber}` : '#'}
              target={gdmNumber ? "_blank" : undefined}
              className={`h-12 px-6 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-black rounded-xl transition-all shadow-sm hover:shadow-md ${!gdmNumber ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={18} /> Print
            </Link>
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
            <Link 
              to={selectedGdms.length > 0 ? `/print/gdm/${selectedGdms.join(',')}` : '#'}
              target={selectedGdms.length > 0 ? "_blank" : undefined}
              className={`h-10 px-6 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-bold rounded-lg transition-all shadow-sm ${selectedGdms.length === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
            >
              <Printer size={16} /> Print Selected ({selectedGdms.length})
            </Link>
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

    </div>
  );
}

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { api } from '../api';
import { FileText, Calendar, Download, TrendingUp, Truck, Package, IndianRupee, Users, Building2, X, Clock, CheckCircle2, History } from 'lucide-react';

export default function Reports() {
  const [activeTab, setActiveTab] = useState('gc'); // gc, gdm, ewaybill, consignor, consignee, vehicle
  const [selectedGc, setSelectedGc] = useState(null);
  
  // Generic Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  
  // Advanced Filters
  const [branch, setBranch] = useState('ALL');
  const [statusFilter, setStatusFilter] = useState('');
  const [freightTypeFilter, setFreightTypeFilter] = useState('');
  const [godownFilter, setGodownFilter] = useState('');

  // Pagination & Data State
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalRecords, setTotalRecords] = useState(0);
  const [reportData, setReportData] = useState([]);
  const [loading, setLoading] = useState(false);

  // Debounce search query
  const [debouncedSearch, setDebouncedSearch] = useState('');
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchQuery), 500);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  const resetFiltersAndData = () => {
    setPage(1);
    setReportData([]);
  };

  useEffect(() => {
    resetFiltersAndData();
  }, [activeTab, dateFrom, dateTo, branch, statusFilter, freightTypeFilter, godownFilter, debouncedSearch]);

  const fetchReportData = async (pageNum = 1, append = false) => {
    try {
      if (!append) setLoading(true);

      const queryParams = new URLSearchParams();
      if (branch !== 'ALL') queryParams.append('branch', branch);
      if (dateFrom) queryParams.append('fromDate', new Date(dateFrom).toISOString());
      if (dateTo) {
        const d = new Date(dateTo);
        d.setHours(23, 59, 59, 999);
        queryParams.append('toDate', d.toISOString());
      }
      if (statusFilter) queryParams.append('status', statusFilter);
      if (freightTypeFilter && (activeTab === 'gc' || activeTab === 'ewaybill')) queryParams.append('freightType', freightTypeFilter);
      if (godownFilter && (activeTab === 'gc' || activeTab === 'ewaybill')) queryParams.append('godown', godownFilter);
      if (debouncedSearch) queryParams.append('searchQuery', debouncedSearch);

      let finalData = [];
      let nextTotalPages = 1;
      let nextTotalRecords = 0;

      // 1. Aggregation Tabs (Fetch all at once, no pagination needed for UI since it's just grouped stats)
      if (['consignor', 'consignee', 'vehicle'].includes(activeTab)) {
        if (pageNum > 1) return; // Master tabs don't paginate
        const res = await api.get(`/reports/aggregations?${queryParams.toString()}`);
        if (activeTab === 'consignor') finalData = res.consignors || [];
        if (activeTab === 'consignee') finalData = res.consignees || [];
        if (activeTab === 'vehicle') finalData = res.vehicles || [];
        nextTotalRecords = finalData.length;
      }
      
      // 2. Transactional Tabs (Paginated)
      else {
        queryParams.append('page', pageNum);
        queryParams.append('limit', 50);

        if (activeTab === 'gc' || activeTab === 'ewaybill') {
          const res = await api.get(`/gcs?${queryParams.toString()}`);
          nextTotalPages = res.totalPages || 1;
          nextTotalRecords = res.total || 0;
          
          if (activeTab === 'gc') {
            finalData = (res.data || []).map(gc => {
              const totalArticles = gc.goods ? gc.goods.reduce((acc, curr) => acc + (parseInt(curr.articleCount) || 0), 0) : 0;
              return {
                id: gc.id,
                Number: gc.gcNumber,
                Date: new Date(gc.date).toLocaleDateString('en-IN'),
                Consignor: gc.consignor?.name || '-',
                Consignee: gc.consignee?.name || '-',
                Godown: gc.godown || '-',
                Articles: totalArticles,
                Inv_No: gc.invoiceNumber || '-',
                Inv_Value: parseFloat(gc.invoiceValue || 0).toFixed(2),
                Frt_Type: gc.freightType || '-',
                Freight: parseFloat(gc.freightTotal || 0).toFixed(2),
                GDM_No: gc.gdm?.gdmNumber || 'Unassigned',
                Vehicle: gc.gdm?.vehicle?.vehicleNumber || '-',
                Status: gc.status,
                _gcObj: gc
              };
            });
          } else { // ewaybill
            finalData = (res.data || []).map(gc => {
              let validUptoStr = '-';
              let ewbDateStr = '-';
              if (gc.ewbRawData) {
                if (gc.ewbRawData.validUpto) validUptoStr = gc.ewbRawData.validUpto;
                if (gc.ewbRawData.ewayBillDate || gc.ewbRawData.ewbDate || gc.ewbRawData.docDate) {
                  ewbDateStr = gc.ewbRawData.ewayBillDate || gc.ewbRawData.ewbDate || gc.ewbRawData.docDate;
                }
              }
              return {
                id: gc.id,
                'EWB No': gc.ewbNumber || 'PENDING',
                'GC No': gc.gcNumber,
                'EWB Date': ewbDateStr,
                'Valid Upto': validUptoStr,
                'Consignor': gc.consignor?.name || '-',
                'Consignee': gc.consignee?.name || '-',
                'Inv No': gc.invoiceNumber || '-',
                'Inv Date': gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-IN') : '-',
                'Inv Value': parseFloat(gc.invoiceValue || 0).toFixed(2),
                'Status': gc.gdm?.gdmNumber ? 'Assigned' : 'Unassigned',
                _gcObj: gc
              };
            });
          }
        } 
        else if (activeTab === 'gdm') {
          const res = await api.get(`/gdms?${queryParams.toString()}`);
          nextTotalPages = res.totalPages || 1;
          nextTotalRecords = res.total || 0;
          
          finalData = (res.data || []).map(gdm => ({
            id: gdm.id,
            Number: gdm.gdmNumber,
            Date: new Date(gdm.date).toLocaleDateString('en-IN'),
            Vehicle: gdm.vehicle?.vehicleNumber || '-',
            Driver: gdm.driverName || '-',
            Destination: gdm.destination || gdm.toName || '-',
            Status: gdm.status
          }));
        }
      }

      if (append) {
        setReportData(prev => {
          const existingIds = new Set(prev.map(r => r.id || r.Name || r.Vehicle));
          const uniqueNew = finalData.filter(r => !existingIds.has(r.id || r.Name || r.Vehicle));
          return [...prev, ...uniqueNew];
        });
      } else {
        setReportData(finalData);
      }
      setTotalPages(nextTotalPages);
      setTotalRecords(nextTotalRecords);

    } catch (err) {
      console.error("Failed to fetch report data", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchReportData(page, page > 1);
  }, [page, activeTab, dateFrom, dateTo, branch, statusFilter, freightTypeFilter, godownFilter, debouncedSearch]);

  const handleExportCSV = () => {
    if (!reportData.length) return;
    const headers = Object.keys(reportData[0]).filter(k => k !== '_gcObj' && k !== 'id');
    const csvContent = [
      headers.join(','),
      ...reportData.map(row => headers.map(h => `"${row[h] || ''}"`).join(','))
    ].join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement("a");
    const url = URL.createObjectURL(blob);
    link.setAttribute("href", url);
    link.setAttribute("download", `${activeTab}_report_${new Date().toISOString().slice(0,10)}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6 max-w-[1400px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-indigo-100 text-indigo-700 p-2.5 rounded-xl">
            <FileText size={24} />
          </div>
          <div>
            <h1 className="text-2xl font-black text-slate-800 tracking-tight">Reports & Analytics</h1>
            <p className="text-sm font-medium text-slate-500">Comprehensive overview of transport operations</p>
          </div>
        </div>
        
        <button 
          onClick={handleExportCSV}
          disabled={!reportData.length}
          className="flex items-center gap-2 px-4 py-2 bg-slate-900 text-white font-bold rounded-lg hover:bg-slate-800 transition-colors disabled:bg-slate-300 disabled:cursor-not-allowed"
        >
          <Download size={16} /> Export to CSV
        </button>
      </div>

      {/* TOP NAVIGATION TABS */}
      <div className="flex bg-white rounded-xl shadow-sm border border-slate-200 p-1.5 overflow-x-auto hide-scrollbar">
        {[
          { id: 'gc', label: 'GC Report', icon: <Package size={16} /> },
          { id: 'gdm', label: 'GDM Report', icon: <FileText size={16} /> },
          { id: 'ewaybill', label: 'E-Way Bill Report', icon: <CheckCircle2 size={16} /> },
          { id: 'consignor', label: 'Consignor Report', icon: <Building2 size={16} /> },
          { id: 'consignee', label: 'Consignee Report', icon: <Users size={16} /> },
          { id: 'vehicle', label: 'Vehicle Report', icon: <Truck size={16} /> },
        ].map(tab => (
          <button
            key={tab.id}
            onClick={() => { setActiveTab(tab.id); setSearchQuery(''); }}
            className={`flex items-center gap-2 px-6 py-2.5 rounded-lg font-bold text-sm transition-all whitespace-nowrap ${
              activeTab === tab.id 
                ? 'bg-indigo-50 text-indigo-700 shadow-sm border border-indigo-100' 
                : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50 border border-transparent'
            }`}
          >
            {tab.icon} {tab.label}
          </button>
        ))}
      </div>

      {/* FILTER PANEL */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 flex flex-col gap-4">
        
        {/* Row 1: Global Filters */}
        <div className="flex flex-wrap gap-4 items-end">
          <div className="flex flex-col flex-1 min-w-[200px]">
            <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Search</label>
            <input 
              type="text" 
              placeholder="Search data..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 placeholder-slate-400"
            />
          </div>

          <div className="flex flex-col">
            <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Branch</label>
            <select 
              value={branch}
              onChange={(e) => setBranch(e.target.value)}
              className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500"
            >
              <option value="ALL">All Branches</option>
              <option value="MAIN">MAIN</option>
              <option value="MADURAI">MADURAI</option>
              <option value="SIVAKASI">SIVAKASI</option>
            </select>
          </div>

          <div className="flex flex-col">
            <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">From Date</label>
            <input 
              type="date" 
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
              className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500"
            />
          </div>

          <div className="flex flex-col">
            <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">To Date</label>
            <input 
              type="date" 
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
              className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500"
            />
          </div>
        </div>

        {/* Row 2: Advanced Contextual Filters */}
        {(activeTab === 'gc' || activeTab === 'gdm' || activeTab === 'ewaybill') && (
          <div className="flex flex-wrap gap-4 pt-4 border-t border-slate-100">
            <div className="flex flex-col">
              <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Status</label>
              <select 
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500"
              >
                <option value="">All Statuses</option>
                {activeTab === 'gdm' ? (
                  <>
                    <option value="Created">Created</option>
                    <option value="In Transit">In Transit</option>
                    <option value="Delivered">Delivered</option>
                  </>
                ) : (
                  <>
                    <option value="Created">Created</option>
                    <option value="Assigned">Assigned</option>
                    <option value="In Transit">In Transit</option>
                    <option value="Delivered">Delivered</option>
                    <option value="Cancelled">Cancelled</option>
                  </>
                )}
              </select>
            </div>

            {(activeTab === 'gc' || activeTab === 'ewaybill') && (
              <>
                <div className="flex flex-col">
                  <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Freight Type</label>
                  <select 
                    value={freightTypeFilter}
                    onChange={(e) => setFreightTypeFilter(e.target.value)}
                    className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500"
                  >
                    <option value="">All Freight Types</option>
                    <option value="To Pay">To Pay</option>
                    <option value="Paid">Paid</option>
                    <option value="T.B.B.">T.B.B.</option>
                  </select>
                </div>
                <div className="flex flex-col">
                  <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Godown</label>
                  <input 
                    type="text"
                    placeholder="E.g. Godown 1"
                    value={godownFilter}
                    onChange={(e) => setGodownFilter(e.target.value)}
                    className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 placeholder-slate-400"
                  />
                </div>
              </>
            )}

            <button onClick={() => { 
                setDateFrom(''); setDateTo(''); setSearchQuery(''); setBranch('ALL'); setStatusFilter(''); setFreightTypeFilter(''); setGodownFilter('');
              }} 
              className="mt-6 h-10 px-4 text-sm font-bold text-slate-500 hover:text-slate-800 hover:bg-slate-100 rounded-lg transition-colors"
            >
              Clear Filters
            </button>
          </div>
        )}
      </div>

      {/* DATA TABLE */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-100 bg-slate-50/50 flex justify-between items-center">
          <h3 className="font-bold text-slate-800 uppercase tracking-wider text-sm">
            {activeTab.replace('_', ' ')} Data ({totalRecords} records matched)
          </h3>
        </div>
        <div className="overflow-x-auto min-h-[300px]">
          {loading && page === 1 ? (
            <div className="p-10 text-center text-slate-500 font-medium flex items-center justify-center gap-3">
              <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
              Loading Report Data...
            </div>
          ) : (
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
                  {reportData.length > 0 && Object.keys(reportData[0]).filter(k => k !== '_gcObj' && k !== 'id').map(header => (
                    <th key={header} className="p-4">{header}</th>
                  ))}
                </tr>
              </thead>
              <tbody className="text-sm font-semibold text-slate-700 divide-y divide-slate-100">
                {reportData.length === 0 ? (
                  <tr>
                    <td colSpan="10" className="p-8 text-center text-slate-400">No data found for the selected filters.</td>
                  </tr>
                ) : (
                  reportData.map((row, idx) => (
                    <tr key={idx} 
                        onClick={() => { if (activeTab === 'gc' && row._gcObj) setSelectedGc(row._gcObj); }}
                        className={`transition-colors ${activeTab === 'gc' ? 'cursor-pointer hover:bg-indigo-50/60' : 'hover:bg-slate-50'}`}>
                      {Object.entries(row).filter(([k,v]) => k !== '_gcObj' && k !== 'id').map(([k, val], i) => (
                        <td key={i} className={`p-4 ${i === 0 ? 'font-bold text-indigo-900' : ''}`}>
                          {val}
                        </td>
                      ))}
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}
          
          {/* Infinite Scroll Observer */}
          {page < totalPages && (
            <div 
              className="h-16 mt-4 flex items-center justify-center"
              ref={(el) => {
                if (!el) return;
                const observer = new IntersectionObserver(
                  (entries) => {
                    if (entries[0].isIntersecting && !loading) {
                      setPage(p => p + 1);
                    }
                  },
                  { threshold: 1.0 }
                );
                observer.observe(el);
                return () => observer.disconnect();
              }}
            >
              <div className="animate-pulse text-sm font-bold text-slate-500">Loading more rows...</div>
            </div>
          )}
        </div>
      </div>

      {/* GC TRACKING SLIDE PANEL */}
      {selectedGc && (
        <div className="fixed inset-0 z-50 flex justify-end bg-slate-900/40 backdrop-blur-sm transition-all">
          <div className="w-full max-w-md bg-white h-full shadow-2xl flex flex-col animate-in slide-in-from-right duration-300">
            {/* Panel Header */}
            <div className="p-5 border-b border-slate-100 bg-indigo-600 text-white flex justify-between items-center shrink-0">
              <div>
                <h2 className="text-xl font-black tracking-tight flex items-center gap-2"><History size={20} /> GC Tracking Log</h2>
                <p className="text-indigo-200 text-sm font-medium mt-1">Timeline for {selectedGc.gcNumber}</p>
              </div>
              <button onClick={() => setSelectedGc(null)} className="p-2 hover:bg-white/20 rounded-full transition-colors"><X size={20}/></button>
            </div>
            
            <div className="p-6 bg-slate-50 border-b border-slate-200 shrink-0">
              <div className="grid grid-cols-2 gap-4">
                 <div>
                   <p className="text-[10px] font-bold text-slate-500 uppercase">Consignor</p>
                   <p className="font-bold text-sm text-slate-800">{selectedGc.consignor?.name}</p>
                 </div>
                 <div>
                   <p className="text-[10px] font-bold text-slate-500 uppercase">Consignee</p>
                   <p className="font-bold text-sm text-slate-800">{selectedGc.consignee?.name}</p>
                 </div>
                 <div className="col-span-2">
                   <p className="text-[10px] font-bold text-slate-500 uppercase">Current EWB Number</p>
                   <p className="font-mono font-bold text-sm text-indigo-700 bg-indigo-100 px-2 py-1 rounded inline-block mt-1">{selectedGc.ewbNumber ? selectedGc.ewbNumber.replace(/(\d{4})(\d{4})(\d{4})/, '$1 $2 $3') : 'None'}</p>
                 </div>
              </div>
            </div>

            {/* Timeline Content */}
            <div className="flex-1 overflow-y-auto p-6 space-y-6">
              
              {/* Original EWB Generation Event */}
              {selectedGc.ewbRawData && (
                <div className="relative pl-6 border-l-2 border-indigo-200 pb-2">
                  <div className="absolute -left-[9px] top-0 w-4 h-4 bg-amber-500 border-[3px] border-white rounded-full shadow-sm"></div>
                  <p className="text-xs font-bold text-amber-600 uppercase tracking-wider mb-1">{selectedGc.ewbRawData.ewayBillDate || selectedGc.ewbRawData.ewbDate || selectedGc.ewbRawData.docDate || 'Original Date'}</p>
                  <p className="text-sm font-bold text-slate-800">EWB Generated By Consignor</p>
                  <p className="text-xs text-slate-500 mt-1 font-medium">Original E-Way Bill <span className="font-bold text-slate-700">{selectedGc.ewbNumber}</span> created on government portal.</p>
                </div>
              )}
              
              {/* Synthetic Creation Event */}
              <div className="relative pl-6 border-l-2 border-indigo-200 pb-2">
                <div className="absolute -left-[9px] top-0 w-4 h-4 bg-indigo-500 border-[3px] border-white rounded-full shadow-sm"></div>
                <p className="text-xs font-bold text-indigo-500 uppercase tracking-wider mb-1">{new Date(selectedGc.createdAt || selectedGc.date).toLocaleString('en-IN')}</p>
                <p className="text-sm font-bold text-slate-800">GC Drafted</p>
                <p className="text-xs text-slate-500 mt-1">GC {selectedGc.gcNumber} was initiated in the system.</p>
              </div>

              {/* Database Tracking Logs */}
              {selectedGc.trackingLogs && selectedGc.trackingLogs.length > 0 && selectedGc.trackingLogs.map((log, i) => (
                <div key={i} className="relative pl-6 border-l-2 border-indigo-200 pb-2">
                  <div className="absolute -left-[9px] top-0 w-4 h-4 bg-emerald-500 border-[3px] border-white rounded-full shadow-sm"></div>
                  <p className="text-xs font-bold text-emerald-600 uppercase tracking-wider mb-1">{new Date(log.timestamp).toLocaleString('en-IN')}</p>
                  <p className="text-sm font-bold text-slate-800">{log.actionType.replace(/_/g, ' ')}</p>
                  <p className="text-xs text-slate-600 mt-1 font-medium">{log.description}</p>
                  
                  {log.metaData && log.metaData.fromGstin && (
                    <div className="mt-2 p-2 bg-slate-100 rounded border border-slate-200 text-[10px] font-mono text-slate-600">
                      <div><span className="font-bold">EWB Value:</span> ₹{log.metaData.totInvValue}</div>
                      <div><span className="font-bold">EWB Date:</span> {log.metaData.docDate}</div>
                    </div>
                  )}
                </div>
              ))}

              {/* GDM Assignment */}
              {selectedGc.gdm && (
                <div className="relative pl-6 border-l-2 border-indigo-200 pb-2">
                  <div className="absolute -left-[9px] top-0 w-4 h-4 bg-blue-500 border-[3px] border-white rounded-full shadow-sm"></div>
                  <p className="text-xs font-bold text-blue-600 uppercase tracking-wider mb-1">{new Date(selectedGc.gdm.date || selectedGc.gdm.createdAt).toLocaleString('en-IN')}</p>
                  <p className="text-sm font-bold text-slate-800">Assigned to GDM: {selectedGc.gdm.gdmNumber}</p>
                  <p className="text-xs text-slate-600 mt-1 font-medium">Vehicle <span className="font-bold uppercase bg-slate-100 px-1 rounded">{selectedGc.gdm.vehicle?.vehicleNumber}</span> assigned for dispatch.</p>
                </div>
              )}

              {/* End Node */}
              <div className="relative pl-6">
                <div className="absolute -left-[9px] top-0 w-4 h-4 bg-slate-300 border-[3px] border-white rounded-full shadow-sm"></div>
                <p className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">Current State</p>
                <p className="text-sm font-bold text-slate-800">{selectedGc.status}</p>
              </div>

            </div>
          </div>
        </div>
      )}

    </div>
  );
}

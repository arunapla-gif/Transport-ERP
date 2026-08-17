import React, { useState, useEffect, useRef, useCallback } from 'react';
import { api } from '../api';
import { FileText, Calendar, Download, TrendingUp, Truck, Package, IndianRupee, Users, Building2, X, Clock, CheckCircle2, History } from 'lucide-react';
import { Button } from '../components/ui/Button';
import ReportKpiBar from '../components/reports/ReportKpiBar';
import GcTrackingPanel from '../components/reports/GcTrackingPanel';

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
            'GDM No': gdm.gdmNumber,
            Date: new Date(gdm.date).toLocaleDateString('en-IN'),
            Vehicle: gdm.vehicle?.vehicleNumber || '-',
            Driver: gdm.driverName ? `${gdm.driverName} ${gdm.driverPhone ? `(${gdm.driverPhone})` : ''}` : '-',
            'To (Name)': gdm.destination || gdm.toName || '-',
            'CEWB No': gdm.cewbNumber || 'N/A',
            'Total GCs': gdm.gcs ? gdm.gcs.length : 0,
            Freight: gdm.memoAmount ? `₹${parseFloat(gdm.memoAmount).toFixed(2)}` : '₹0.00',
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
        
        <Button variant="custom" 
          onClick={handleExportCSV}
          disabled={!reportData.length}
          className="flex items-center gap-2 px-4 py-2 bg-slate-900 text-white font-bold rounded-lg hover:bg-slate-800 transition-colors disabled:bg-slate-300 disabled:cursor-not-allowed"
        >
          <Download size={16} /> Export to CSV
        </Button>
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
          <Button variant="custom"
            key={tab.id}
            onClick={() => { setActiveTab(tab.id); setSearchQuery(''); }}
            className={`flex items-center gap-2 px-6 py-2.5 rounded-lg font-bold text-sm transition-all whitespace-nowrap ${
              activeTab === tab.id 
                ? 'bg-indigo-50 text-indigo-700 shadow-sm border border-indigo-100' 
                : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50 border border-transparent'
            }`}
          >
            {tab.icon} {tab.label}
          </Button>
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

            <Button variant="custom" onClick={() => { 
                setDateFrom(''); setDateTo(''); setSearchQuery(''); setBranch('ALL'); setStatusFilter(''); setFreightTypeFilter(''); setGodownFilter('');
              }} 
              className="mt-6 h-10 px-4 text-sm font-bold text-slate-500 hover:text-slate-800 hover:bg-slate-100 rounded-lg transition-colors"
            >
              Clear Filters
            </Button>
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

        {/* Real-time KPI Summary */}
        <div className="px-4 pt-4 bg-white">
          <ReportKpiBar activeTab={activeTab} reportData={reportData} />
        </div>

        <div className="overflow-x-auto min-h-[300px]">
          {loading && page === 1 ? (
            <div className="p-10 text-center text-slate-500 font-medium flex items-center justify-center gap-3">
              <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
              Loading Report Data...
            </div>
          ) : (
            <div className="flex flex-col w-full min-w-[800px] border border-slate-200 rounded-lg overflow-hidden">
              {/* Header */}
              <div className="flex bg-slate-100 text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200 shrink-0">
                {reportData.length > 0 && Object.keys(reportData[0]).filter(k => k !== '_gcObj' && k !== 'id').map(header => (
                  <div key={header} className="p-4 flex-1 truncate">{header}</div>
                ))}
              </div>
              
              {/* Standard Scrollable Body */}
              <div className="flex-1 overflow-y-auto max-h-[600px] w-full bg-white relative">
                {reportData.length === 0 ? (
                  <div className="p-8 text-center text-slate-400">No data found for the selected filters.</div>
                ) : (
                  <div className="w-full flex flex-col">
                    {reportData.map((row, index) => (
                      <div 
                        key={row.id || index}
                        onClick={() => { if (activeTab === 'gc' && row._gcObj) setSelectedGc(row._gcObj); }}
                        className={`flex items-center min-h-[55px] text-sm font-semibold text-slate-700 transition-colors border-b border-slate-100 ${activeTab === 'gc' ? 'cursor-pointer hover:bg-indigo-50' : 'hover:bg-slate-50'}`}
                      >
                        {Object.entries(row).filter(([k]) => k !== '_gcObj' && k !== 'id').map(([k, val], i) => (
                          <div key={i} className={`px-4 flex-1 truncate ${i === 0 ? 'font-bold text-indigo-900' : ''}`}>
                            {val}
                          </div>
                        ))}
                      </div>
                    ))}
                    
                    {/* Infinite Scroll Observer Placed INSIDE the scrollable container */}
                    {page < totalPages && (
                      <div 
                        className="h-16 flex shrink-0 items-center justify-center w-full"
                        ref={(el) => {
                          if (!el) return;
                          const observer = new IntersectionObserver(
                            (entries) => {
                              if (entries[0].isIntersecting && !loading) {
                                setPage(p => p + 1);
                              }
                            }, 
                            { threshold: 0.1 }
                          );
                          observer.observe(el);
                          return () => observer.disconnect();
                        }}
                      >
                        <div className="animate-spin h-6 w-6 border-b-2 border-indigo-600 rounded-full"></div>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* GC TRACKING SLIDE PANEL */}
      <GcTrackingPanel 
        selectedGc={selectedGc} 
        onClose={() => setSelectedGc(null)} 
      />

    </div>
  );
}

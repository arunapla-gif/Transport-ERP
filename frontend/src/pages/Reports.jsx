import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { FileText, Calendar, Download, TrendingUp, Truck, Package, IndianRupee, Users, Building2, X, Clock, CheckCircle2, History } from 'lucide-react';

export default function Reports() {
  const [activeTab, setActiveTab] = useState('gc'); // gc, gdm, consignor, consignee, vehicle
  const [selectedGc, setSelectedGc] = useState(null);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  
  // Generic Filters
  const [searchQuery, setSearchQuery] = useState('');

  const [loading, setLoading] = useState(false);
  const [rawGcs, setRawGcs] = useState([]);
  const [rawGdms, setRawGdms] = useState([]);

  // Computed data for the current tab
  const [reportData, setReportData] = useState([]);

  // Fetch all core data once
  useEffect(() => {
    const fetchAll = async () => {
      setLoading(true);
      try {
        const [gcs, gdms] = await Promise.all([
          api.get('/gcs'),
          api.get('/gdms')
        ]);
        setRawGcs(gcs || []);
        setRawGdms(gdms || []);
      } catch (err) {
        console.error("Failed to fetch report data", err);
      } finally {
        setLoading(false);
      }
    };
    fetchAll();
  }, []);

  // Process data based on active tab and filters
  useEffect(() => {
    processData();
  }, [rawGcs, rawGdms, activeTab, dateFrom, dateTo, searchQuery]);

  const processData = () => {
    // 1. Date Filtering Helper
    const isWithinDate = (dateStr) => {
      if (!dateStr) return false;
      const d = new Date(dateStr);
      d.setHours(0, 0, 0, 0);
      let valid = true;
      if (dateFrom) {
        const f = new Date(dateFrom);
        f.setHours(0,0,0,0);
        valid = valid && d >= f;
      }
      if (dateTo) {
        const t = new Date(dateTo);
        t.setHours(23,59,59,999);
        valid = valid && d <= t;
      }
      return valid;
    };

    // 2. Filter Raw Data
    const filteredGcs = rawGcs.filter(gc => isWithinDate(gc.date));
    const filteredGdms = rawGdms.filter(gdm => isWithinDate(gdm.date));

    // 3. Search Helper
    const matchesSearch = (str) => {
      if (!searchQuery) return true;
      return str && str.toLowerCase().includes(searchQuery.toLowerCase());
    };

    // 4. Generate Specific Reports
    let finalData = [];

    if (activeTab === 'gc') {
      finalData = filteredGcs.map(gc => {
        const totalArticles = gc.goods ? gc.goods.reduce((acc, curr) => acc + (parseInt(curr.articleCount) || 0), 0) : 0;
        return {
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
      }).filter(r => matchesSearch(r.Number) || matchesSearch(r.Consignor) || matchesSearch(r.Consignee) || matchesSearch(r.Vehicle) || matchesSearch(r.GDM_No));
    }

    else if (activeTab === 'gdm') {
      finalData = filteredGdms.map(gdm => ({
        Number: gdm.gdmNumber,
        Date: new Date(gdm.date).toLocaleDateString('en-IN'),
        Vehicle: gdm.vehicle?.vehicleNumber || '-',
        Driver: gdm.driverName || '-',
        Destination: gdm.destination || gdm.toName || '-',
        Status: gdm.status
      })).filter(r => matchesSearch(r.Number) || matchesSearch(r.Vehicle) || matchesSearch(r.Destination));
    }

    else if (activeTab === 'ewaybill') {
      finalData = filteredGcs.map(gc => {
        let validUptoStr = '-';
        let ewbDateStr = '-';
        if (gc.ewbRawData) {
          if (gc.ewbRawData.validUpto) validUptoStr = gc.ewbRawData.validUpto;
          if (gc.ewbRawData.ewayBillDate || gc.ewbRawData.ewbDate || gc.ewbRawData.docDate) {
            ewbDateStr = gc.ewbRawData.ewayBillDate || gc.ewbRawData.ewbDate || gc.ewbRawData.docDate;
          }
        }
        return {
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
      }).filter(r => matchesSearch(r['EWB No']) || matchesSearch(r['GC No']) || matchesSearch(r.Consignor) || matchesSearch(r.Consignee));
    }

    else if (activeTab === 'consignor') {
      const map = {};
      filteredGcs.forEach(gc => {
        const name = gc.consignor?.name || 'Unknown';
        if (!map[name]) map[name] = { Name: name, TotalGCs: 0, TotalWeight: 0, TotalFreight: 0 };
        map[name].TotalGCs += 1;
        map[name].TotalFreight += parseFloat(gc.freightTotal || 0);
        gc.goods?.forEach(g => { map[name].TotalWeight += parseFloat(g.weight || 0); });
      });
      finalData = Object.values(map)
        .map(r => ({ ...r, TotalFreight: r.TotalFreight.toFixed(2), TotalWeight: r.TotalWeight.toFixed(2) }))
        .filter(r => matchesSearch(r.Name));
    }

    else if (activeTab === 'consignee') {
      const map = {};
      filteredGcs.forEach(gc => {
        const name = gc.consignee?.name || 'Unknown';
        if (!map[name]) map[name] = { Name: name, TotalGCs: 0, TotalWeight: 0, TotalFreight: 0 };
        map[name].TotalGCs += 1;
        map[name].TotalFreight += parseFloat(gc.freightTotal || 0);
        gc.goods?.forEach(g => { map[name].TotalWeight += parseFloat(g.weight || 0); });
      });
      finalData = Object.values(map)
        .map(r => ({ ...r, TotalFreight: r.TotalFreight.toFixed(2), TotalWeight: r.TotalWeight.toFixed(2) }))
        .filter(r => matchesSearch(r.Name));
    }

    else if (activeTab === 'vehicle') {
      const map = {};
      filteredGdms.forEach(gdm => {
        const veh = gdm.vehicle?.vehicleNumber || 'Unknown';
        if (!map[veh]) map[veh] = { Vehicle: veh, TotalTrips: 0, TotalAdvance: 0, TotalBalance: 0 };
        map[veh].TotalTrips += 1;
        map[veh].TotalAdvance += parseFloat(gdm.advanceAmount || 0);
        map[veh].TotalBalance += parseFloat(gdm.balanceAmount || 0);
      });
      finalData = Object.values(map)
        .map(r => ({ ...r, TotalAdvance: r.TotalAdvance.toFixed(2), TotalBalance: r.TotalBalance.toFixed(2) }))
        .filter(r => matchesSearch(r.Vehicle));
    }

    setReportData(finalData);
  };

  const handleExportCSV = () => {
    if (!reportData.length) return;
    const headers = Object.keys(reportData[0]).filter(k => k !== '_gcObj');
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
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-5 flex flex-wrap gap-6 items-end">
        <div className="flex flex-col flex-1 min-w-[250px]">
          <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-2">Search Report</label>
          <input 
            type="text" 
            placeholder={
              activeTab === 'gc' ? "Search GC, Consignor, Consignee..." :
              activeTab === 'gdm' ? "Search GDM, Vehicle, Destination..." :
              activeTab === 'vehicle' ? "Search Vehicle Number..." :
              activeTab === 'ewaybill' ? "Search EWB, GC, Consignor..." :
              "Search Name..."
            }
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="h-10 px-3 bg-white border border-slate-200 rounded-lg text-sm font-semibold text-slate-800 focus:outline-none focus:border-indigo-500 placeholder-slate-400"
          />
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

        <button onClick={() => { setDateFrom(''); setDateTo(''); setSearchQuery(''); }} className="h-10 px-4 text-sm font-bold text-slate-500 hover:text-slate-800 hover:bg-slate-100 rounded-lg transition-colors">
          Clear
        </button>
      </div>

      {/* DATA TABLE */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        <div className="p-4 border-b border-slate-100 bg-slate-50/50 flex justify-between items-center">
          <h3 className="font-bold text-slate-800 uppercase tracking-wider text-sm">
            {activeTab.replace('_', ' ')} Data ({reportData.length} records)
          </h3>
        </div>
        <div className="overflow-x-auto">
          {loading ? (
            <div className="p-10 text-center text-slate-500 font-medium flex items-center justify-center gap-3">
              <div className="w-5 h-5 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
              Loading Report Data...
            </div>
          ) : (
            <table className="w-full text-left border-collapse whitespace-nowrap">
              <thead>
                <tr className="bg-white text-[10px] font-extrabold text-slate-500 uppercase tracking-wider border-b border-slate-200">
                  {reportData.length > 0 && Object.keys(reportData[0]).filter(k => k !== '_gcObj').map(header => (
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
                      {Object.entries(row).filter(([k,v]) => k !== '_gcObj').map(([k, val], i) => (
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

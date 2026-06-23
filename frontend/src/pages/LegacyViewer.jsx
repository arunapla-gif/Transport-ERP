import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { Database, Search, Download, ArrowRight, UserCheck } from 'lucide-react';

export default function LegacyViewer() {
  const [companies, setCompanies] = useState([]);
  const [selectedCompany, setSelectedCompany] = useState('');
  const [financialYears, setFinancialYears] = useState([]);
  const [selectedFy, setSelectedFy] = useState('');
  const [activeTab, setActiveTab] = useState('consignors'); // consignors, consignees, transactions
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [visibleCount, setVisibleCount] = useState(100);
  const [selectedRow, setSelectedRow] = useState(null);

  useEffect(() => {
    fetchCompanies();
  }, []);

  useEffect(() => {
    if (selectedCompany) {
      fetchFinancialYears();
    }
  }, [selectedCompany]);

  useEffect(() => {
    if (selectedCompany) {
      fetchData();
      setVisibleCount(100); // Reset visible count on tab/company change
    }
  }, [selectedCompany, activeTab, selectedFy]);

  const fetchCompanies = async () => {
    try {
      const res = await api.get('/legacy-mdb/companies');
      setCompanies(res.companies);
      if (res.companies.length > 0) setSelectedCompany(res.companies[0]);
    } catch (err) {
      toast.error('Failed to load MS Access folders');
    }
  };

  const fetchFinancialYears = async () => {
    try {
      const res = await api.get(`/legacy-mdb/${encodeURIComponent(selectedCompany)}/financial-years`);
      setFinancialYears(res.years || []);
      if (res.years && res.years.length > 0) {
        setSelectedFy(res.years[0]);
      } else {
        setSelectedFy('');
      }
    } catch (err) {
      toast.error('Failed to load financial years');
    }
  };

  const fetchData = async () => {
    setLoading(true);
    setData([]);
    try {
      const query = (activeTab === 'transactions' || activeTab === 'gdms' || activeTab === 'vehicles') && selectedFy 
        ? `?fy=${encodeURIComponent(selectedFy)}` 
        : '';
      const res = await api.get(`/legacy-mdb/${encodeURIComponent(selectedCompany)}/${activeTab}${query}`);
      setData(res.data);
    } catch (err) {
      toast.error(`Failed to load ${activeTab} from MS Access`);
    } finally {
      setLoading(false);
    }
  };

  const filteredData = data.filter(row => {
    if (!searchTerm) return true;
    const term = searchTerm.toLowerCase();
    // Search across all string values in the object
    return Object.values(row).some(val => 
      val && val.toString().toLowerCase().includes(term)
    );
  });

  const handleRefine = (row) => {
    toast.success('Refine mapping popup will open here (coming soon!)');
    console.log("Data to refine:", row);
  };

  const safeFormatDate = (dateVal) => {
    if (!dateVal) return '';
    // If it's already DD-MM-YYYY like "01-04-2026", just return it
    if (typeof dateVal === 'string' && /^\d{2}-\d{2}-\d{4}$/.test(dateVal.trim())) {
      return dateVal.trim();
    }
    // Otherwise try parsing it
    try {
      const d = new Date(dateVal);
      if (isNaN(d.getTime())) return String(dateVal); // Fallback to raw string if invalid
      return d.toLocaleDateString('en-GB'); // en-GB forces DD/MM/YYYY
    } catch (e) {
      return String(dateVal);
    }
  };

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl md:text-3xl font-black text-slate-800 tracking-tight flex items-center gap-3">
            <Database className="text-indigo-600" size={28} />
            Legacy ERP Viewer
          </h1>
          <p className="text-sm font-bold text-slate-500 mt-1">
            Direct live connection to Jelly MS Access (.mdb) files.
          </p>
        </div>

        <div className="flex gap-2">
          {(activeTab === 'transactions' || activeTab === 'gdms' || activeTab === 'vehicles') && (
            <select 
              value={selectedFy} 
              onChange={e => setSelectedFy(e.target.value)}
              className="h-10 px-3 bg-white border border-slate-300 rounded-lg text-sm font-bold text-slate-700 shadow-sm focus:ring-2 focus:ring-indigo-500 outline-none"
            >
              <option value="">All Years</option>
              {financialYears.length > 0 
                ? financialYears.map(fy => <option key={fy} value={fy}>{fy}</option>)
                : <option disabled>No years found</option>
              }
            </select>
          )}
          <select 
            value={selectedCompany} 
            onChange={e => setSelectedCompany(e.target.value)}
            className="h-10 px-3 bg-white border border-slate-300 rounded-lg text-sm font-bold text-slate-700 shadow-sm focus:ring-2 focus:ring-indigo-500 outline-none"
          >
            {companies.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
      </div>

      <div className="bg-white border border-slate-200 rounded-xl shadow-sm overflow-hidden flex flex-col h-[calc(100vh-200px)] min-h-[500px]">
        {/* Tabs & Search */}
        <div className="flex flex-col md:flex-row md:items-center justify-between p-4 border-b border-slate-100 gap-4 bg-slate-50/50">
          <div className="flex p-1 bg-slate-200/50 rounded-lg w-fit">
            <button 
              onClick={() => setActiveTab('consignors')}
              className={`px-4 py-1.5 rounded-md text-sm font-bold transition-all ${activeTab === 'consignors' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
            >
              Consignors
            </button>
            <button 
              onClick={() => setActiveTab('consignees')}
              className={`px-4 py-1.5 rounded-md text-sm font-bold transition-all ${activeTab === 'consignees' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
            >
              Consignees
            </button>
            <button 
              onClick={() => setActiveTab('vehicles')}
              className={`px-4 py-1.5 rounded-md text-sm font-bold transition-all ${activeTab === 'vehicles' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
            >
              Vehicles
            </button>
            <button 
              onClick={() => setActiveTab('transactions')}
              className={`px-4 py-1.5 rounded-md text-sm font-bold transition-all ${activeTab === 'transactions' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
            >
              GCs
            </button>
            <button 
              onClick={() => setActiveTab('gdms')}
              className={`px-4 py-1.5 rounded-md text-sm font-bold transition-all ${activeTab === 'gdms' ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-800'}`}
            >
              GDMs
            </button>
          </div>

          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={16} />
            <input 
              type="text" 
              placeholder="Search legacy records..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full md:w-64 pl-9 pr-3 h-9 bg-white border border-slate-300 rounded-md text-sm font-bold focus:ring-2 focus:ring-indigo-500 outline-none transition-all shadow-sm"
            />
          </div>
        </div>

        {/* Data Table */}
        <div className="flex-1 overflow-auto bg-slate-50 relative p-4">
          {loading ? (
            <div className="absolute inset-0 flex items-center justify-center bg-white/80 backdrop-blur-sm z-10">
              <div className="flex flex-col items-center">
                <div className="w-10 h-10 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin mb-3"></div>
                <p className="text-sm font-bold text-indigo-900">Reading MS Access (.mdb)...</p>
              </div>
            </div>
          ) : filteredData.length === 0 ? (
            <div className="h-full flex flex-col items-center justify-center text-slate-400">
              <Database size={48} className="mb-4 opacity-20" />
              <p className="font-bold text-lg">No records found</p>
            </div>
          ) : (
            <div className="grid gap-3 grid-cols-1 lg:grid-cols-2">
              {filteredData.slice(0, visibleCount).map((row, i) => (
                <div 
                  key={i} 
                  onClick={() => setSelectedRow(row)}
                  className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col justify-between group hover:border-indigo-400 hover:shadow-md cursor-pointer transition-all"
                >
                  <div>
                    {/* Render different UI based on tab */}
                    {activeTab === 'consignors' && (
                      <>
                        <div className="flex items-start justify-between mb-2">
                          <h3 className="font-black text-slate-800 text-lg leading-tight">{row.ConsignorName || 'UNKNOWN'}</h3>
                          <span className="text-xs font-bold px-2 py-1 bg-slate-100 text-slate-500 rounded-md whitespace-nowrap ml-2">ID: {row.ConsignorID}</span>
                        </div>
                        <p className="text-sm font-bold text-slate-500 mb-1">{[row.Address, row.Street_Area, row.City_Village].filter(Boolean).join(', ')}</p>
                        {row.GSTIN && <p className="text-xs font-bold text-emerald-600 mt-2 bg-emerald-50 w-fit px-2 py-0.5 rounded">GST: {row.GSTIN}</p>}
                      </>
                    )}

                    {activeTab === 'consignees' && (
                      <>
                        <div className="flex items-start justify-between mb-2">
                          <h3 className="font-black text-slate-800 text-lg leading-tight">{row.ConsigneeName || 'UNKNOWN'}</h3>
                          <span className="text-xs font-bold px-2 py-1 bg-slate-100 text-slate-500 rounded-md whitespace-nowrap ml-2">ID: {row.ConsigneeID}</span>
                        </div>
                        <p className="text-sm font-bold text-slate-500 mb-1">{[row.Address, row.Street_Area, row.City_Village].filter(Boolean).join(', ')}</p>
                        {row.GSTIN && <p className="text-xs font-bold text-emerald-600 mt-2 bg-emerald-50 w-fit px-2 py-0.5 rounded">GST: {row.GSTIN}</p>}
                      </>
                    )}

                    {activeTab === 'transactions' && (
                      <>
                        <div className="flex items-start justify-between mb-2">
                          <h3 className="font-black text-slate-800 text-lg">GC No: {row.Billno}</h3>
                          <span className="text-xs font-bold px-2 py-1 bg-amber-100 text-amber-700 rounded-md">
                            {safeFormatDate(row.Date)}
                          </span>
                        </div>
                        <div className="flex items-center gap-2 text-sm font-bold text-slate-600">
                          <span className="truncate max-w-[120px]" title={row.Fromname}>{row.Fromname || 'Unknown Sender'}</span>
                          <ArrowRight size={14} className="text-slate-300 flex-shrink-0" />
                          <span className="truncate max-w-[120px]" title={row.Toname}>{row.Toname || 'Unknown Receiver'}</span>
                        </div>
                        <p className="text-xs font-bold text-slate-400 mt-2">
                          {row.FromCity || 'Unknown'} ➔ {row.ToCity2 || 'Unknown'} | Freight: ₹{row.Total || '0'} ({row.Paymenttype})
                        </p>
                      </>
                    )}

                    {activeTab === 'vehicles' && (
                      <>
                        <div className="flex items-start justify-between mb-2">
                          <h3 className="font-black text-slate-800 text-lg">{row.LorryNo}</h3>
                          {row.LorryName && <span className="text-xs font-bold px-2 py-1 bg-blue-100 text-blue-700 rounded-md">{row.LorryName}</span>}
                        </div>
                        <p className="text-sm font-bold text-slate-600">Driver: {row.DriverName || 'N/A'}</p>
                        <p className="text-xs font-bold text-slate-400 mt-1">Contact: {row.Cell || 'N/A'}</p>
                      </>
                    )}

                    {activeTab === 'gdms' && (
                      <>
                        <div className="flex items-start justify-between mb-2">
                          <h3 className="font-black text-slate-800 text-lg">GDM ID: {row.ID}</h3>
                          <span className="text-xs font-bold px-2 py-1 bg-emerald-100 text-emerald-700 rounded-md">
                            {safeFormatDate(row.Date)}
                          </span>
                        </div>
                        <p className="text-sm font-bold text-slate-600">Lorry: {row.LorryNo || 'N/A'}</p>
                        <p className="text-xs font-bold text-slate-400 mt-1">Driver: {row.DriverName} | Ph: {row.Cell}</p>
                      </>
                    )}
                  </div>

                  <div className="mt-4 pt-3 border-t border-slate-100 flex justify-between items-center">
                    <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Click card for details</span>
                    <button 
                      onClick={(e) => { e.stopPropagation(); handleRefine(row); }}
                      className="text-xs font-black text-indigo-600 bg-indigo-50 hover:bg-indigo-600 hover:text-white px-3 py-1.5 rounded-md transition-all flex items-center gap-1.5"
                    >
                      <UserCheck size={14} />
                      Refine & Import
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
          
          {filteredData.length > visibleCount && (
            <div className="flex justify-center mt-6 mb-4">
              <button 
                onClick={() => setVisibleCount(prev => prev + 100)}
                className="px-6 py-2 bg-white border border-slate-300 text-slate-600 font-bold rounded-lg shadow-sm hover:bg-slate-50 transition-colors"
              >
                Load More (+100)
              </button>
            </div>
          )}
          
          <div className="text-center py-4 text-xs font-bold text-slate-400">
            Showing {Math.min(filteredData.length, visibleCount)} of {filteredData.length} records.
          </div>
        </div>
      </div>

      {/* DETAILED VIEW MODAL */}
      {selectedRow && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-slate-900/40 backdrop-blur-sm p-4 animate-in fade-in duration-200">
          <div className="bg-white w-full max-w-3xl rounded-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden animate-in zoom-in-95 duration-200">
            <div className="px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-slate-50">
              <h2 className="text-xl font-black text-slate-800 flex items-center gap-2">
                <Database className="text-indigo-600" size={24} />
                Raw MS Access Record
              </h2>
              <button 
                onClick={() => setSelectedRow(null)}
                className="w-8 h-8 flex items-center justify-center rounded-full hover:bg-slate-200 text-slate-500 transition-colors"
              >
                ✕
              </button>
            </div>
            
            <div className="p-6 overflow-y-auto flex-1 bg-slate-50/50">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-3">
                {Object.entries(selectedRow).map(([key, value]) => (
                  <div key={key} className="bg-white p-3 rounded-lg border border-slate-200 shadow-sm">
                    <div className="text-[10px] font-black text-slate-400 uppercase tracking-widest mb-1">{key}</div>
                    <div className="text-sm font-bold text-slate-700 break-words">
                      {value === null || value === '' ? <span className="text-slate-300 italic">EMPTY</span> : String(value)}
                    </div>
                  </div>
                ))}
              </div>
            </div>
            
            <div className="px-6 py-4 border-t border-slate-100 flex justify-between items-center bg-white">
              <p className="text-xs font-bold text-slate-400">Displaying exact fields extracted from .mdb file</p>
              <div className="flex gap-3">
                <button 
                  onClick={() => setSelectedRow(null)}
                  className="px-4 py-2 rounded-lg font-bold text-slate-600 hover:bg-slate-100 transition-colors"
                >
                  Close
                </button>
                <button 
                  onClick={() => {
                    handleRefine(selectedRow);
                    setSelectedRow(null);
                  }}
                  className="px-4 py-2 rounded-lg font-black text-white bg-indigo-600 hover:bg-indigo-700 shadow-sm transition-colors flex items-center gap-2"
                >
                  <UserCheck size={16} />
                  Refine & Import
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

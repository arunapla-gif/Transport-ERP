import React, { useState, useEffect } from 'react';
import { api } from '../api';
import { Package, Truck, MapPin, Calendar, FileText } from 'lucide-react';

export default function WarehouseStatement() {
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [inwards, setInwards] = useState([]);
  const [loading, setLoading] = useState(true);

  const fetchInwards = async () => {
    try {
      setLoading(true);
      const data = await api.get(`/warehouse-inward?date=${date}`);
      setInwards(data || []);
    } catch (err) {
      console.error('Failed to fetch inwards', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchInwards();
  }, [date]);

  const totalArticles = inwards.reduce((sum, item) => sum + (item.articles || 0), 0);

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="max-w-6xl mx-auto py-6 px-4 print:p-0 print:m-0 print:max-w-none" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      <style>
        {`
          @media print {
            @page { 
              size: A4 landscape; 
              margin: 10mm; 
            }
          }
        `}
      </style>
      
      {/* Header & Controls */}
      <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 mb-6 print:hidden">
        <div>
          <h1 className="text-2xl font-black text-slate-800">Warehouse Daily Statement</h1>
          <p className="text-sm font-bold text-slate-500 mt-1">Review inward entries for the selected date</p>
        </div>
        
        <div className="flex gap-3 items-end">
          <div className="flex flex-col">
            <label className="text-xs font-bold text-slate-500 uppercase tracking-wider mb-1">Select Date</label>
            <div className="relative">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Calendar size={16} className="text-indigo-500" />
              </div>
              <input 
                type="date"
                value={date}
                onChange={e => setDate(e.target.value)}
                className="h-10 pl-10 pr-4 bg-white border border-slate-200 rounded-lg text-sm font-bold text-slate-700 shadow-sm outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"
              />
            </div>
          </div>
          <button 
            onClick={handlePrint}
            className="h-10 px-4 bg-slate-800 hover:bg-slate-700 text-white rounded-lg font-bold text-sm shadow-sm flex items-center gap-2 transition-all active:scale-95"
          >
            <FileText size={16} /> Print Report
          </button>
        </div>
      </div>

      {/* Summary Cards (Hidden in Print) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6 print:hidden">
        <div className="bg-gradient-to-br from-indigo-50 to-white p-5 rounded-xl border border-indigo-100 shadow-sm">
          <p className="text-xs font-bold text-indigo-500 uppercase tracking-wider">Total Entries</p>
          <p className="text-3xl font-black text-indigo-900 mt-1">{inwards.length}</p>
        </div>
        <div className="bg-gradient-to-br from-emerald-50 to-white p-5 rounded-xl border border-emerald-100 shadow-sm">
          <p className="text-xs font-bold text-emerald-500 uppercase tracking-wider">Total Articles Inwarded</p>
          <p className="text-3xl font-black text-emerald-900 mt-1">{totalArticles}</p>
        </div>
      </div>

      {/* Print-Only Header */}
      <div className="hidden print:flex justify-between items-end border-b-2 border-black pb-1 mb-2">
        <h1 className="text-[14px] font-black text-black leading-none">DAILY INWARD STATEMENT</h1>
        <p className="text-[10px] font-bold text-gray-800 leading-none">Date: {new Date(date).toLocaleDateString('en-IN')}</p>
      </div>

      {/* Main Table */}
      <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden print:shadow-none print:border-black">
        {loading ? (
          <div className="p-10 text-center text-slate-500 font-bold animate-pulse">Loading data...</div>
        ) : inwards.length === 0 ? (
          <div className="p-10 text-center text-slate-500 font-bold">No inward entries found for this date.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-slate-50 border-b border-slate-200 print:bg-gray-100 print:border-black print:border-b-2">
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider w-16 print:text-black">Rec No.</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider print:text-black">Consignor (From)</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider print:text-black">Consignee (To)</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider print:text-black">City</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider text-right print:text-black">Articles</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider text-center print:text-black">Godown</th>
                  <th className="px-4 py-3 print:px-1 print:py-0.5 text-xs print:text-[9px] font-bold text-slate-500 uppercase tracking-wider print:text-black">Remarks</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 print:divide-gray-400">
                {inwards.map((item, index) => (
                  <tr key={item.id} className="hover:bg-slate-50/50 transition-colors print:border-b print:border-gray-400">
                    <td className="px-4 py-3 print:px-1 print:py-0.5 text-sm print:text-[10px] font-bold text-slate-800 print:text-black">{item.receiptNo || '-'}</td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5">
                      <div className="flex items-start gap-2">
                        <Truck size={14} className="text-blue-400 mt-1 print:hidden" />
                        <div className="print:leading-[1]">
                          <span className="text-sm print:text-[10px] font-bold text-slate-800 print:text-black">{item.consignorName}</span>
                          {item.ewayBillNo && <span className="hidden print:inline text-[9px] font-bold text-gray-700 ml-1">(EWB: {item.ewayBillNo})</span>}
                          {item.ewayBillNo && <p className="text-[10px] font-bold text-slate-400 print:hidden">EWB: {item.ewayBillNo}</p>}
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5">
                      <div className="flex items-start gap-2">
                        <MapPin size={14} className="text-emerald-400 mt-1 print:hidden" />
                        <div className="print:leading-[1]">
                          <span className="text-sm print:text-[10px] font-bold text-slate-800 print:text-black">{item.consigneeName}</span>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5">
                      <span className="text-sm print:text-[9px] font-bold text-slate-500 print:text-gray-800">
                        {item.consigneeCity}
                      </span>
                    </td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5 text-right">
                      <span className="text-sm print:text-[10px] font-black text-indigo-600 bg-indigo-50 px-2.5 py-1 rounded-md border border-indigo-100 print:border-none print:bg-transparent print:p-0 print:text-black">
                        {item.articles}
                      </span>
                    </td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5 text-center">
                      <span className="inline-block px-2 py-1 bg-amber-50 text-amber-700 text-xs font-bold border border-amber-200 rounded print:border-none print:p-0 print:bg-transparent print:text-black print:text-[10px]">
                        {item.godownNo ? item.godownNo.replace(/[^0-9]/g, '') : ''}
                      </span>
                    </td>
                    <td className="px-4 py-3 print:px-1 print:py-0.5">
                      <span className="text-sm print:text-[9px] font-medium text-slate-500 print:text-gray-700 truncate max-w-[120px] print:max-w-[80px] inline-block">
                        {item.remarks || '-'}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot className="bg-slate-50 border-t-2 border-slate-200 print:border-t-2 print:border-black">
                <tr>
                  <td colSpan="4" className="px-4 py-3 print:px-1 print:py-1 text-right text-xs print:text-[10px] font-bold text-slate-500 uppercase tracking-wider print:text-black">Total Articles:</td>
                  <td className="px-4 py-3 print:px-1 print:py-1 text-right text-lg print:text-[12px] font-black text-indigo-900 print:text-black">{totalArticles}</td>
                  <td colSpan="2" className="print:hidden"></td>
                </tr>
              </tfoot>
            </table>
          </div>
        )}
      </div>

      {/* Print Footer */}
      <div className="hidden print:flex justify-between mt-2 px-4">
        <div className="text-[9px] font-bold text-black border-t border-black pt-1 w-32 text-center">Clerk Signature</div>
        <div className="text-[9px] font-bold text-black border-t border-black pt-1 w-32 text-center">Manager Signature</div>
      </div>
      
    </div>
  );
}

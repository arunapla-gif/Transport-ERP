import React, { useState, useEffect, useMemo } from 'react';
import { api } from '../api';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { SearchableSelect } from '../components/ui/SearchableSelect';
import { Save, Plus, Trash2, MapPin, Building2, Receipt, Package, Wallet, FileText, Truck } from 'lucide-react';

// Specialized compact input primitives for the Premium layout
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <select 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value || opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

// Overriding SearchableSelect classes for premium dense layout
const denseSearchableSelectClass = "[&>label]:!text-[10px] [&>label]:!font-bold [&>label]:!text-slate-500 [&>label]:!mb-0.5 [&>div]:!h-9 [&>div]:!min-h-0 [&>div]:!py-0 [&>div]:!rounded-lg [&>div]:!border-slate-200 [&>div]:!bg-white/50 [&>div]:!shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] [&>div:focus-within]:!border-indigo-500 [&>div:focus-within]:!ring-2 [&>div:focus-within]:!ring-indigo-500/20 [&>div>input]:!text-sm [&>div>input]:!font-medium [&>div>input]:!text-slate-800 [&>div>div]:!text-sm [&>div>div]:!font-medium [&>div>svg]:!w-4 [&>div>svg]:!h-4 [&:hover>div]:!border-slate-300 [&:focus-within>label]:!text-indigo-600 [&>label]:transition-colors";

// Glassmorphic Card Wrapper Component
const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function LorryAccounts() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Bill Meta
  const [billMeta, setBillMeta] = useState({
    billNumber: '',
    date: new Date().toISOString().split('T')[0],
  });

  // Trip Details
  const [tripDetails, setTripDetails] = useState({
    transporterName: '',
    lorryNumber: '',
    fromLocation: '',
    toLocation: '',
    gcNumbers: '',
  });

  // Financials
  const [financials, setFinancials] = useState({
    grossFreight: '',
    advancePaid: '',
    commission: '',
    shortage: '',
    tds: '',
    paymentMode: 'Cash',
    remarks: ''
  });

  // Calculate Net Balance dynamically
  const netBalance = useMemo(() => {
    const gross = Number(financials.grossFreight) || 0;
    const advance = Number(financials.advancePaid) || 0;
    const comm = Number(financials.commission) || 0;
    const short = Number(financials.shortage) || 0;
    const tdsAmt = Number(financials.tds) || 0;
    
    return gross - advance - comm - short - tdsAmt;
  }, [financials]);

  // Hook for full keyboard flow!
  useKeyboardFlow();

  const handleSave = async () => {
    try {
      setLoading(true);
      setError('');
      setSuccess('');

      const payload = {
        ...billMeta,
        ...tripDetails,
        ...financials,
        netBalance
      };

      await api.post('/freight-bills', payload);
      setSuccess('Lorry Account Saved Successfully!');
      handleReset();
      
      setTimeout(() => setSuccess(''), 3000);
    } catch (err) {
      setError(err.error || err.message || 'Failed to save Lorry Account');
    } finally {
      setLoading(false);
    }
  };

  const handleReset = () => {
    setBillMeta({
      billNumber: '',
      date: new Date().toISOString().split('T')[0],
    });
    setTripDetails({
      transporterName: '',
      lorryNumber: '',
      fromLocation: '',
      toLocation: '',
      gcNumbers: '',
    });
    setFinancials({
      grossFreight: '',
      advancePaid: '',
      commission: '',
      shortage: '',
      tds: '',
      paymentMode: 'Cash',
      remarks: ''
    });
  };

  return (
    <div className="space-y-3 max-w-[1000px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* 1. TOP RIBBON */}
      <GlassCard>
        <div className="flex flex-wrap gap-3 items-end justify-between">
          <div className="flex gap-3 items-end">
            <DenseInput label="Bill Number" value={billMeta.billNumber} onChange={e => setBillMeta({...billMeta, billNumber: e.target.value})} className="w-32 [&>input]:font-black [&>input]:text-indigo-900 [&>input]:bg-indigo-50/50 [&>input]:border-indigo-200" autoFocus />
            <DenseInput label="Date" type="date" value={billMeta.date} onChange={e => setBillMeta({...billMeta, date: e.target.value})} className="w-32" />
          </div>
          <div className="flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50/80 rounded-lg border border-indigo-100/50">
            <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Status:</span>
            <div className="flex items-center gap-1 text-xs font-bold text-indigo-600">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 animate-pulse"></span>
              Draft
            </div>
          </div>
        </div>
      </GlassCard>

      {error && <div className="px-5 py-3 bg-rose-50/90 backdrop-blur-sm text-rose-700 rounded-xl border border-rose-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">⚠️</span> {error}</div>}
      {success && <div className="px-5 py-3 bg-emerald-50/90 backdrop-blur-sm text-emerald-700 rounded-xl border border-emerald-200 text-sm font-bold shadow-sm flex items-center gap-2"><span className="text-xl leading-none">✓</span> {success}</div>}

      {/* 2. TRIP DETAILS */}
      <GlassCard>
        <div className="flex items-center gap-2 mb-3">
          <div className="bg-blue-50 text-blue-600 p-1.5 rounded-lg shadow-inner border border-blue-100/50"><Truck size={16} /></div>
          <h3 className="font-bold text-sm text-slate-800 tracking-tight">Trip Details</h3>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
           <DenseInput label="Transporter / Owner Name" value={tripDetails.transporterName} onChange={e => setTripDetails({...tripDetails, transporterName: e.target.value})} />
           <DenseInput label="Lorry Number" value={tripDetails.lorryNumber} onChange={e => setTripDetails({...tripDetails, lorryNumber: e.target.value})} className="[&>input]:uppercase" />
           <DenseInput label="Attached GC Numbers" value={tripDetails.gcNumbers} onChange={e => setTripDetails({...tripDetails, gcNumbers: e.target.value})} placeholder="e.g. 1001, 1002" />
           <DenseInput label="From Location" value={tripDetails.fromLocation} onChange={e => setTripDetails({...tripDetails, fromLocation: e.target.value})} />
           <DenseInput label="To Location" value={tripDetails.toLocation} onChange={e => setTripDetails({...tripDetails, toLocation: e.target.value})} />
        </div>
      </GlassCard>

      {/* 3. FINANCIALS */}
      <GlassCard>
        <div className="flex items-center gap-2 mb-3">
          <div className="bg-emerald-50 text-emerald-600 p-1.5 rounded-lg shadow-inner border border-emerald-100/50"><Wallet size={16} /></div>
          <h3 className="font-bold text-sm text-slate-800 tracking-tight">Financial Calculation</h3>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-3 mb-4">
           <DenseInput label="Gross Freight ₹" type="number" value={financials.grossFreight} onChange={e => setFinancials({...financials, grossFreight: e.target.value})} className="[&>input]:font-bold [&>input]:text-indigo-700 [&>input]:bg-indigo-50/30" />
           <DenseInput label="Advance Paid ₹" type="number" value={financials.advancePaid} onChange={e => setFinancials({...financials, advancePaid: e.target.value})} />
           <DenseInput label="Commission ₹" type="number" value={financials.commission} onChange={e => setFinancials({...financials, commission: e.target.value})} />
           <DenseInput label="Shortage ₹" type="number" value={financials.shortage} onChange={e => setFinancials({...financials, shortage: e.target.value})} />
           <DenseInput label="TDS Amount ₹" type="number" value={financials.tds} onChange={e => setFinancials({...financials, tds: e.target.value})} />
        </div>

        <div className="flex flex-col lg:flex-row gap-4 items-end justify-between border-t border-slate-100 pt-3">
           <div className="flex gap-3 w-full lg:w-auto">
             <DenseSelect label="Payment Mode" options={['Cash', 'Bank Transfer', 'Cheque']} value={financials.paymentMode} onChange={e => setFinancials({...financials, paymentMode: e.target.value})} className="w-32" />
             <DenseInput label="Remarks" value={financials.remarks} onChange={e => setFinancials({...financials, remarks: e.target.value})} className="flex-1 lg:w-64" />
           </div>

           <div className="flex items-center gap-4 w-full lg:w-auto justify-end">
             <div className="flex flex-col items-end">
               <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Net Balance Payable</span>
               <div className={`h-9 px-4 rounded-lg text-lg font-black flex items-center shadow-inner border
                 ${netBalance > 0 ? 'bg-emerald-50 border-emerald-200 text-emerald-700' : 
                   netBalance < 0 ? 'bg-rose-50 border-rose-200 text-rose-700' : 
                   'bg-slate-50 border-slate-200 text-slate-700'}`}>
                 ₹ {netBalance.toFixed(2)}
               </div>
             </div>

             <div className="flex gap-2 ml-2">
               <button type="button" tabIndex="-1" onClick={handleReset} className="h-9 px-4 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 hover:border-slate-300 shadow-sm hover:shadow transition-all duration-200 hover:-translate-y-[1px] active:translate-y-[1px] active:scale-95 flex items-center">
                 Reset
               </button>
               <button type="button" onClick={handleSave} disabled={loading} className="h-9 px-6 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg font-bold text-xs shadow-[0_2px_8px_rgba(79,70,229,0.3)] hover:shadow-[0_4px_12px_rgba(79,70,229,0.4)] transition-all duration-200 hover:-translate-y-[1px] active:translate-y-[1px] active:scale-95 flex items-center gap-1.5">
                 <FileText size={14} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Wait...' : 'Submit'}
               </button>
             </div>
           </div>
        </div>
      </GlassCard>

    </div>
  );
}

import React, { memo } from 'react';
import { Button } from '../ui/Button';
import { Calculator, CheckCircle2 } from 'lucide-react';

const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] read-only:bg-slate-50 read-only:text-slate-500" 
      {...props} 
    />
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-3.5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const FreightCalculationCard = memo(({
  freightRate,
  setFreightRate,
  totalFreight,
  advancePaid,
  setAdvancePaid,
  balanceFreight,
  setActiveGc,
  handleSave,
  loading
}) => {
  return (
    <GlassCard>
      <div className="flex items-center gap-2 mb-3">
        <div className="bg-emerald-50 text-emerald-600 p-1.5 rounded-lg shadow-inner border border-emerald-100/50"><Calculator size={16} /></div>
        <h3 className="font-bold text-sm text-slate-800 tracking-tight">Freight Calculation</h3>
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 items-end">
        <DenseInput 
          label="Rate Per Article ₹" 
          type="number" 
          value={freightRate} 
          onChange={e => setFreightRate(e.target.value)} 
          className="[&>input]:font-bold [&>input]:text-slate-800"
        />
        
        <div className="flex flex-col group">
          <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Total Freight</label>
          <div className="h-9 px-3 border border-indigo-100 rounded-lg bg-indigo-50/50 text-base font-black text-indigo-900 flex items-center shadow-inner">
            {totalFreight.toFixed(2)}
          </div>
        </div>

        <DenseInput 
          label="Advance Received ₹" 
          type="number" 
          value={advancePaid} 
          onChange={e => setAdvancePaid(e.target.value)} 
        />
        
        <div className="flex flex-col group">
          <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5">Balance</label>
          <div className={`h-9 px-3 border rounded-lg text-base font-black flex items-center shadow-inner
            ${balanceFreight > 0 ? 'bg-emerald-50 border-emerald-200 text-emerald-700' : 'bg-slate-50 border-slate-200 text-slate-700'}`}>
            {balanceFreight.toFixed(2)}
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-2 mt-5 pt-4 border-t border-slate-100">
         <Button variant="secondary" type="button" tabIndex="-1" onClick={() => setActiveGc(null)} className="h-9 px-4 text-xs shadow-sm flex items-center">
           Cancel
         </Button>
         <Button variant="success" type="button" onClick={handleSave} disabled={loading} className="h-9 px-6 text-xs shadow-sm flex items-center gap-1.5">
           <CheckCircle2 size={14} className={loading ? 'animate-pulse' : ''} /> {loading ? 'Saving...' : 'Save Freight Entry'}
         </Button>
      </div>
    </GlassCard>
  );
});

export default FreightCalculationCard;

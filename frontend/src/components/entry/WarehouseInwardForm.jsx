import React, { memo } from 'react';
import { SearchableSelect } from '../ui/SearchableSelect';
import { Button } from '../ui/Button';
import { Save } from 'lucide-react';

const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <input 
      className="w-full h-12 md:h-10 px-3 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-semibold md:font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-sm" 
      {...props} 
    />
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/90 backdrop-blur-2xl border border-white/60 rounded-xl p-4 md:p-5 shadow-[0_4px_20px_rgb(79,70,229,0.04)] relative transition-all duration-300 hover:shadow-[0_4px_20px_rgb(79,70,229,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const WarehouseInwardForm = memo(({
  editingId,
  loading,
  consignorName,
  setConsignorName,
  consigneeName,
  setConsigneeName,
  consigneeCity,
  setConsigneeCity,
  articles,
  setArticles,
  godownNo,
  setGodownNo,
  remarks,
  setRemarks,
  consignorOptions,
  consigneeOptions,
  godowns,
  consignees,
  handleInward,
  cancelEdit
}) => {
  return (
    <GlassCard className="animate-in fade-in slide-in-from-bottom-4 duration-500 print:hidden">
      <h3 className="font-black text-slate-800 uppercase text-sm tracking-wider mb-4 md:mb-5 border-b border-slate-100 pb-2">
        {editingId ? 'Edit Entry Details' : 'Entry Details'}
      </h3>
      
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 md:gap-5">
        <SearchableSelect 
          label="Consignor Name *" 
          options={consignorOptions}
          value={consignorName} 
          onChange={val => setConsignorName(val)} 
          placeholder="Search Consignor..."
          className="[&>div:nth-of-type(1)]:h-12 [&>div:nth-of-type(1)]:md:h-10 [&>div:nth-of-type(1)]:bg-white/70 [&>div:nth-of-type(1)]:md:bg-white/50 [&>label]:text-[11px] md:[&>label]:text-[10px] [&_input]:text-base md:[&_input]:text-sm [&>div:nth-of-type(1)]:rounded-xl [&>div:nth-of-type(1)]:md:rounded-lg"
        />
        <SearchableSelect 
          label="Consignee Name *" 
          options={consigneeOptions}
          value={consigneeName} 
          onChange={val => {
            setConsigneeName(val);
            const found = consignees.find(c => c.name === val);
            if (found && found.city) setConsigneeCity(found.city);
          }} 
          placeholder="Search Consignee..."
          className="[&>div:nth-of-type(1)]:h-12 [&>div:nth-of-type(1)]:md:h-10 [&>div:nth-of-type(1)]:bg-white/70 [&>div:nth-of-type(1)]:md:bg-white/50 [&>label]:text-[11px] md:[&>label]:text-[10px] [&_input]:text-base md:[&_input]:text-sm [&>div:nth-of-type(1)]:rounded-xl [&>div:nth-of-type(1)]:md:rounded-lg"
        />
        <DenseInput 
          label="Consignee City" 
          placeholder="Enter City" 
          value={consigneeCity} 
          onChange={e => setConsigneeCity(e.target.value)} 
        />
        <DenseInput 
          label="Articles (Qty) *" 
          type="number" 
          inputMode="numeric"
          placeholder="0" 
          value={articles} 
          onChange={e => setArticles(e.target.value)} 
        />
        
        <div className="flex flex-col group">
          <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 transition-colors group-focus-within:text-indigo-600">Godown No *</label>
          <select 
            className="w-full h-12 md:h-10 px-3 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-semibold md:font-medium text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all shadow-sm appearance-none"
            value={godownNo}
            onChange={e => setGodownNo(e.target.value)}
          >
            <option value="">Select Godown</option>
            {godowns.map(g => (
              <option key={g.id} value={g.name}>{g.name}</option>
            ))}
          </select>
        </div>
        
        <DenseInput 
          label="Remarks" 
          placeholder="Optional remarks..." 
          value={remarks} 
          onChange={e => setRemarks(e.target.value)} 
        />
      </div>
      
      <div className="mt-8 flex justify-end">
        {editingId && (
          <Button 
            variant="secondary"
            type="button"
            onClick={cancelEdit}
            className="w-full sm:w-auto h-14 md:h-12 px-6 mr-3 text-lg md:text-base flex items-center justify-center gap-2"
          >
            Cancel Edit
          </Button>
        )}
        <Button 
          variant="primary"
          onClick={handleInward}
          disabled={loading}
          className={`w-full sm:w-auto h-14 md:h-12 px-10 text-lg md:text-base flex items-center justify-center gap-2 ${editingId ? 'bg-blue-600 hover:bg-blue-500' : 'bg-emerald-600 hover:bg-emerald-500'}`}
        >
          <Save size={20} /> {loading ? 'Saving...' : (editingId ? 'Update Entry' : 'Confirm Entry')}
        </Button>
      </div>
    </GlassCard>
  );
});

export default WarehouseInwardForm;

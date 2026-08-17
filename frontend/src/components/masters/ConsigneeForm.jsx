import React from 'react';
import { MapPin, Save, Trash2 } from 'lucide-react';
import { Button } from '../../components/ui/Button';

// Premium Dense Primitives
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 md:mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <input 
      className="w-full h-12 md:h-9 px-3 md:px-2.5 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseTextarea = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 md:mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <textarea 
      className="w-full px-3 py-2 md:px-2.5 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)] resize-y min-h-[48px]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 md:mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <select 
      className="w-full h-12 md:h-9 px-3 md:px-2.5 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-medium text-slate-800 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value !== undefined ? opt.value : opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

export const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-4 shadow-[0_4px_20px_rgb(16,185,129,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(16,185,129,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function ConsigneeForm({ 
  formData, 
  setFormData, 
  consignees, 
  handleVerifyGST, 
  handleSave, 
  loading 
}) {
  return (
    <>
      <GlassCard>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
          <DenseInput label="Trade Name (Primary) *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="lg:col-span-2 [&>input]:font-bold [&>input]:text-emerald-900" />
          <DenseInput label="Legal Name" value={formData.legalName} onChange={e => setFormData({...formData, legalName: e.target.value})} />
          <div className="flex items-end gap-2 lg:col-span-3">
            <DenseInput label="GSTIN" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value.toUpperCase()})} className="w-64 [&>input]:uppercase" />
            <Button variant="secondary" type="button" onClick={handleVerifyGST} disabled={loading} className="h-12 md:h-9 px-4 md:px-3 bg-emerald-100 hover:bg-emerald-200 text-emerald-700 border-emerald-200 whitespace-nowrap text-sm md:text-xs">Verify</Button>
          </div>
          
          <DenseTextarea label="Full Address" value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} className="lg:col-span-3" rows={2} />
          
          <DenseInput label="City" value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
          <DenseInput label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
          <div className="flex gap-2">
            <DenseInput label="State" value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} className="w-2/3" />
            <DenseInput label="State Code" value={formData.stateCode} onChange={e => setFormData({...formData, stateCode: e.target.value})} className="w-1/3" />
          </div>
          
          <DenseInput label="Pincode" value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
          <DenseSelect 
            label="Parent Group (Master Consignee)" 
            options={[
              { label: '-- No Parent Group --', value: '' },
              ...consignees.filter(c => c.id !== formData.id).map(c => ({ label: `${c.name} ${c.city ? `(${c.city})` : ''}`, value: c.id }))
            ]}
            value={formData.parentId || ''} 
            onChange={e => setFormData({...formData, parentId: e.target.value ? parseInt(e.target.value) : ''})} 
            className="lg:col-span-2"
          />
          <DenseInput label="Phone Number" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
          <DenseInput label="Email Address" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
        </div>

        <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
          <Button variant="secondary" onClick={() => setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [], parentId: '' })} className="h-12 md:h-9 px-6 md:px-4 text-sm md:text-xs">
            Clear
          </Button>
          <Button variant="success" onClick={handleSave} disabled={loading} className="h-12 md:h-9 px-8 md:px-5 flex items-center gap-2 text-sm md:text-xs">
            <Save size={16} className="md:w-3.5 md:h-3.5" /> {formData.id ? 'Update Consignee' : 'Save Consignee'}
          </Button>
        </div>
      </GlassCard>

      {formData.addresses && formData.addresses.length > 0 && (
        <GlassCard className="!p-0 border-emerald-200/50 mt-4">
          <div className="p-3 border-b border-emerald-100/50 bg-emerald-50/30 flex justify-between items-center">
            <h3 className="font-bold text-sm text-emerald-900 flex items-center gap-2">
              <MapPin size={14} className="text-emerald-500"/> Additional Places of Business
              <span className="bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full text-[10px]">{formData.addresses.length}</span>
            </h3>
          </div>
          <div className="p-2 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
            {formData.addresses.map((addr, idx) => (
              <div key={idx} className="relative p-3 rounded-lg border border-slate-200 bg-white shadow-sm group">
                <Button variant="custom" onClick={() => setFormData(prev => ({ ...prev, addresses: prev.addresses.filter((_, i) => i !== idx) }))} className="absolute top-2 right-2 p-1 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded opacity-0 group-hover:opacity-100 transition-all"><Trash2 size={12}/></Button>
                <p className="text-xs font-bold text-slate-700 mb-1 pr-6">{addr.address || 'No Street Address'}</p>
                <div className="flex gap-2 text-[10px] text-slate-500">
                  <span>{addr.city}</span>•<span>{addr.district}</span>•<span>{addr.state}</span>
                </div>
                <p className="text-[10px] text-slate-400 mt-1">PIN: {addr.pincode}</p>
              </div>
            ))}
          </div>
        </GlassCard>
      )}
    </>
  );
}

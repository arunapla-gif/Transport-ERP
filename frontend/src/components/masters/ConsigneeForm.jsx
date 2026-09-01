import React from 'react';
import { MapPin, Save, Trash2, CheckCircle } from 'lucide-react';
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
        <div className="flex items-center justify-between mb-4 pb-4 border-b border-slate-100">
          <h3 className="font-bold text-slate-800 text-sm">Customer Details</h3>
          <label className="flex items-center gap-2 cursor-pointer group">
            <span className="text-xs font-bold text-slate-600 group-hover:text-emerald-600 transition-colors">Retail / Walk-in Customer</span>
            <div className={`w-10 h-5 rounded-full transition-colors relative ${formData.isRetail ? 'bg-emerald-500' : 'bg-slate-200'}`}>
              <div className={`absolute top-0.5 left-0.5 bg-white w-4 h-4 rounded-full shadow transition-transform ${formData.isRetail ? 'translate-x-5' : 'translate-x-0'}`} />
            </div>
            <input 
              type="checkbox" 
              className="hidden"
              checked={formData.isRetail}
              onChange={(e) => {
                setFormData(prev => ({ 
                  ...prev, 
                  isRetail: e.target.checked,
                  gstin: e.target.checked ? null : prev.gstin
                }));
              }}
            />
          </label>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
          <DenseInput label="Trade Name (Primary) *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="lg:col-span-2 [&>input]:font-bold [&>input]:text-emerald-900" />
          <DenseInput label="Legal Name" value={formData.legalName} onChange={e => setFormData({...formData, legalName: e.target.value})} />
          <div className="flex flex-col gap-1 lg:col-span-3">
            <div className="flex items-center justify-between px-1">
              <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider">GSTIN</label>
              <label className="flex items-center gap-1.5 cursor-pointer hover:bg-slate-50 px-1.5 py-0.5 rounded transition-colors">
                <input 
                  type="checkbox" 
                  checked={formData.gstin === 'URP'}
                  onChange={(e) => setFormData({ ...formData, gstin: e.target.checked ? 'URP' : '' })}
                  className="w-3 h-3 text-emerald-600 rounded border-slate-300 focus:ring-emerald-500 cursor-pointer"
                />
                <span className="text-[10px] font-bold text-slate-600 select-none">Unregistered (URD)</span>
              </label>
            </div>
            <div className="flex items-end gap-2">
              <input 
                className={`flex-1 h-12 md:h-9 px-3 md:px-2.5 border border-slate-200 rounded-xl md:rounded-lg ${formData.gstin === 'URP' ? 'bg-slate-50 text-slate-400 cursor-not-allowed' : 'bg-white/70 md:bg-white/50 text-slate-800 hover:border-slate-300'} text-base md:text-sm font-medium placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 uppercase transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]`}
                value={formData.gstin || ''}
                onChange={e => setFormData({...formData, gstin: e.target.value.toUpperCase()})}
                disabled={formData.gstin === 'URP'}
                placeholder="27AADCB2230M1Z2"
              />
              <Button 
                variant="secondary" 
                type="button" 
                onClick={handleVerifyGST} 
                disabled={loading || formData.gstin === 'URP' || !formData.gstin || formData.migrationType === 'GST_VERIFIED'} 
                className={`h-12 md:h-9 px-4 md:px-3 whitespace-nowrap text-sm md:text-xs ${
                  formData.gstin === 'URP' 
                    ? 'bg-slate-100 text-slate-400 border-slate-200' 
                    : formData.migrationType === 'GST_VERIFIED'
                    ? 'bg-emerald-100 text-emerald-700 border-emerald-200 cursor-default opacity-100'
                    : 'bg-emerald-100 hover:bg-emerald-200 text-emerald-700 border-emerald-200'
                }`}
              >
                {formData.migrationType === 'GST_VERIFIED' && formData.gstin !== 'URP' ? (
                  <span className="flex items-center gap-1.5 font-bold">
                    <CheckCircle className="w-3.5 h-3.5" /> Verified
                  </span>
                ) : (
                  'Verify'
                )}
              </Button>
            </div>
          </div>
          
          <DenseTextarea label={`Full Address ${formData.gstin === 'URP' ? '*' : ''}`} value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} className="lg:col-span-3" rows={2} />
          
          <DenseInput label={`City ${formData.gstin === 'URP' ? '*' : ''}`} value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
          <DenseInput label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
          <div className="flex gap-2">
            <DenseInput label={`State ${formData.gstin === 'URP' ? '*' : ''}`} value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} className="w-2/3" />
            <DenseInput label={`State Code ${formData.gstin === 'URP' ? '*' : ''}`} value={formData.stateCode} onChange={e => setFormData({...formData, stateCode: e.target.value})} className="w-1/3" />
          </div>
          
          <DenseInput label={`Pincode ${formData.gstin === 'URP' ? '*' : ''}`} value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
          <DenseInput label={`Phone Number ${formData.isRetail ? '*' : ''}`} value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
          <DenseInput label="Email Address" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
          
          {formData.gstin === 'URP' && (
            <div className="lg:col-span-3 mt-2 p-3 bg-amber-50/50 border border-amber-100 rounded-xl flex items-center justify-between animate-in fade-in slide-in-from-top-2 duration-300">
               <div>
                  <h4 className="text-sm font-bold text-amber-900">KYC Required for Unregistered Dealers</h4>
                  <p className="text-xs font-medium text-amber-700/80">Please provide their PAN or Aadhaar number for compliance.</p>
               </div>
               <div className="w-1/3">
                  <DenseInput 
                     label="PAN / Aadhaar *" 
                     value={formData.panNumber} 
                     onChange={e => setFormData({...formData, panNumber: e.target.value.toUpperCase()})} 
                     className="[&>input]:uppercase [&>input]:bg-white" 
                     placeholder="ABCDE1234F"
                  />
               </div>
            </div>
          )}
          
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

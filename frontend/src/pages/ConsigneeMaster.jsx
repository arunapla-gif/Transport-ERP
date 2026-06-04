import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, MapPin, Save, FileText, Search } from 'lucide-react';

// Premium Dense Primitives
const DenseInput = ({ label, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <input 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 placeholder-slate-400 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props} 
    />
  </div>
);

const DenseSelect = ({ label, options, className = "", ...props }) => (
  <div className={`flex flex-col group ${className}`}>
    {label && <label className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-0.5 transition-colors group-focus-within:text-emerald-600">{label}</label>}
    <select 
      className="w-full h-9 px-2.5 border border-slate-200 rounded-lg bg-white/50 text-sm font-medium text-slate-800 focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value !== undefined ? opt.value : opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-4 shadow-[0_4px_20px_rgb(16,185,129,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(16,185,129,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function ConsigneeMaster() {
  const [consignees, setConsignees] = useState([]);
  const [formData, setFormData] = useState({
    id: null, name: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: []
  });
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');

  useKeyboardFlow({
    onSave: (e) => handleSave(e || { preventDefault: () => {} })
  });

  useEffect(() => {
    fetchConsignees();
  }, []);

  const fetchConsignees = async () => {
    try {
      const data = await api.get('/consignees');
      setConsignees(data);
    } catch (err) {
      toast.error('Failed to fetch data.');
    }
  };

  const handleVerifyGST = async () => {
    if (!formData.gstin) return toast.error('Please enter a GSTIN to verify');
    setLoading(true);
    
    try {
      const data = await api.verifyGST(formData.gstin);
      const info = data.taxpayerInfo;
      if (!info) throw new Error('Invalid GSTIN details');
      const addr = info.pradr?.addr || {};
      
      const additionalAddresses = (info.adadr || []).map(a => {
        const adr = a.addr || {};
        return {
          address: [adr.bno, adr.bnm, adr.st, adr.flno].filter(Boolean).join(', '),
          city: adr.loc || adr.city || '',
          district: adr.dst || '',
          state: adr.stcd || '',
          pincode: adr.pncd || adr.pincode || ''
        };
      });

      setFormData(prev => ({
        ...prev,
        name: info.tradeNam || info.lgnm || prev.name,
        address: [addr.bno, addr.bnm, addr.st, addr.flno].filter(Boolean).join(', ') || prev.address,
        city: addr.loc || addr.city || prev.city,
        district: addr.dst || prev.district,
        state: addr.stcd || prev.state,
        pincode: addr.pncd || addr.pincode || prev.pincode,
        addresses: additionalAddresses
      }));
      toast.success('GST verified and details auto-filled!');
    } catch (err) {
      toast.error(err.message || 'Failed to verify GSTIN');
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    if (!formData.name) return toast.error("Name is required");
    
    setLoading(true);
    
    try {
      if (formData.id) {
        await api.put(`/consignees/${formData.id}`, formData);
        toast.success('Consignee updated successfully');
      } else {
        const { id, ...dataToCreate } = formData;
        await api.post('/consignees', dataToCreate);
        toast.success('Consignee created successfully');
      }
      setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] });
      fetchConsignees();
    } catch (err) {
      toast.error('Failed to save record: ' + (err.message || 'Unknown error'));
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (consignee) => {
    setFormData({
      id: consignee.id,
      name: consignee.name || '', address: consignee.address || '', city: consignee.city || '', 
      district: consignee.district || '', state: consignee.state || '', pincode: consignee.pincode || '', 
      gstin: consignee.gstin || '', phone: consignee.phone || '', email: consignee.email || '', group: consignee.group || '', addresses: consignee.addresses || []
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to delete this record?')) return;
    try {
      await api.delete(`/consignees/${id}`);
      fetchConsignees();
      toast.success('Record deleted');
    } catch (err) {
      toast.error('Failed to delete record');
    }
  };

  const filteredConsignees = consignees.filter(c => 
    c.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    (c.gstin && c.gstin.toLowerCase().includes(searchTerm.toLowerCase())) ||
    (c.city && c.city.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-emerald-50 text-emerald-600 p-2 rounded-xl shadow-inner border border-emerald-100/50">
            <MapPin size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Consignee Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage consignee profiles, delivery addresses, and GSTIN details.</p>
          </div>
        </div>
      </GlassCard>

      {/* FORM CARD */}
      <GlassCard>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
          <DenseInput label="Consignee Name *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="lg:col-span-2 [&>input]:font-bold [&>input]:text-emerald-900" />
          <div className="flex items-end gap-2">
            <DenseInput label="GSTIN" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value})} className="flex-1 [&>input]:uppercase" />
            <button type="button" onClick={handleVerifyGST} disabled={loading} className="h-9 px-3 bg-emerald-100 hover:bg-emerald-200 text-emerald-700 rounded-lg font-bold text-xs transition-colors border border-emerald-200 whitespace-nowrap">Verify</button>
          </div>
          
          <DenseInput label="Full Address" value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} className="lg:col-span-3" />
          
          <DenseInput label="City" value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
          <DenseInput label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
          <DenseInput label="State" value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} />
          
          <DenseInput label="Pincode" value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
          <DenseInput label="Phone Number" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
          <DenseInput label="Email Address" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
        </div>

        <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
          <button onClick={() => setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] })} className="h-9 px-4 bg-white border border-slate-200 text-slate-600 rounded-lg font-bold text-xs hover:bg-slate-50 transition-colors">
            Clear
          </button>
          <button onClick={handleSave} disabled={loading} className="h-9 px-5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg font-bold text-xs transition-colors flex items-center gap-2 disabled:opacity-70">
            <Save size={14} /> {formData.id ? 'Update Consignee' : 'Save Consignee'}
          </button>
        </div>
      </GlassCard>

      {/* ADDITIONAL ADDRESSES CARD */}
      {formData.addresses && formData.addresses.length > 0 && (
        <GlassCard className="!p-0 border-emerald-200/50">
          <div className="p-3 border-b border-emerald-100/50 bg-emerald-50/30 flex justify-between items-center">
            <h3 className="font-bold text-sm text-emerald-900 flex items-center gap-2">
              <MapPin size={14} className="text-emerald-500"/> Additional Places of Business
              <span className="bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full text-[10px]">{formData.addresses.length}</span>
            </h3>
          </div>
          <div className="p-2 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
            {formData.addresses.map((addr, idx) => (
              <div key={idx} className="relative p-3 rounded-lg border border-slate-200 bg-white shadow-sm group">
                <button onClick={() => setFormData(prev => ({ ...prev, addresses: prev.addresses.filter((_, i) => i !== idx) }))} className="absolute top-2 right-2 p-1 text-slate-400 hover:text-rose-500 hover:bg-rose-50 rounded opacity-0 group-hover:opacity-100 transition-all"><Trash2 size={12}/></button>
                <p className="text-xs font-bold text-slate-700 mb-1 line-clamp-1 pr-6">{addr.address || 'No Street Address'}</p>
                <div className="flex gap-2 text-[10px] text-slate-500">
                  <span>{addr.city}</span>•<span>{addr.district}</span>•<span>{addr.state}</span>
                </div>
                <p className="text-[10px] text-slate-400 mt-1">PIN: {addr.pincode}</p>
              </div>
            ))}
          </div>
        </GlassCard>
      )}

      {/* LIST CARD */}
      <GlassCard className="!p-0">
        <div className="p-4 border-b border-slate-100 flex justify-between items-center bg-slate-50/50">
          <h3 className="font-bold text-sm text-slate-800">Saved Records <span className="text-slate-400 font-medium ml-1">({consignees.length})</span></h3>
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input 
              type="text" 
              placeholder="Search party..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="h-8 pl-9 pr-3 w-64 border border-slate-200 rounded-lg bg-white text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20"
            />
          </div>
        </div>
        <div className="overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
              <tr>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Name</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">City</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">GSTIN</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider">Phone</th>
                <th className="px-4 py-3 font-bold uppercase tracking-wider text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredConsignees.length > 0 ? filteredConsignees.map((c) => (
                <tr key={c.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-4 py-3 font-medium text-slate-800">{c.name}</td>
                  <td className="px-4 py-3 text-slate-600">{c.city || '-'}</td>
                  <td className="px-4 py-3 text-slate-600 font-mono text-xs uppercase">{c.gstin || '-'}</td>
                  <td className="px-4 py-3 text-slate-600">{c.phone || '-'}</td>
                  <td className="px-4 py-3">
                    <div className="flex justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button onClick={() => handleEdit(c)} className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-md transition-colors"><Edit2 size={14} /></button>
                      <button onClick={() => handleDelete(c.id)} className="p-1.5 text-rose-600 hover:bg-rose-50 rounded-md transition-colors"><Trash2 size={14} /></button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td colSpan="5" className="px-4 py-8 text-center text-slate-500 text-sm">No records found.</td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </GlassCard>
    </div>
  );
}

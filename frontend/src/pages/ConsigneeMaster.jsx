import React, { useState, useEffect } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { Edit2, Trash2, MapPin, Save, FileText, Search } from 'lucide-react';

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

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white/80 backdrop-blur-2xl border border-white/60 rounded-xl p-4 shadow-[0_4px_20px_rgb(16,185,129,0.04)] relative overflow-hidden transition-all duration-300 hover:shadow-[0_4px_20px_rgb(16,185,129,0.06)] ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

export default function ConsigneeMaster() {
  const [consignees, setConsignees] = useState([]);
  const [formData, setFormData] = useState({
    id: null, name: '', legalName: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: []
  });
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('API_ONLY');

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

  const updateConsigneeName = async (id, newName) => {
    try {
      await api.put(`/consignees/${id}`, { name: newName });
      toast.success('Primary name updated!');
      fetchConsignees();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed to update name');
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
      
      const companyName = info.tradeNam || info.lgnm || '';
      
      const cleanAddressParts = (parts) => {
        let joined = parts.filter(Boolean).join(', ');
        if (!companyName) return joined;
        
        try {
          const cleanName = companyName.replace(/[^a-zA-Z0-9 ]/g, '').trim();
          if (cleanName) {
            const regexPattern = cleanName.split(/\s+/).join('\\s*[^a-zA-Z0-9]*\\s*');
            const regex = new RegExp('^' + regexPattern + '\\s*[^a-zA-Z0-9]*\\s*', 'i');
            joined = joined.replace(regex, '');
          }
        } catch (e) {
          // Fallback if regex fails
        }
        
        return joined;
      };

      const additionalAddresses = (info.adadr || []).map(a => {
        const adr = a.addr || {};
        return {
          address: cleanAddressParts([adr.bno, adr.bnm, adr.st, adr.flno]),
          city: adr.loc || adr.city || '',
          district: adr.dst || '',
          state: adr.stcd || '',
          pincode: adr.pncd || adr.pincode || ''
        };
      });

      setFormData(prev => ({
        ...prev,
        name: companyName || prev.name,
        legalName: info.lgnm || prev.legalName,
        address: cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.flno]) || prev.address,
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
    if (!formData.name.trim()) return toast.error('Consignee Name is required');
    setLoading(true);
    try {
      const { id, ...dataToCreate } = formData;
      const payload = { ...dataToCreate, migrationType: 'MANUAL' };
      if (formData.id) {
        await api.put(`/consignees/${formData.id}`, { ...payload, id: formData.id });
        toast.success('Updated successfully');
      } else {
        await api.post('/consignees', payload);
        toast.success('Added successfully');
      }
      setFormData({ id: null, name: '', legalName: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] });
      fetchConsignees();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Operation failed');
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (consignee) => {
    setFormData({
      id: consignee.id,
      name: consignee.name || '',
      legalName: consignee.legalName || '',
      address: consignee.address || '',
      city: consignee.city || '',
      district: consignee.district || '',
      state: consignee.state || '',
      pincode: consignee.pincode || '',
      gstin: consignee.gstin || '',
      phone: consignee.phone || '',
      email: consignee.email || '',
      group: consignee.group || '',
      addresses: consignee.addresses || []
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

  const apiOnlyCount = consignees.filter(c => c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL').length;
  const oldDataCount = consignees.filter(c => c.migrationType === 'OLD_DATA_ONLY').length;
  const retailPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_WITH_PHONE').length;
  const retailNoPhoneCount = consignees.filter(c => c.migrationType === 'RETAIL_NO_PHONE').length;

  const filteredConsignees = consignees.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
      (c.gstin && c.gstin.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (c.city && c.city.toLowerCase().includes(searchTerm.toLowerCase()));
      
    if (activeTab === 'API_ONLY') return matchesSearch && (c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL');
    if (activeTab === 'OLD_DATA_ONLY') return matchesSearch && c.migrationType === 'OLD_DATA_ONLY';
    if (activeTab === 'RETAIL_WITH_PHONE') return matchesSearch && c.migrationType === 'RETAIL_WITH_PHONE';
    if (activeTab === 'RETAIL_NO_PHONE') return matchesSearch && c.migrationType === 'RETAIL_NO_PHONE';
    return false;
  });

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
          <DenseInput label="Trade Name (Primary) *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="lg:col-span-2 [&>input]:font-bold [&>input]:text-emerald-900" />
          <DenseInput label="Legal Name" value={formData.legalName} onChange={e => setFormData({...formData, legalName: e.target.value})} />
          <div className="flex items-end gap-2 lg:col-span-3">
            <DenseInput label="GSTIN" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value})} className="w-64 [&>input]:uppercase" />
            <button type="button" onClick={handleVerifyGST} disabled={loading} className="h-12 md:h-9 px-4 md:px-3 bg-emerald-100 hover:bg-emerald-200 text-emerald-700 rounded-xl md:rounded-lg font-bold text-sm md:text-xs transition-colors border border-emerald-200 whitespace-nowrap">Verify</button>
          </div>
          
          <DenseTextarea label="Full Address" value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} className="lg:col-span-3" rows={2} />
          
          <DenseInput label="City" value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
          <DenseInput label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
          <DenseInput label="State" value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} />
          
          <DenseInput label="Pincode" value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
          <DenseInput label="Phone Number" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
          <DenseInput label="Email Address" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
        </div>

        <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
          <button onClick={() => setFormData({ id: null, name: '', legalName: '', address: '', city: '', district: '', state: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] })} className="h-12 md:h-9 px-6 md:px-4 bg-white border border-slate-200 text-slate-600 rounded-xl md:rounded-lg font-bold text-sm md:text-xs hover:bg-slate-50 transition-colors">
            Clear
          </button>
          <button onClick={handleSave} disabled={loading} className="h-12 md:h-9 px-8 md:px-5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl md:rounded-lg font-bold text-sm md:text-xs transition-colors flex items-center gap-2 disabled:opacity-70">
            <Save size={16} className="md:w-3.5 md:h-3.5" /> {formData.id ? 'Update Consignee' : 'Save Consignee'}
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

      {/* LIST CARD */}
      <GlassCard className="!p-0">
        <div className="p-4 border-b border-slate-100 flex flex-col md:flex-row justify-between items-start md:items-center gap-3 bg-slate-50/50">
          <div className="flex bg-slate-200/50 p-1 rounded-lg w-full md:w-auto">
             <button onClick={() => setActiveTab('API_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'API_ONLY' ? 'bg-white text-emerald-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>API Data ({apiOnlyCount})</button>
             <button onClick={() => setActiveTab('OLD_DATA_ONLY')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'OLD_DATA_ONLY' ? 'bg-white text-rose-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Kept Old Data ({oldDataCount})</button>
             <button onClick={() => setActiveTab('RETAIL_WITH_PHONE')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'RETAIL_WITH_PHONE' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Retail (Has Phone) ({retailPhoneCount})</button>
             <button onClick={() => setActiveTab('RETAIL_NO_PHONE')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'RETAIL_NO_PHONE' ? 'bg-white text-indigo-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Retail (No Phone) ({retailNoPhoneCount})</button>
          </div>
          <div className="relative w-full md:w-auto">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 md:w-3.5 md:h-3.5" />
            <input 
              type="text" 
              placeholder="Search party..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="h-12 md:h-8 pl-10 md:pl-9 pr-3 w-full md:w-64 border border-slate-200 rounded-xl md:rounded-lg bg-white text-base md:text-xs focus:outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/20 shadow-sm md:shadow-none"
            />
          </div>
        </div>

        <>
        {/* MOBILE CARDS VIEW */}
        <div className="md:hidden divide-y divide-slate-100 max-h-[60vh] overflow-y-auto">
          {filteredConsignees.length > 0 ? filteredConsignees.map((c) => (
            <div key={c.id} className="p-4 bg-white hover:bg-slate-50 transition-colors">
              <div className="flex justify-between items-start mb-2">
                <div className="pr-2">
                  <h4 className="font-black text-slate-800 text-base leading-tight flex items-center gap-1.5">
                    {c.name}
                    {c.gstin && c.migrationType !== 'OLD_DATA_ONLY' && <span title="GST Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0">✓</span>}
                  </h4>
                  {c.legalName && c.legalName !== c.name && (
                    <p className="text-[11px] font-semibold text-slate-500 mt-1">Legal: {c.legalName}</p>
                  )}
                  {Array.isArray(c.tradeNames) && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name && (
                    <p className="text-[11px] font-semibold text-slate-500 mt-0.5">Trade: {c.tradeNames.join(', ')}</p>
                  )}
                  <p className="text-xs font-bold text-emerald-600 mt-1 uppercase tracking-wider">{c.gstin || 'NO GSTIN'}</p>
                  {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                    <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200 mt-1 inline-block">+{c.addresses.length} Addr</span>
                  )}
                </div>
                <div className="flex gap-2 shrink-0 opacity-100">
                  <button onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 text-blue-600 bg-blue-50 border border-blue-200 active:bg-blue-100 rounded-lg font-medium"><Edit2 size={14} /><span className="text-xs">Edit</span></button>
                  <button onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 text-rose-600 bg-rose-50 border border-rose-200 active:bg-rose-100 rounded-lg font-medium"><Trash2 size={14} /><span className="text-xs">Delete</span></button>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-2 text-sm font-medium text-slate-600 mt-4 bg-slate-50 p-2.5 rounded-lg border border-slate-100">
                <div className="flex items-center gap-1.5 truncate"><MapPin size={14} className="text-slate-400 shrink-0"/> <span className="truncate">{c.city || '-'}</span></div>
                <div className="flex items-center gap-1.5 truncate">📞 <span className="truncate">{c.phone || '-'}</span></div>
              </div>
            </div>
          )) : (
            <div className="p-8 text-center font-bold text-slate-500 text-sm">No records found.</div>
          )}
        </div>

        {/* DESKTOP TABLE VIEW */}
        <div className="hidden md:block overflow-x-auto max-h-[400px] overflow-y-auto custom-scrollbar">
          <table className="w-full text-sm text-left">
            <thead className="text-xs text-slate-500 bg-slate-50/80 sticky top-0 backdrop-blur-md z-10 border-b border-slate-200">
              <tr>
                <th className="px-3 py-2 font-bold uppercase tracking-wider w-[40%]">Name</th>
                <th className="px-3 py-2 font-bold uppercase tracking-wider w-[20%]">City</th>
                <th className="px-3 py-2 font-bold uppercase tracking-wider">GSTIN</th>
                <th className="px-3 py-2 font-bold uppercase tracking-wider">Phone</th>
                <th className="px-3 py-2 font-bold uppercase tracking-wider text-right sticky right-0 bg-slate-50/95 backdrop-blur-md z-20 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.05)] border-l border-slate-100">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredConsignees.length > 0 ? filteredConsignees.map((c) => (
                <tr key={c.id} className="hover:bg-slate-50/50 transition-colors group">
                  <td className="px-3 py-2 font-medium text-slate-800">
                    <div className="flex flex-col">
                      <div className="flex items-center gap-2">
                        {c.name}
                        {c.gstin && c.migrationType !== 'OLD_DATA_ONLY' && <span title="GST Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0">✓</span>}
                      </div>
                      
                      {c.legalName && (
                        <span className="text-[11px] text-slate-500 font-medium mt-1">Legal: {c.legalName}</span>
                      )}
                      
                      {(() => {
                        const allNames = Array.from(new Set([c.name, ...(c.tradeNames || []), c.legalName].filter(Boolean)));
                        if (allNames.length > 1) {
                          return (
                            <div className="flex items-center gap-1 mt-1">
                              <span className="text-[11px] text-slate-500 font-medium">Trade:</span>
                              <select 
                                className="text-[11px] border border-slate-200 rounded px-1 py-0.5 bg-slate-50 focus:outline-none focus:ring-1 focus:ring-emerald-500 max-w-[200px]"
                                value={c.name}
                                onChange={(e) => {
                                  if (e.target.value !== c.name) {
                                    updateConsigneeName(c.id, e.target.value);
                                  }
                                }}
                              >
                                {allNames.map((n, idx) => (
                                  <option key={idx} value={n}>{n}</option>
                                ))}
                              </select>
                            </div>
                          );
                        } else if (c.tradeNames && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name) {
                          return <span className="text-[11px] text-slate-500 font-medium mt-1">Trade: {c.tradeNames.join(', ')}</span>;
                        }
                        return null;
                      })()}
                    </div>
                  </td>
                  <td className="px-3 py-2 text-slate-600">
                    <div className="flex flex-col">
                      <span>{c.city || '-'}</span>
                      {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                        <span className="text-[10px] text-amber-600 font-medium mt-0.5">+{c.addresses.length} Addr</span>
                      )}
                    </div>
                  </td>
                  <td className="px-3 py-2 text-slate-600 font-mono text-xs uppercase">{c.gstin || '-'}</td>
                  <td className="px-3 py-2 text-slate-600">{c.phone || '-'}</td>
                  <td className="px-3 py-2 sticky right-0 bg-white z-10 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.03)] border-l border-slate-50 group-hover:bg-slate-50/50 transition-colors">
                    <div className="flex justify-end gap-2 opacity-100">
                      <button onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 bg-blue-50 text-blue-600 hover:bg-blue-100 rounded-md border border-blue-200 font-medium whitespace-nowrap">
                        <Edit2 size={14} /> <span className="text-xs hidden lg:inline">Edit</span>
                      </button>
                      <button onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 bg-rose-50 text-rose-600 hover:bg-rose-100 rounded-md border border-rose-200 font-medium whitespace-nowrap">
                        <Trash2 size={14} /> <span className="text-xs hidden lg:inline">Delete</span>
                      </button>
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
        </>
      </GlassCard>
    </div>
  );
}

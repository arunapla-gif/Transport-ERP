import React, { useState, useEffect, useMemo, useRef } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { usePermissions } from '../hooks/usePermissions';
import { Edit2, Trash2, Building2, Save, FileText, Search, MapPin } from 'lucide-react';
import { Button } from '../components/ui/Button';

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
    {label && <label className="text-[11px] md:text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-1 md:mb-0.5 transition-colors group-focus-within:text-indigo-600">{label}</label>}
    <select 
      className="w-full h-12 md:h-9 px-3 md:px-2.5 border border-slate-200 rounded-xl md:rounded-lg bg-white/70 md:bg-white/50 text-base md:text-sm font-medium text-slate-800 focus:outline-none focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 hover:border-slate-300 transition-all appearance-none cursor-pointer shadow-[inset_0_1px_2px_rgba(0,0,0,0.02)]" 
      {...props}
    >
      {options.map((opt, i) => (
        <option key={i} value={opt.value !== undefined ? opt.value : opt}>{opt.label || opt}</option>
      ))}
    </select>
  </div>
);

const GlassCard = ({ children, className = "" }) => (
  <div className={`bg-white border border-slate-200/60 rounded-xl p-4 shadow-sm relative overflow-hidden transition-shadow duration-300 hover:shadow-md ${className}`}>
    <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-white to-transparent opacity-80" />
    {children}
  </div>
);

const stateNameToCode = {
  "jammu and kashmir": "01", "himachal pradesh": "02", "punjab": "03", "chandigarh": "04",
  "uttarakhand": "05", "haryana": "06", "delhi": "07", "rajasthan": "08", "uttar pradesh": "09",
  "bihar": "10", "sikkim": "11", "arunachal pradesh": "12", "nagaland": "13", "manipur": "14",
  "mizoram": "15", "tripura": "16", "meghalaya": "17", "assam": "18", "west bengal": "19",
  "jharkhand": "20", "odisha": "21", "chhattisgarh": "22", "madhya pradesh": "23",
  "gujarat": "24", "daman and diu": "25", "dadra and nagar haveli and daman and diu": "26",
  "maharashtra": "27", "andhra pradesh": "28", "karnataka": "29", "goa": "30",
  "lakshadweep": "31", "kerala": "32", "tamil nadu": "33", "puducherry": "34",
  "andaman and nicobar islands": "35", "telangana": "36", "ladakh": "38"
};

import { useLocation } from 'react-router-dom';

export default function ConsignorMaster() {
  const { canEdit, canDelete } = usePermissions();
  const location = useLocation();
  const query = new URLSearchParams(location.search);
  const branch = query.get('branch') || 'MAIN';

  const [consignors, setConsignors] = useState([]);
  const [formData, setFormData] = useState({
    id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: []
  });
  const [loading, setLoading] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('API_ONLY');

  useKeyboardFlow({
    onSave: (e) => handleSave(e || { preventDefault: () => {} })
  });

  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [totalRecords, setTotalRecords] = useState(0);
  const desktopObserverRef = useRef(null);
  const mobileObserverRef = useRef(null);

  // Debounce search term
  const [debouncedSearch, setDebouncedSearch] = useState('');
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(searchTerm), 400);
    return () => clearTimeout(timer);
  }, [searchTerm]);

  // Reset pagination when search changes
  useEffect(() => {
    setPage(1);
    setConsignors([]);
    setHasMore(true);
  }, [debouncedSearch, branch]);

  useEffect(() => {
    const fetchConsignors = async () => {
      try {
        setLoading(true);
        const url = `/consignors?branch=${branch}&page=${page}&limit=50&q=${encodeURIComponent(debouncedSearch)}`;
        const res = await api.get(url);
        
        if (res.data) {
           setConsignors(prev => {
              if (page === 1) return res.data;
              const existingIds = new Set(prev.map(p => p.id));
              const newItems = res.data.filter(d => !existingIds.has(d.id));
              return [...prev, ...newItems];
           });
           setHasMore(res.hasMore);
           setTotalRecords(res.total);
        } else {
           setConsignors(res); // legacy fallback
           setHasMore(false);
        }
      } catch (err) {
        toast.error('Failed to fetch data.');
      } finally {
        setLoading(false);
      }
    };
    fetchConsignors();
  }, [page, debouncedSearch, branch]);

  useEffect(() => {
    const observer = new IntersectionObserver(
      entries => {
        const isIntersecting = entries.some(entry => entry.isIntersecting);
        if (isIntersecting && hasMore && !loading) {
          setPage(prev => prev + 1);
        }
      },
      { threshold: 0, rootMargin: '1500px' }
    );
    if (desktopObserverRef.current) observer.observe(desktopObserverRef.current);
    if (mobileObserverRef.current) observer.observe(mobileObserverRef.current);
    return () => observer.disconnect();
  }, [hasMore, loading]);

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

      setFormData(prev => {
        const rawState = addr.stcd || '';
        let mappedStateCode = prev.stateCode;
        if (rawState) {
          const normalized = rawState.trim().toLowerCase();
          if (stateNameToCode[normalized]) {
            mappedStateCode = stateNameToCode[normalized];
          }
        }

        return {
          ...prev,
          name: companyName || prev.name,
          address: cleanAddressParts([addr.bno, addr.bnm, addr.st, addr.flno]) || prev.address,
          city: addr.loc || addr.city || prev.city,
          district: addr.dst || prev.district,
          state: rawState || prev.state,
          stateCode: mappedStateCode || rawState,
          pincode: addr.pncd || addr.pincode || prev.pincode,
          addresses: additionalAddresses
        };
      });
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
      const payload = { ...formData, branch, migrationType: 'GST_VERIFIED' };
      if (formData.id) {
        await api.put(`/consignors/${formData.id}`, payload);
        toast.success('Consignor updated successfully');
      } else {
        const { id, ...dataToCreate } = payload;
        await api.post('/consignors', dataToCreate);
        toast.success('Consignor created successfully');
      }
      setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] });
      fetchConsignors();
    } catch (err) {
      toast.error('Failed to save record: ' + (err.message || 'Unknown error'));
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (consignor) => {
    setFormData({
      id: consignor.id,
      name: consignor.name || '', address: consignor.address || '', city: consignor.city || '', 
      district: consignor.district || '', state: consignor.state || '', stateCode: consignor.stateCode || '', pincode: consignor.pincode || '', 
      gstin: consignor.gstin || '', phone: consignor.phone || '', email: consignor.email || '', group: consignor.group || '', addresses: consignor.addresses || []
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to archive this record?')) return;
    try {
      await api.delete(`/consignors/${id}`);
      fetchConsignors();
      toast.success('Record archived');
    } catch (err) {
      toast.error('Failed to archive record');
    }
  };

  const handleRestore = async (id) => {
    try {
      await api.put(`/consignors/${id}/restore`);
      fetchConsignors();
      toast.success('Record restored successfully');
    } catch (err) {
      toast.error('Failed to restore record');
    }
  };

  const apiOnlyCount = consignors.filter(c => !c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED').length;
  const oldDataCount = consignors.filter(c => c.migrationType === 'OLD_DATA_ONLY').length;
  const mergedCount = consignors.filter(c => c.migrationType === 'MERGED_NAME').length;

  const filteredConsignors = useMemo(() => {
    return consignors.filter(c => {
      // The search query is now handled by the server (debouncedSearch).
      // We only use this local filter for the TABS (API_ONLY, etc) to avoid refetching on tab switch.
      if (activeTab === 'API_ONLY') return (!c.migrationType || c.migrationType === 'API_ONLY' || c.migrationType === 'MANUAL' || c.migrationType === 'EWB_LITE' || c.migrationType === 'GST_VERIFIED');
      if (activeTab === 'OLD_DATA_ONLY') return c.migrationType === 'OLD_DATA_ONLY';
      if (activeTab === 'MERGED_NAME') return c.migrationType === 'MERGED_NAME';
      return false;
    });
  }, [consignors, activeTab]);

  // Memoize heavy table row rendering to prevent typing lag
  const desktopTableRows = useMemo(() => {
    if (filteredConsignors.length === 0) {
      return (
        <tr>
          <td colSpan="6" className="px-4 py-16 bg-slate-50/30">
            <div className="flex flex-col items-center justify-center text-center">
              <div className="w-16 h-16 bg-white shadow-sm border border-slate-100 rounded-full flex items-center justify-center mb-4 text-indigo-200">
                <Search size={28} />
              </div>
              <h3 className="text-sm font-black text-slate-700">No records found</h3>
              <p className="text-xs font-medium text-slate-400 mt-1 max-w-xs">We couldn't find any consignors matching your current filters or search criteria.</p>
            </div>
          </td>
        </tr>
      );
    }
    return filteredConsignors.map((c, index) => (
      <tr key={c.id} className={`group hover:bg-indigo-50/30 transition-all duration-200 even:bg-slate-50/50 ${c.isActive === false ? 'opacity-60 bg-slate-100/50 grayscale-[50%]' : ''}`}>
        <td className="px-4 py-3 font-bold text-slate-400 text-center text-xs group-hover:text-indigo-400 transition-colors">{index + 1}</td>
        <td className="px-4 py-3">
          <div className="flex flex-col">
            <div className="flex items-center gap-2">
              <span className="font-bold text-slate-800 text-sm group-hover:text-indigo-900 transition-colors">{c.name}</span>
              {c.isActive === false && <span title="Archived Record" className="flex items-center justify-center bg-slate-200 text-slate-700 px-1.5 py-0.5 rounded border border-slate-300 text-[9px] font-black shrink-0 whitespace-nowrap shadow-sm">ARCHIVED</span>}
              {c.gstin && c.migrationType === 'GST_VERIFIED' && <span title="Fully Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0 shadow-sm">✓</span>}
              {c.migrationType === 'EWB_LITE' && <span title="Partial Profile - Verify GST" className="flex items-center justify-center bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded border border-amber-200 text-[9px] font-black shrink-0 whitespace-nowrap shadow-sm">⚠️ Lite</span>}
            </div>
            {c.legalName && c.legalName !== c.name && (
              <span className="text-[10px] text-slate-500 font-semibold mt-0.5">Legal: {c.legalName}</span>
            )}
          </div>
        </td>
        <td className="px-4 py-3 text-slate-600 text-xs font-medium">
          <div className="flex flex-col">
            <span className="flex items-center gap-1"><MapPin size={12} className="text-slate-400"/> {c.city || '-'}</span>
            {Array.isArray(c.addresses) && c.addresses.length > 0 && (
              <span className="text-[9px] text-amber-600 font-black mt-1 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-100 w-fit">+{c.addresses.length} ADDR</span>
            )}
          </div>
        </td>
        <td className="px-4 py-3 text-slate-700 font-mono text-xs font-bold uppercase tracking-wider">{c.gstin || '-'}</td>
        <td className="px-4 py-3 text-slate-600 text-xs font-medium">{c.phone || '-'}</td>
        <td className="px-4 py-3 sticky right-0 bg-white group-even:bg-slate-50 group-hover:bg-indigo-50/90 z-10 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.03)] border-l border-slate-100 transition-colors duration-200">
          <div className="flex justify-end gap-2 opacity-50 group-hover:opacity-100 transition-opacity">
            {canEdit && <Button variant="secondary" onClick={() => handleEdit(c)} className="flex items-center gap-1.5 px-2.5 py-1.5 h-auto text-indigo-600 hover:bg-indigo-50 hover:text-indigo-700 bg-white border-indigo-200/50 shadow-sm text-xs"><Edit2 size={12} /> Edit</Button>}
            {canDelete && c.isActive !== false && <Button variant="secondary" onClick={() => handleDelete(c.id)} className="flex items-center gap-1.5 px-2.5 py-1.5 h-auto text-rose-600 hover:bg-rose-50 hover:text-rose-700 bg-white border-rose-200/50 shadow-sm text-xs"><Trash2 size={12} /> Archive</Button>}
            {canDelete && c.isActive === false && <Button variant="secondary" onClick={() => handleRestore(c.id)} className="flex items-center gap-1.5 px-2.5 py-1.5 h-auto text-emerald-600 hover:bg-emerald-50 hover:text-emerald-700 bg-white border-emerald-200/50 shadow-sm text-xs">Restore</Button>}
          </div>
        </td>
      </tr>
    ));
  }, [filteredConsignors, canEdit, canDelete]);

  return (
    <div className="space-y-4 max-w-[1200px] mx-auto pb-10" style={{ fontFamily: '"Inter", system-ui, sans-serif' }}>
      
      {/* HEADER CARD */}
      <GlassCard className="!p-4">
        <div className="flex items-center gap-3">
          <div className="bg-indigo-50 text-indigo-600 p-2 rounded-xl shadow-inner border border-indigo-100/50">
            <Building2 size={20} />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 tracking-tight">Consignor Master</h2>
            <p className="text-xs font-medium text-slate-500">Manage consignor profiles, addresses, and GSTIN details.</p>
          </div>
        </div>
      </GlassCard>

      {/* FORM CARD */}
      <GlassCard>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-x-6 gap-y-4">
          <DenseInput label="Consignor Name *" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} className="lg:col-span-2 [&>input]:font-bold [&>input]:text-indigo-900" />
          <div className="flex items-end gap-2">
            <DenseInput label="GSTIN" value={formData.gstin} onChange={e => setFormData({...formData, gstin: e.target.value.toUpperCase()})} className="flex-1 [&>input]:uppercase" />
            <Button variant="secondary" type="button" onClick={handleVerifyGST} disabled={loading} className="h-12 md:h-9 px-4 md:px-3 bg-indigo-100 hover:bg-indigo-200 text-indigo-700 border-indigo-200 whitespace-nowrap text-sm md:text-xs">Verify</Button>
          </div>
          
          <DenseTextarea label="Full Address" value={formData.address} onChange={e => setFormData({...formData, address: e.target.value})} className="lg:col-span-3" rows={2} />
          
          <DenseInput label="City" value={formData.city} onChange={e => setFormData({...formData, city: e.target.value})} />
          <DenseInput label="District" value={formData.district} onChange={e => setFormData({...formData, district: e.target.value})} />
          <div className="flex gap-2">
            <DenseInput label="State" value={formData.state} onChange={e => setFormData({...formData, state: e.target.value})} className="w-2/3" />
            <DenseInput label="State Code" value={formData.stateCode} onChange={e => setFormData({...formData, stateCode: e.target.value})} className="w-1/3" />
          </div>
          
          <DenseInput label="Pincode" value={formData.pincode} onChange={e => setFormData({...formData, pincode: e.target.value})} />
          <DenseInput label="Phone Number" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
          <DenseInput label="Email Address" type="email" value={formData.email} onChange={e => setFormData({...formData, email: e.target.value})} />
        </div>

        <div className="flex justify-end gap-3 mt-6 pt-4 border-t border-slate-100">
          <Button variant="secondary" onClick={() => setFormData({ id: null, name: '', address: '', city: '', district: '', state: '', stateCode: '', pincode: '', gstin: '', phone: '', email: '', group: '', addresses: [] })} className="h-12 md:h-9 px-6 md:px-4 text-sm md:text-xs">
            Clear
          </Button>
          <Button variant="primary" onClick={handleSave} disabled={loading || (formData.id && !canEdit)} className="h-12 md:h-9 px-8 md:px-5 flex items-center gap-2 text-sm md:text-xs">
            <Save size={16} className="md:w-3.5 md:h-3.5" /> {formData.id ? 'Update Consignor' : 'Save Consignor'}
          </Button>
        </div>
      </GlassCard>

      {/* ADDITIONAL ADDRESSES CARD */}
      {formData.addresses && formData.addresses.length > 0 && (
        <GlassCard className="!p-0 border-indigo-200/50">
          <div className="p-3 border-b border-indigo-100/50 bg-indigo-50/30 flex justify-between items-center">
            <h3 className="font-bold text-sm text-indigo-900 flex items-center gap-2">
              <MapPin size={14} className="text-indigo-500"/> Additional Places of Business
              <span className="bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full text-[10px]">{formData.addresses.length}</span>
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
             <button onClick={() => setActiveTab('MERGED_NAME')} className={`flex-1 md:flex-none px-4 py-1.5 rounded-md text-xs font-bold transition-all ${activeTab === 'MERGED_NAME' ? 'bg-white text-blue-700 shadow-sm border border-slate-200/60' : 'text-slate-500 hover:text-slate-700'}`}>Merged Names ({mergedCount})</button>
          </div>
          <div className="relative w-full md:w-auto group">
              <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 md:w-3.5 md:h-3.5 group-focus-within:text-indigo-500 transition-colors z-10" />
            {/* The Glow */}
            <div className="absolute inset-0 bg-indigo-500/20 blur-md rounded-lg opacity-0 group-focus-within:opacity-100 transition-opacity duration-500"></div>
            <input 
              type="text" 
              placeholder="Search party..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="relative h-12 md:h-8 pl-10 md:pl-9 pr-3 w-full md:w-64 border border-slate-200 rounded-xl md:rounded-lg bg-white/90 backdrop-blur text-base md:text-xs focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 shadow-sm transition-all duration-300"
            />
          </div>
        </div>

        <>
          {/* MOBILE CARDS VIEW */}
        <div className="md:hidden divide-y divide-slate-100 max-h-[60vh] overflow-y-auto">
          {filteredConsignors.length > 0 ? filteredConsignors.map((c, index) => (
            <div key={c.id} className={`p-4 bg-white hover:bg-slate-50 transition-colors ${c.isActive === false ? 'opacity-60 bg-slate-50 border-slate-300' : ''}`}>
              <div className="flex justify-between items-start mb-2">
                <div className="pr-2">
                  <h4 className="font-black text-slate-800 text-base leading-tight flex flex-wrap items-center gap-1.5">
                    <span className="text-slate-400 font-bold mr-1 text-sm">{index + 1}.</span>
                    {c.isActive === false && <span title="Archived Record" className="flex items-center justify-center bg-slate-200 text-slate-700 px-1.5 rounded border border-slate-300 text-[10px] font-black shrink-0 whitespace-nowrap">ARCHIVED</span>}
                    {c.name}
                    {c.gstin && c.migrationType === 'GST_VERIFIED' && <span title="Fully Verified" className="flex items-center justify-center w-4 h-4 bg-emerald-100 text-emerald-600 rounded-full border border-emerald-200 text-[10px] font-black shrink-0">✓</span>}
                    {c.migrationType === 'EWB_LITE' && <span title="Partial Profile - Verify GST" className="flex items-center justify-center bg-amber-100 text-amber-700 px-1.5 rounded border border-amber-300 text-[10px] font-black shrink-0 whitespace-nowrap">⚠️ EWB Lite</span>}
                  </h4>
                  {c.legalName && c.legalName !== c.name && (
                    <p className="text-[11px] font-semibold text-slate-500 mt-1">Legal: {c.legalName}</p>
                  )}
                  {Array.isArray(c.tradeNames) && c.tradeNames.length > 0 && c.tradeNames[0] !== c.name && (
                    <p className="text-[11px] font-semibold text-slate-500 mt-0.5">Trade: {c.tradeNames.join(', ')}</p>
                  )}
                  <p className="text-xs font-bold text-indigo-600 mt-1 uppercase tracking-wider">{c.gstin || 'NO GSTIN'}</p>
                  {Array.isArray(c.addresses) && c.addresses.length > 0 && (
                    <span className="text-[10px] font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded border border-amber-200 mt-1 inline-block">+{c.addresses.length} Addr</span>
                  )}
                </div>
                <div className="flex gap-2 shrink-0">
                  {canEdit && <Button variant="secondary" onClick={() => handleEdit(c)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-blue-600 bg-blue-50 hover:bg-blue-100 border-blue-200 shadow-none"><Edit2 size={14} /><span className="text-xs">Edit</span></Button>}
                  {canDelete && c.isActive !== false && <Button variant="secondary" onClick={() => handleDelete(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-amber-600 bg-amber-50 hover:bg-amber-100 border-amber-200 shadow-none"><Trash2 size={14} /><span className="text-xs">Archive</span></Button>}
                  {canDelete && c.isActive === false && <Button variant="secondary" onClick={() => handleRestore(c.id)} className="flex items-center gap-1 px-2 py-1.5 h-auto text-emerald-600 bg-emerald-50 hover:bg-emerald-100 border-emerald-200 shadow-none"><span className="text-xs">Restore</span></Button>}
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

        {/* DESKTOP TABLE VIEW - PREMIUM DATA GRID */}
        <div className="hidden md:block overflow-x-auto max-h-[500px] overflow-y-auto custom-scrollbar border border-slate-200/60 rounded-b-xl rounded-t-none">
          <table className="w-full text-sm text-left border-collapse">
            <thead className="text-[11px] font-black text-slate-500 uppercase tracking-wider bg-slate-50/95 sticky top-0 backdrop-blur-xl z-20 shadow-[0_1px_3px_rgba(0,0,0,0.05)]">
              <tr>
                <th className="px-4 py-3 w-12 text-center border-b border-slate-200">#</th>
                <th className="px-4 py-3 w-[40%] border-b border-slate-200">Consignor Details</th>
                <th className="px-4 py-3 w-[20%] border-b border-slate-200">Location</th>
                <th className="px-4 py-3 border-b border-slate-200">Tax ID (GSTIN)</th>
                <th className="px-4 py-3 border-b border-slate-200">Contact</th>
                <th className="px-4 py-3 text-right sticky right-0 bg-slate-50/95 backdrop-blur-xl z-30 shadow-[-10px_0_15px_-5px_rgba(0,0,0,0.05)] border-l border-b border-slate-200">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 bg-white">
              {desktopTableRows}
              {hasMore && (
                <tr>
                  <td colSpan="6" className="py-6 text-center text-slate-500 font-medium" ref={desktopObserverRef}>
                    {loading ? (
                      <span className="flex items-center justify-center gap-2"><div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div> Loading more...</span>
                    ) : 'Scroll for more'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        
        {/* MOBILE OBSERVER DIV (only shown on mobile if desktop hidden) */}
        <div className="md:hidden p-4 text-center text-slate-500 text-sm font-medium" ref={mobileObserverRef}>
           {hasMore && (loading ? 'Loading more...' : 'Scroll for more')}
        </div>
        </>
      </GlassCard>
    </div>
  );
}

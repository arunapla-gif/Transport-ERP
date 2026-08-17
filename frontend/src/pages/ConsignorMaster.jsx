import React, { useState, useEffect, useMemo, useRef } from 'react';
import { api } from '../api';
import toast from 'react-hot-toast';
import { useKeyboardFlow } from '../hooks/useKeyboardFlow';
import { usePermissions } from '../hooks/usePermissions';
import { Edit2, Trash2, Building2, Save, FileText, Search, MapPin } from 'lucide-react';
import { Button } from '../components/ui/Button';

import { useLocation } from 'react-router-dom';
import ConsignorForm, { GlassCard } from '../components/masters/ConsignorForm';
import ConsignorTable from '../components/masters/ConsignorTable';

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

  const fetchConsignors = async (pageNum = page) => {
    try {
      setLoading(true);
      const url = `/consignors?branch=${branch}&page=${pageNum}&limit=50&q=${encodeURIComponent(debouncedSearch)}`;
      const res = await api.get(url);
      
      if (res.data) {
         setConsignors(prev => {
            if (pageNum === 1) return res.data;
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

  useEffect(() => {
    fetchConsignors(page);
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
      <ConsignorForm 
        formData={formData}
        setFormData={setFormData}
        handleVerifyGST={handleVerifyGST}
        handleSave={handleSave}
        loading={loading}
        canEdit={canEdit}
      />

      {/* LIST CARD */}
      <ConsignorTable 
        consignors={consignors}
        filteredConsignors={filteredConsignors}
        desktopTableRows={desktopTableRows}
        loading={loading}
        hasMore={hasMore}
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        desktopObserverRef={desktopObserverRef}
        mobileObserverRef={mobileObserverRef}
        handleEdit={handleEdit}
        handleDelete={handleDelete}
        handleRestore={handleRestore}
        canEdit={canEdit}
        canDelete={canDelete}
      />
    </div>
  );
}
